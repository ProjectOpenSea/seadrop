// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Test } from "forge-std/Test.sol";

import { SeaDropMinter } from "seadrop/v3/SeaDropMinter.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { ERC721SeaDropV3 } from "seadrop/v3/ERC721SeaDropV3.sol";

import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

/**
 * @dev Gas for one paid mint with a fee recipient, set up the way
 *      test/foundry/SeaDropSnapshot.t.sol measures v1's testMintPublic:
 *      0.1 ETH, a 1% fee to address(5), the creator as sole payout
 *      recipient, both funded, and the test contract minting one token to
 *      itself.
 */
contract TestSeaDropV3Snapshot is Test {
    SeaDropMinter minter;
    ERC721SeaDropV3 token721;
    ERC1155SeaDropV3 token1155;
    ERC721SeaDrop v1Token;

    address creator = makeAddr("creator");
    address signer;
    uint256 signerKey;
    bytes signature;

    function setUp() public {
        (signer, signerKey) = makeAddrAndKey("signer");

        minter = new SeaDropMinter(address(this));
        minter.setCurrency(
            address(0),
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: 100,
                feeRecipient: address(5)
            })
        );

        token721 = new ERC721SeaDropV3("", "", address(minter));
        token721.setMaxSupply(1000);
        token1155 = new ERC1155SeaDropV3(address(minter));
        token1155.setMaxSupply(1, 1000);
        address[] memory allowed = new address[](1);
        allowed[0] = address(minter);
        v1Token = new ERC721SeaDrop("", "", allowed);
        v1Token.setMaxSupply(1000);

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 10_000);
        ISeaDropMinter.Stage memory stage = ISeaDropMinter.Stage({
            price: 0.1 ether,
            currency: address(0),
            startTime: uint40(vm.getBlockTimestamp()),
            endTime: uint40(vm.getBlockTimestamp()) + 100,
            feeBps: 100,
            feeRecipient: address(5),
            maxPerWallet: 10,
            signerSetId: 0,
            signer: address(0)
        });

        minter.setPayoutRecipients(address(token721), recipients);
        minter.setPayoutRecipients(address(token1155), recipients);
        minter.setPayoutRecipients(address(v1Token), recipients);
        minter.setStage(address(token721), 0, 0, stage);
        minter.setStage(address(token1155), 1, 0, stage);
        minter.setStage(address(v1Token), 0, 0, stage);

        // The same stage without a wallet limit, which skips the count.
        stage.maxPerWallet = 0;
        minter.setStage(address(token721), 0, 2, stage);
        stage.maxPerWallet = 10;

        // A signed stage, with the signer in an admin-managed set.
        minter.setSignerSetMember(1, signer, true);
        stage.signerSetId = 1;
        minter.setStage(address(token721), 0, 1, stage);
        _signAuthorization();

        vm.deal(address(5), 1 << 128);
        vm.deal(creator, 1 << 128);
    }

    function _signAuthorization() internal {
        bytes32 structHash = keccak256(
            abi.encode(
                minter.MINT_AUTHORIZATION_TYPEHASH(),
                address(token721),
                uint256(0),
                uint256(1),
                address(this),
                uint256(5),
                false,
                uint256(0),
                uint256(1010101)
            )
        );
        (, string memory name, string memory version,,,,) =
            minter.eip712Domain();
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,"
                    "address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(minter)
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            signerKey,
            keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash))
        );
        signature = abi.encodePacked(r, s, v);
    }

    function testMintV3ERC721_snapshot() public {
        minter.mint{ value: 0.1 ether }(
            ISeaDropMinter.MintParams({
                token: address(token721),
                id: 0,
                stageIndex: 0,
                wallet: address(this),
                recipient: address(this),
                quantity: 1,
                currency: address(0),
                maxTotalPrice: 0.1 ether
            }),
            ISeaDropMinter.Authorization(address(0), 0, false, 0, 0, "")
        );
    }

    function testMintV3ERC1155_snapshot() public {
        minter.mint{ value: 0.1 ether }(
            ISeaDropMinter.MintParams({
                token: address(token1155),
                id: 1,
                stageIndex: 0,
                wallet: address(this),
                recipient: address(this),
                quantity: 1,
                currency: address(0),
                maxTotalPrice: 0.1 ether
            }),
            ISeaDropMinter.Authorization(address(0), 0, false, 0, 0, "")
        );
    }

    function testMintV1TokenThroughV3_snapshot() public {
        minter.mint{ value: 0.1 ether }(
            ISeaDropMinter.MintParams({
                token: address(v1Token),
                id: 0,
                stageIndex: 0,
                wallet: address(this),
                recipient: address(this),
                quantity: 1,
                currency: address(0),
                maxTotalPrice: 0.1 ether
            }),
            ISeaDropMinter.Authorization(address(0), 0, false, 0, 0, "")
        );
    }

    function testMintV3ERC721NoWalletLimit_snapshot() public {
        minter.mint{ value: 0.1 ether }(
            ISeaDropMinter.MintParams({
                token: address(token721),
                id: 0,
                stageIndex: 2,
                wallet: address(this),
                recipient: address(this),
                quantity: 1,
                currency: address(0),
                maxTotalPrice: 0.1 ether
            }),
            ISeaDropMinter.Authorization(address(0), 0, false, 0, 0, "")
        );
    }

    function testMintV3ERC721Signed_snapshot() public {
        minter.mint{ value: 0.1 ether }(
            ISeaDropMinter.MintParams({
                token: address(token721),
                id: 0,
                stageIndex: 1,
                wallet: address(this),
                recipient: address(this),
                quantity: 1,
                currency: address(0),
                maxTotalPrice: 0.1 ether
            }),
            ISeaDropMinter.Authorization(
                signer, 5, false, 0, 1010101, signature
            )
        );
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        public
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
