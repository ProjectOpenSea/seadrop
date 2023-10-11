// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { TestERC721 } from "seadrop/test/TestERC721.sol";
import {
    AllowListData,
    MintParams,
    PublicDrop,
    TokenGatedDropStage,
    TokenGatedMintParams,
    SignedMintValidationParams
} from "seadrop/lib/SeaDropStructs.sol";

import { Merkle } from "murky/Merkle.sol";

contract ERC721SeaDropPlusRegularMint is ERC721SeaDrop {
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowed
    ) ERC721SeaDrop(name, symbol, allowed) {}

    function mint(address recip, uint256 quantity) public payable {
        _mint(recip, quantity);
    }
}

contract TestSeaDropSnapshot is TestHelper {
    TestERC721 tokenGatedEligible;
    mapping(address => bool) seenAddresses;
    ERC721SeaDropPlusRegularMint snapshotToken;

    bytes32 merkleRoot;
    bytes32[] proof;
    Merkle tree;
    bytes signature;
    bytes signature2098;
    MintParams mintParams;
    SignedMintValidationParams signedMintValidationParams;

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        snapshotToken = new ERC721SeaDropPlusRegularMint(
            "",
            "",
            allowedSeaDrop
        );
        // Deploy a standard ERC721 token.
        tokenGatedEligible = new TestERC721();

        // Set the max supply to 1000.
        snapshotToken.setMaxSupply(1000);

        // Set the creator payout address.
        snapshotToken.updateCreatorPayoutAddress(address(seadrop), creator);

        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
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

        mintParams = MintParams({
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

        _configureTokenGated();

        tokenGatedEligible.mint(address(this), 1);

        signedMintValidationParams.maxEndTime = type(uint40).max;
        signedMintValidationParams.maxMaxTotalMintableByWallet = type(uint16)
            .max;
        signedMintValidationParams.maxMaxTokenSupplyForStage = type(uint16).max;
        signedMintValidationParams.maxFeeBps = 10000;
        _configureSigner();
    }

    function _configureTokenGated() internal {
        TokenGatedDropStage memory tokenGatedDropStage = TokenGatedDropStage({
            mintPrice: 0.1 ether, // mint price
            maxTotalMintableByWallet: 10, // max mints per wallet
            startTime: uint48(block.timestamp), // start time
            endTime: uint48(block.timestamp) + 1000,
            dropStageIndex: 1,
            maxTokenSupplyForStage: 1000, // max supply for stage
            feeBps: 100, // fee (1%)
            restrictFeeRecipients: false // if false, allow any fee recipient
        });
        snapshotToken.updateTokenGatedDrop(
            address(seadrop),
            address(tokenGatedEligible),
            tokenGatedDropStage
        );
    }

    function _configureSigner() internal {
        address signer = makeAddr("signer");
        snapshotToken.updateSignedMintValidationParams(
            address(seadrop),
            signer,
            signedMintValidationParams
        );
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "signer",
            address(snapshotToken),
            address(this),
            address(5),
            mintParams,
            1010101
        );
        signature = abi.encodePacked(r, s, v);
        signature2098 = _encodeSignature2098(r, s, v);
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
        seadrop.mintAllowList{ value: 0.1 ether }(
            address(snapshotToken),
            address(5),
            address(0),
            1,
            mintParams,
            proof
        );
    }

    function testMintAllowedTokenHolder_snapshot() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        TokenGatedMintParams
            memory tokenGatedMintParams = TokenGatedMintParams({
                allowedNftToken: address(tokenGatedEligible),
                allowedNftTokenIds: ids
            });
        seadrop.mintAllowedTokenHolder{ value: 0.1 ether }(
            address(snapshotToken),
            address(5),
            address(0),
            tokenGatedMintParams
        );
    }

    function testMintSigned_snapshot() public {
        seadrop.mintSigned{ value: 0.1 ether }(
            address(snapshotToken),
            address(5),
            address(0),
            1,
            mintParams,
            1010101,
            signature
        );
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
