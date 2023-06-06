// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PublicDrop,
    SignedMintValidationParams
} from "./ERC1155SeaDropStructs.sol";

import { CreatorPayout } from "./SeaDropStructs.sol";

library ERC1155SeaDropContractOffererStorage {
    struct Layout {
        /// @notice The allowed Seaport addresses that can mint.
        mapping(address => bool) _allowedSeaport;
        /// @notice The enumerated allowed Seaport addresses.
        address[] _enumeratedAllowedSeaport;
        /// @notice The public drop data.
        mapping(uint256 => PublicDrop) _publicDrops;
        /// @notice The enumerated public drop indexes.
        uint256[] _enumeratedPublicDropIndexes;
        /// @notice The creator payout addresses and basis points.
        CreatorPayout[] _creatorPayouts;
        /// @notice The allow list merkle root.
        bytes32 _allowListMerkleRoot;
        /// @notice The allowed fee recipients.
        mapping(address => bool) _allowedFeeRecipients;
        /// @notice The enumerated allowed fee recipients.
        address[] _enumeratedFeeRecipients;
        /// @notice The parameters for allowed signers for server-side drops by index.
        mapping(address => mapping(uint256 => SignedMintValidationParams)) _signedMintValidationParams;
        /// @notice The signers for each server-side drop.
        address[] _enumeratedSigners;
        /// @notice The enumerated indexes for the signer validation params.
        mapping(address => uint256[]) _enumeratedSignedMintValidationParamsIndexes;
        /// @notice The used signature digests.
        mapping(bytes32 => bool) _usedDigests;
        /// @notice The allowed payers.
        mapping(address => bool) _allowedPayers;
        /// @notice The enumerated allowed payers.
        address[] _enumeratedPayers;
    }

    bytes32 internal constant STORAGE_SLOT =
        bytes32(
            uint256(
                keccak256("contracts.storage.ERC1155SeaDropContractOfferer")
            ) - 1
        );

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
