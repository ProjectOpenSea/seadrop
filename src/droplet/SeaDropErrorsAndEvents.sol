// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { PublicDrop } from "./SeaDropStructs.sol";

interface SeaDropErrorsAndEvents {
    // todo: don't think publicdrop benefits from indexed
    error OnlySeaDrop();

    event PublicDropUpdated(
        address indexed nftContract,
        PublicDrop indexed newPublicDrop
    );
    event SaleTokenUpdated(
        address indexed nftContract,
        address indexed newSaleToken
    );
    event AllowListUpdated(
        address indexed nftContract,
        bytes32 indexed encryptionPublicKey,
        bytes32 indexed newMerkleRoot,
        // for verifying retrieved leaves
        bytes32 leavesHash,
        string leavesURI
    );
    event DropURIUpdated(address indexed nftContract, string newDropURI);
    event PayoutAddressUpdated(
        address indexed nftContract,
        address indexed newPayoutAddress
    );
}
