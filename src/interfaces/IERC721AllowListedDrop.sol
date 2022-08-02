// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721Drop } from "./IERC721Drop.sol";

interface IERC721AllowlistedDrop is IERC721Drop {
    event MerkleRootUpdated(
        bytes32 indexed newMerkleRoot,
        address indexed encryptionPublicKey,
        string leavesURI
    );

    // Struct to hold AllowListMint params.
    // Note: When calculating allowlist root, the values should not be "packed"
    // according to abi.encodePacked.
    struct AllowListMint {
        uint256 option;
        uint256 numToMint;
        uint256 mintPrice;
        uint256 maxNumberMinted;
        uint256 startTime;
        uint256 endTime;
        uint256 allowListIndex;
        uint256 feeBps;
    }

    function setMerkleRoot(
        bytes32 newMerkleRoot,
        address leavesEncryptionPublicKey,
        string calldata leavesURI
    ) external;

    function mintAllowList(
        AllowListMint calldata mintParams,
        bytes32[] calldata proof
    ) external payable;
}
