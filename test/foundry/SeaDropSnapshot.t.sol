// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { TestERC721 } from "test/foundry/utils/TestERC721.sol";
import {
    AllowListData,
    MintParams,
    PublicDrop,
    TokenGatedDropStage,
    TokenGatedMintParams
} from "seadrop/lib/SeaDropStructs.sol";
import { Merkle } from "murky/Merkle.sol";

contract ERC721SeaDropPlusRegularMint is ERC721SeaDrop {
    constructor(
        string memory name,
        string memory symbol,
        address admin,
        address[] memory allowed
    ) ERC721SeaDrop(name, symbol, admin, allowed) {}

    function mint(address recip, uint256 quantity) public payable {
        _mint(recip, quantity);
    }
}

contract TestSeaDrop is TestHelper {
    TestERC721 badToken;
    mapping(address => bool) seenAddresses;
    ERC721SeaDropPlusRegularMint snapshotToken;

    bytes32 merkleRoot;
    bytes32[] proof;
    Merkle tree;

    struct FuzzSelector {
        address targetAddress;
        bytes4[] targetSelectors;
    }

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        snapshotToken = new ERC721SeaDropPlusRegularMint(
            "",
            "",
            address(this),
            allowedSeaDrop
        );
        // Deploy a vanilla ERC721 token.
        badToken = new TestERC721();

        // Set the max supply to 1000.
        snapshotToken.setMaxSupply(1000);

        // Set the creator payout address.
        snapshotToken.updateCreatorPayoutAddress(address(seadrop), creator);

        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint64(block.timestamp), // start time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Set the public drop for the token contract.
        snapshotToken.updatePublicDrop(address(seadrop), publicDrop);
        snapshotToken.updateAllowedFeeRecipient(
            address(seadrop),
            address(5),
            true
        );
        vm.deal(address(5), 1 << 128);
        vm.deal(creator, 1 << 128);

        MintParams memory mintParams = MintParams({
            mintPrice: 0.1 ether,
            maxTotalMintableByWallet: 5,
            startTime: block.timestamp,
            endTime: block.timestamp + 1000,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 1000,
            feeBps: 100,
            restrictFeeRecipients: true
        });
        bytes32[] memory leaves = new bytes32[](1023);
        for (uint256 i = 0; i < leaves.length; ++i) {
            leaves[i] = keccak256(
                abi.encode(address(uint160(i + 1)), mintParams)
            );
        }
        leaves[50] = keccak256(abi.encode(address(this), mintParams));
        Merkle m = new Merkle();
        merkleRoot = m.getRoot(leaves);
        proof = m.getProof(leaves, 50);
        string[] memory publicKeyURIs = new string[](0);
        AllowListData memory allowListData = AllowListData({
            merkleRoot: merkleRoot,
            publicKeyURIs: publicKeyURIs,
            allowListURI: ""
        });
        snapshotToken.updateAllowList(address(seadrop), allowListData);
    }

    function testRegularMint_snapshot() public {
        snapshotToken.mint{ value: 0.1 ether }(address(this), 1);
    }

    function testMintPublic_snapshot() public {
        seadrop.mintPublic{ value: 0.1 ether }(
            address(snapshotToken),
            address(5),
            address(0),
            1
        );
    }

    function testMintAllowList_snapshot() public {
        MintParams memory mintParams = MintParams({
            mintPrice: 0.1 ether,
            maxTotalMintableByWallet: 5,
            startTime: block.timestamp,
            endTime: block.timestamp + 1000,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 1000,
            feeBps: 100,
            restrictFeeRecipients: true
        });
        seadrop.mintAllowList{ value: 0.1 ether }(
            address(snapshotToken),
            address(5),
            address(0),
            1,
            mintParams,
            proof
        );
    }
}
