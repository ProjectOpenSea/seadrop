// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import {
    ERC1155SeaDropCloneFactory
} from "seadrop/clones/ERC1155SeaDropCloneFactory.sol";

import {
    ERC1155SeaDropCloneable
} from "seadrop/clones/ERC1155SeaDropCloneable.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import {
    ERC1155SeaDropConfigurer
} from "seadrop/lib/ERC1155SeaDropConfigurer.sol";

import {
    MultiConfigureStruct,
    PublicDrop
} from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

contract ERC1155SeaDropCloneFactoryTest is SeaDrop1155Test {
    ERC1155SeaDropCloneFactory factory;
    uint256 feeBps = 500;

    function setUp() public override {
        super.setUp();

        factory = new ERC1155SeaDropCloneFactory(address(consideration));
    }

    function testClone__snapshot() public {
        factory.createClone("name", "symbol", bytes32("1"));
    }

    function testClone1() public {
        vm.expectEmit(false, false, false, false);
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC1155_CLONE);
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        token = ERC1155SeaDrop(clone);

        assertEq(token.name(), "name", "name should be set");
        assertEq(token.symbol(), "symbol", "symbol should be set");
        assertEq(token.owner(), address(this), "owner should be set");

        address creator = makeAddr("creator");
        _setSingleCreatorPayout(address(token), creator);

        assertEq(token.totalSupply(0), 0);
        assertEq(token.totalSupply(1), 0);

        address feeRecipient = makeAddr("feeRecipient");
        IERC1155SeaDrop(clone).updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(1, 10);
        token.setMaxSupply(3, 10);

        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 3,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        IERC1155SeaDrop(clone).updatePublicDrop(publicDrop, 0);

        // Token id 1 x3 and token id 3 x1.
        address minter = address(this);
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMint(
                clone,
                _uints(1, 3),
                _uints(3, 1),
                feeRecipient,
                feeBps,
                1 ether,
                minter,
                0
            )
        );
        assertEq(value, 4 ether);

        vm.deal(address(this), 10 ether);
        _fulfillAndExpectMint(order, minter, value, 0);

        assertEq(token.balanceOf(minter, 1), 3);
        assertEq(token.balanceOf(minter, 3), 1);
        assertEq(creator.balance, 4 ether * 0.95);

        // Minting the same again exceeds maxTotalMintableByWalletPerToken for
        // token id 1: 3 minted of it plus 3 (not the wallet's 4 overall).
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                1,
                6,
                5
            )
        );

        assertEq(token.uri(1), "", "tokenURI should be blank at first");
        assertEq(token.baseURI(), "", "baseURI should be blank at first");

        token.setBaseURI("https://example.com");
        assertEq(token.baseURI(), "https://example.com");
        assertEq(token.uri(1), "https://example.com");
    }

    function testClone_Reinitialize() public {
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC1155SeaDropCloneable token = ERC1155SeaDropCloneable(clone);
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize(
            address(0), address(0), "name", "symbol", address(this)
        );
    }

    /// @dev Nobody can initialize the implementation the clones point at,
    ///      and it holds no owner or configuration of its own.
    function testCannotInitializeImplementation() public {
        ERC1155SeaDropCloneable implementation =
            ERC1155SeaDropCloneable(factory.cloneableImplementation());
        assertEq(implementation.owner(), address(0));
        assertEq(implementation.name(), "");

        address attacker = makeAddr("attacker");
        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(attacker);
        implementation.initialize(
            attacker, address(consideration), "name", "symbol", attacker
        );
        assertEq(implementation.owner(), address(0));

        // The same holds for an implementation deployed outside the factory.
        ERC1155SeaDropCloneable standalone = new ERC1155SeaDropCloneable();
        vm.expectRevert("Initializable: contract is already initialized");
        vm.prank(attacker);
        standalone.initialize(
            attacker, address(consideration), "name", "symbol", attacker
        );
    }

    /// @dev Clones of the locked implementation still initialize, once.
    function testClonesOfLockedImplementationInitialize() public {
        address first = factory.createClone("first", "ONE", bytes32("1"));
        address second = factory.createClone("second", "TWO", bytes32("2"));
        assertTrue(first != second);
        assertEq(ERC1155SeaDrop(first).name(), "first");
        assertEq(ERC1155SeaDrop(second).name(), "second");
        assertEq(ERC1155SeaDrop(first).owner(), address(this));
        assertEq(IERC1155SeaDrop(first).configurer(), factory.configurer());
        assertEq(
            IERC1155SeaDrop(first).getAllowedSeaport(),
            _addrs(address(consideration))
        );
    }

    event ContractURIUpdated(string newContractURI);
    event ContractURIUpdated();

    /// @dev Clones emit ERC-7572's ContractURIUpdated() after SeaDrop's
    ///      original event, from setContractURI and from the factory's
    ///      configurer.
    function testCloneSetContractURIEmitsERC7572Event() public {
        address clone = factory.createClone("name", "symbol", bytes32("1"));

        vm.recordLogs();
        ERC1155SeaDropCloneable(clone)
            .setContractURI("https://example.com/contract");
        _assertContractURIUpdatedLogs(
            vm.getRecordedLogs(), clone, "https://example.com/contract"
        );
        assertEq(
            ERC1155SeaDropCloneable(clone).contractURI(),
            "https://example.com/contract"
        );

        MultiConfigureStruct memory config;
        config.contractURI = "https://example.com/contract2";
        vm.expectEmit(true, true, true, true, clone);
        emit ContractURIUpdated("https://example.com/contract2");
        vm.expectEmit(true, true, true, true, clone);
        emit ContractURIUpdated();
        ERC1155SeaDropConfigurer(factory.configurer())
            .multiConfigure(clone, config);
        assertEq(
            ERC1155SeaDropCloneable(clone).contractURI(),
            "https://example.com/contract2"
        );
    }

    /// @dev The public getter solady made internal keeps its 48 hours.
    function testCloneOwnershipHandoverValidFor() public {
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        assertEq(
            ERC1155SeaDropCloneable(clone).ownershipHandoverValidFor(), 48 hours
        );
    }
}
