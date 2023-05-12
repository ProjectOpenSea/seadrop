// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
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
        /// @notice The token gated drop stages.
        mapping(address => TokenGatedDropStage) _tokenGatedDrops;
        /// @notice The tokens for token gated drops.
        address[] _enumeratedTokenGatedTokens;
        /// @notice The token ids and redeemed counts for token gated drop stages.
        mapping(address => mapping(uint256 => uint256)) _tokenGatedRedeemed;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("contracts.storage.ERC1155SeaDropContractOfferer");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
