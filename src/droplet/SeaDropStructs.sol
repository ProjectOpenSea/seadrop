// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

struct PublicDrop {
    // up to 1.2m of native token, eg: ETH, MATIC
    uint80 mintPrice; //80/256 bits
    // when drop stage starts being active
    uint64 startTime; // 144/256 bits
    // when drop stage stops being active
    uint64 endTime; // 208/256 bits
    // maximum number of mints for the public drop
    // which contract should check this?
    uint16 maxMintsPerWallet; // 224/256 bits
    // TODO: do we need this?
    // maxmium number of mints per transaction for the public drop
    uint16 maxMintsPerTransaction; // 240/256 bits
    // fee out of 10,000 basis points that we will collect - TBD?
    uint16 feeBps; // 256/256 bits
}

struct AllowListMint {
    uint256 numToMint;
    uint256 mintPrice;
    uint256 maxNumberMinted;
    uint256 startTime;
    uint256 endTime;
    uint256 allowListIndex;
    uint256 feeBps;
}

struct AllowListMintOption {
    uint256 numToMint;
    uint256 tokenOrOptionIdToMint;
    uint256 mintPrice;
    uint256 maxNumberMinted;
    uint256 startTime;
    uint256 endTime;
    uint256 allowListIndex;
    uint256 feeBps;
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
