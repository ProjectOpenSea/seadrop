// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { PublicDrop } from "./SeaDropStructs.sol";

interface SeaDropErrorsAndEvents {
    error InvalidProof();
    error InvalidSignature(address recoveredSigner);

    event PublicDropUpdated(address indexed nftContract, PublicDrop publicDrop);

    event AllowListUpdated(
        address indexed nftContract,
        bytes32 indexed encryptionPublicKey,
        bytes32 indexed newMerkleRoot,
        // for verifying retrieved leaves
        bytes32 allowListHash,
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
