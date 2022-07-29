// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721Drop } from "./IERC721Drop.sol";

interface IERC721AllowlistedDrop is IERC721Drop {
    event MerkleRootUpdated(
        bytes32 indexed newMerkleRoot,
        address indexed encryptionPublicKey,
        string leavesURI
    );

    function setMerkleRoot(
        bytes32 newMerkleRoot,
        address leavesEncryptionPublicKey,
        string calldata leavesURI
    ) external;

    function mintAllowList(
        uint256 numToMint,
        uint256 mintPrice,
        uint256 maxMintable,
        uint256 startTime,
        uint256 endTime,
        uint256 feeBps,
        bytes32[] calldata proof
    ) external payable;
}
