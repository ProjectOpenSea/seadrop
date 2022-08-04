// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

struct PublicDrop {
    // up to 1.2m of native token, eg: ETH, MATIC
    uint80 mintPrice; //80/256 bits
    // check this is not zero
    uint64 startTime; // 144/256 bits
    // maximum total number of mints a user is allowed
    uint40 maxMintsPerWallet; // 184/256 bits
    // fee out of 10,000 basis points to be collected
    uint16 feeBps; // 200/256 bits
    // if false, allow any fee recipient; if true, check fee recipient is allowed
    bool restrictFeeRecipients; // 208/256 bits
}

// // Used to define parameters of a DropStage
// // Stages are strictly for front-end consumption, and are trusted to match
// // information in the AllowLists
// // (we may want to surface discrepancies on the front-end)
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

// an allow list leaf will be composed of msg.sender and the following params
// note: since feeBps is encoded in the leaf, backend should ensure that feeBps is
// acceptable before generating a proof
struct MintParams {
    uint256 mintPrice;
    uint256 maxTotalMintableByWallet;
    uint256 startTime;
    uint256 endTime;
    uint256 dropStage; // non-zero
    uint256 maxTokenSupplyForStage;
    uint256 feeBps;
    // do we want to offload here to avoid additional SLOAD?
    bool restrictFeeRecipients;
}

struct AllowListData {
    bytes32 merkleRoot;
    bytes32 leavesHash;
    bytes32 leavesEncryptionPublicKey;
    string leavesURI;
}

struct UserData {
    uint128 numMinted;
    uint128 allowListRedemptions;
}
