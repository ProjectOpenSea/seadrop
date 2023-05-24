// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PublicDrop,
    SignedMintValidationParams
} from "./ERC721SeaDropStructs.sol";

import { CreatorPayout } from "./SeaDropStructs.sol";

library ERC721SeaDropContractOffererStorage {
    struct Layout {
        /// @notice The allowed Seaport addresses that can mint.
        mapping(address => bool) _allowedSeaport;
        /// @notice The enumerated allowed Seaport addresses.
        address[] _enumeratedAllowedSeaport;
        /// @notice The public drop data.
        PublicDrop _publicDrop;
        /// @notice The creator payout addresses and basis points.
        CreatorPayout[] _creatorPayouts;
        /// @notice The allow list merkle root.
        bytes32 _allowListMerkleRoot;
        /// @notice The allowed fee recipients.
        mapping(address => bool) _allowedFeeRecipients;
        /// @notice The enumerated allowed fee recipients.
        address[] _enumeratedFeeRecipients;
        /// @notice The parameters for allowed signers for server-side drops.
        mapping(address => SignedMintValidationParams) _signedMintValidationParams;
        /// @notice The signers for each server-side drop.
        address[] _enumeratedSigners;
        /// @notice The used signature digests.
        mapping(bytes32 => bool) _usedDigests;
        /// @notice The allowed payers.
        mapping(address => bool) _allowedPayers;
        /// @notice The enumerated allowed payers.
        address[] _enumeratedPayers;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("contracts.storage.ERC721SeaDropContractOfferer");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
