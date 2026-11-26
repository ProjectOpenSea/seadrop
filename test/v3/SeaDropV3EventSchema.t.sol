// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { MockDelegateRegistry } from "./utils/Mocks.sol";

import { Vm } from "forge-std/Vm.sol";

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { SeaDropTokenFactory } from "seadrop/v3/SeaDropTokenFactory.sol";

/**
 * @dev Pins the events OpenSea indexes to the field lists in
 *      docs/v3/AuditScope.md ("Event schema"). Changing a field's type or
 *      order fails the signature tests. Moving a field between the topics
 *      and the data, which doesn't change a signature, fails the emission
 *      tests, which compare each log with topics and data encoded here
 *      field by field. Changing a config event's fields means bumping
 *      CONFIG_EVENT_VERSION, updating the doc, and telling the indexer.
 */
contract SeaDropV3EventSchemaTest is SeaDropV3TestHelper {
    uint256 internal constant VERSION = 1;

    function test_configEventVersion() public view {
        assertEq(minter.CONFIG_EVENT_VERSION(), VERSION);
    }

    function test_minterEventSignatures() public pure {
        assertEq(
            ISeaDropMinter.StageUpdated.selector,
            keccak256(
                "StageUpdated(uint256,address,uint256,uint256,"
                "(uint96,address,uint40,uint40,uint16,address,uint32,uint32,"
                "uint32,address))"
            )
        );
        assertEq(
            ISeaDropMinter.PayoutRecipientsUpdated.selector,
            keccak256(
                "PayoutRecipientsUpdated(uint256,address,(address,uint16)[])"
            )
        );
        assertEq(
            ISeaDropMinter.CurrencyUpdated.selector,
            keccak256("CurrencyUpdated(uint256,address,(bool,uint16,address))")
        );
        assertEq(
            ISeaDropMinter.DefaultERC20CurrencyUpdated.selector,
            keccak256(
                "DefaultERC20CurrencyUpdated(uint256,(bool,uint16,address))"
            )
        );
        assertEq(
            ISeaDropMinter.CurrencyOverrideCleared.selector,
            keccak256("CurrencyOverrideCleared(uint256,address)")
        );
        assertEq(
            ISeaDropMinter.SignerSetUpdated.selector,
            keccak256("SignerSetUpdated(uint256,uint32,address,bool)")
        );
        assertEq(
            ISeaDropMinter.SeaDropMint.selector,
            keccak256(
                "SeaDropMint(address,uint256,uint256,address,address,address,"
                "uint256,uint256,address,address,uint256)"
            )
        );
    }

    function test_factoryEventSignature() public pure {
        assertEq(
            SeaDropTokenFactory.TokenCreated.selector,
            keccak256("TokenCreated(address,address,address,bytes32)")
        );
    }

    // ---------------------------------------------------------------------
    // Emitted logs: which fields are topics, and the data's encoding
    // ---------------------------------------------------------------------

    function test_emitted_StageUpdated() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.maxTokenSupplyForStage = 50;
        stage.signerSetId = 3;
        stage.signer = signer;
        vm.recordLogs();
        minter.setStage(address(token1155), ID_1155, 2, stage);

        Vm.Log memory log = _onlyLog(
            address(minter),
            keccak256(
                "StageUpdated(uint256,address,uint256,uint256,"
                "(uint96,address,uint40,uint40,uint16,address,uint32,uint32,"
                "uint32,address))"
            )
        );
        _assertTopics(
            log,
            _topic(address(token1155)),
            bytes32(ID_1155),
            bytes32(uint256(2))
        );
        assertEq(
            log.data,
            abi.encode(
                VERSION,
                PRICE,
                address(0),
                stage.startTime,
                stage.endTime,
                FEE_BPS,
                feeRecipient,
                MAX_PER_WALLET,
                uint256(50),
                uint256(3),
                signer
            )
        );
    }

    function test_emitted_PayoutRecipientsUpdated() public {
        vm.recordLogs();
        _setSinglePayout(address(token721), carol);

        Vm.Log memory log = _onlyLog(
            address(minter),
            keccak256(
                "PayoutRecipientsUpdated(uint256,address,(address,uint16)[])"
            )
        );
        _assertTopics(log, _topic(address(token721)));
        // version, offset of the array, its length, then each recipient.
        assertEq(
            log.data,
            abi.encode(VERSION, uint256(64), uint256(1), carol, uint256(10_000))
        );
    }

    function test_emitted_defaultCurrencyAndClearOverride() public {
        ISeaDropMinter.CurrencyConfig memory config =
            ISeaDropMinter.CurrencyConfig(true, 250, carol);
        vm.recordLogs();
        minter.setDefaultERC20Currency(config);
        Vm.Log memory log = _onlyLog(
            address(minter),
            keccak256(
                "DefaultERC20CurrencyUpdated(uint256,(bool,uint16,address))"
            )
        );
        assertEq(log.topics.length, 1);
        assertEq(log.data, abi.encode(VERSION, true, uint256(250), carol));
        minter.setCurrency(address(token721), config);
        vm.recordLogs();
        minter.clearCurrencyOverride(address(token721));
        log = _onlyLog(
            address(minter),
            keccak256("CurrencyOverrideCleared(uint256,address)")
        );
        _assertTopics(log, _topic(address(token721)));
        assertEq(log.data, abi.encode(VERSION));
    }

    function test_emitted_CurrencyUpdated() public {
        address currency = makeAddr("currency");
        vm.recordLogs();
        minter.setCurrency(
            currency,
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: 250,
                feeRecipient: carol
            })
        );

        Vm.Log memory log = _onlyLog(
            address(minter),
            keccak256("CurrencyUpdated(uint256,address,(bool,uint16,address))")
        );
        _assertTopics(log, _topic(currency));
        assertEq(log.data, abi.encode(VERSION, true, uint256(250), carol));
    }

    function test_emitted_SignerSetUpdated() public {
        vm.recordLogs();
        minter.setSignerSetMember(9, signer, true);

        Vm.Log memory log = _onlyLog(
            address(minter),
            keccak256("SignerSetUpdated(uint256,uint32,address,bool)")
        );
        _assertTopics(log, bytes32(uint256(9)), _topic(signer));
        assertEq(log.data, abi.encode(VERSION, true));
    }

    function test_emitted_TokenCreated() public {
        bytes32 salt = bytes32(uint256(42));
        vm.recordLogs();
        vm.prank(alice);
        address token = factory.createERC1155(salt);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        Vm.Log memory created = _find(
            logs,
            address(factory),
            keccak256("TokenCreated(address,address,address,bytes32)")
        );
        _assertTopics(
            created,
            _topic(token),
            _topic(factory.erc1155Implementation()),
            _topic(alice)
        );
        assertEq(created.data, abi.encode(salt));
    }

    function test_emitted_SeaDropMint() public {
        vm.recordLogs();
        vm.prank(bob);
        minter.mint{ value: 2 * PRICE }(
            _params(address(token1155), ID_1155, alice, alice, 2), _noAuth()
        );

        Vm.Log memory log = _onlyLog(
            address(minter),
            keccak256(
                "SeaDropMint(address,uint256,uint256,address,address,address,"
                "uint256,uint256,address,address,uint256)"
            )
        );
        _assertTopics(
            log, _topic(address(token1155)), bytes32(ID_1155), _topic(alice)
        );
        assertEq(
            log.data,
            abi.encode(
                uint256(0), // stageIndex
                bob, // payer
                alice, // recipient
                uint256(2), // quantity
                PRICE, // unitPrice
                address(0), // currency
                feeRecipient,
                FEE_BPS
            )
        );
    }

    function test_emitted_SeaDropMintWithDistinctRoles() public {
        address registry = minter.DELEGATE_REGISTRY();
        vm.etch(registry, address(new MockDelegateRegistry()).code);
        vm.prank(alice);
        MockDelegateRegistry(registry)
            .delegateContract(bob, address(token1155), "", true);
        vm.recordLogs();
        vm.prank(bob);
        minter.mint{ value: 2 * PRICE }(
            _params(address(token1155), ID_1155, alice, carol, 2), _noAuth()
        );

        Vm.Log memory log = _onlyLog(
            address(minter),
            keccak256(
                "SeaDropMint(address,uint256,uint256,address,address,address,"
                "uint256,uint256,address,address,uint256)"
            )
        );
        _assertTopics(
            log, _topic(address(token1155)), bytes32(ID_1155), _topic(alice)
        );
        assertEq(
            log.data,
            abi.encode(
                uint256(0), // stageIndex
                bob, // payer
                carol, // recipient
                uint256(2), // quantity
                PRICE, // unitPrice
                address(0), // currency
                feeRecipient,
                FEE_BPS
            )
        );
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    /// @dev The one log with `topic0` from `emitter` since recordLogs.
    function _onlyLog(address emitter, bytes32 topic0)
        internal
        returns (Vm.Log memory)
    {
        return _find(vm.getRecordedLogs(), emitter, topic0);
    }

    function _find(Vm.Log[] memory logs, address emitter, bytes32 topic0)
        internal
        pure
        returns (Vm.Log memory found)
    {
        uint256 matches;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == emitter && logs[i].topics.length > 0
                    && logs[i].topics[0] == topic0
            ) {
                found = logs[i];
                ++matches;
            }
        }
        assertEq(matches, 1, "expected exactly one matching log");
    }

    function _topic(address a) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function _assertTopics(Vm.Log memory log, bytes32 t1) internal pure {
        assertEq(log.topics.length, 2, "indexed field count");
        assertEq(log.topics[1], t1);
    }

    function _assertTopics(Vm.Log memory log, bytes32 t1, bytes32 t2)
        internal
        pure
    {
        assertEq(log.topics.length, 3, "indexed field count");
        assertEq(log.topics[1], t1);
        assertEq(log.topics[2], t2);
    }

    function _assertTopics(
        Vm.Log memory log,
        bytes32 t1,
        bytes32 t2,
        bytes32 t3
    ) internal pure {
        assertEq(log.topics.length, 4, "indexed field count");
        assertEq(log.topics[1], t1);
        assertEq(log.topics[2], t2);
        assertEq(log.topics[3], t3);
    }
}
