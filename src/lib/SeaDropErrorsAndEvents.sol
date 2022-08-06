// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { PublicDrop, TokenGatedDropStage } from "./SeaDropStructs.sol";

interface SeaDropErrorsAndEvents {
    error NotActive(
        uint256 currentTimestamp,
        uint256 startTimestamp,
        uint256 endTimestamp
    );
    error AmountExceedsMaxPerTransaction(uint256 amount, uint256 allowed);
    error AmountExceedsMaxPerWallet(uint256 total, uint256 allowed);
    // todo: should allowlist redemptions happen per-list?
    error AllowListRedeemed();
    error IncorrectPayment(uint256 got, uint256 want);
    error InvalidProof();
    error InvalidSignature(address recoveredSigner);
    error OnlyIERC721SeaDrop(address sender);

    error TokenGatedNotTokenOwner(address nftContract, address allowedNftContract, uint256 tokenId);
    error TokenGatedTokenIdAlreadyRedeemed(address nftContract, address allowedNftContract, uint256 tokenId);

    // emitted as part of mint for analytics purposes
    event SeaDropMint(
        address indexed nftContract,
        address indexed minter,
        address indexed feeRecipient,
        uint256 numberMinted,
        uint256 unitMintPrice,
        uint256 feeBps,
        uint256 dropStageIndex // non-zero is an allow-list tier
    );

    event PublicDropUpdated(address indexed nftContract, PublicDrop publicDrop);

    event TokenGatedDropStageUpdated(
        address indexed nftContract,
        address indexed allowedNftToken,
        TokenGatedDropStage dropStage
    );

    event AllowListUpdated(
        address indexed nftContract,
        bytes32 indexed previousMerkleRoot,
        bytes32 indexed newMerkleRoot,
        string[] publicKeyURI, // empty if unencrypted
        string allowListURI
    );

    event DropURIUpdated(address indexed nftContract, string newDropURI);

    event CreatorPayoutAddressUpdated(
        address indexed nftContract,
        address indexed creatorPayoutAddressUpdated
    );

    event AllowedFeeRecipientUpdated(
        address indexed nftContract,
        address indexed newFeeRecipient,
        bool indexed allowed
    );

    event SignersUpdated(
        address indexed nftContract,
        address[] previousSigners,
        address[] newSigners
    );
}
