// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

/**
 * @notice A struct defining public drop data.
 *         Designed to fit efficiently in one storage slot.
 */
struct PublicDrop {
    // Up to 1.2m of native token, e.g.: ETH, MATIC
    uint80 mintPrice; // 80/256 bits
    // Ensure this is not zero.
    uint64 startTime; // 144/256 bits
    // Maximum total number of mints a user is allowed.
    uint40 maxMintsPerWallet; // 184/256 bits
    // Fee out of 10,000 basis points to be collected.
    uint16 feeBps; // 200/256 bits
    // If false, allow any fee recipient; if true, check fee recipient is allowed.
    bool restrictFeeRecipients; // 208/256 bits
}

// Stages from dropURI are strictly for front-end consumption,
// and are trusted to match information in the
// PublicDrop, AllowLists or TokenGatedDropStage
// (we may want to surface discrepancies on the front-end)

/**
 * @notice A struct defining token gated drop stage data.
 *         Designed to fit efficiently in one storage slot.
 */
struct TokenGatedDropStage {
    uint80 mintPrice;
    uint16 maxTotalMintableByWallet;
    uint48 startTime;
    uint48 endTime;
    uint8 dropStage;
    uint40 maxTokenSupplyForStage;
    uint16 feeBps;
    bool restrictFeeRecipients;
}

/**
 * @notice A struct defining mint params for an allow list.
 *         An allow list leaf will be composed of `msg.sender` and
 *         the following params.
 * 
 *         Note: Since feeBps is encoded in the leaf, backend should ensure
 *         that feeBps is acceptable before generating a proof.
 */
struct MintParams {
    uint256 mintPrice;
    uint256 maxTotalMintableByWallet;
    uint256 startTime;
    uint256 endTime;
    uint256 dropStage; // non-zero
    uint256 maxTokenSupplyForStage;
    uint256 feeBps;
    bool restrictFeeRecipients;
}

/**
 * @notice A struct defining token gated mint params.
 */
struct TokenGatedMintParams {
    address allowedNftToken;
    uint256[] allowedNftTokenIds;
}

/**
 * @notice A struct defining allow list data (for minting an allow list).
 */
struct AllowListData {
    bytes32 merkleRoot;
    string[] publicKeyURIs;
    string leavesURI;
}

/**
 * @notice A struct for validating payment for the mint.
 */
struct PaymentValidation {
    uint256 numberToMint;
    uint256 mintPrice;
}