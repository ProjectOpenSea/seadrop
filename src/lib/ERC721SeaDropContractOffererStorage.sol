// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PublicDrop } from "./ERC721SeaDropStructs.sol";

import { CreatorPayout } from "./SeaDropStructs.sol";

library ERC721SeaDropContractOffererStorage {
    /**
     * @notice Who a Seaport call minted to, for safeTransferFrom to check
     *         Seaport's recipient against. Opened by the call's first mint
     *         order in generateOrder and cleared in ratifyOrder.
     */
    struct MintRecord {
        /// @notice The minter of the call's first mint order.
        address minter;
        /// @notice Whether the call has mint orders for more than one minter.
        bool multipleMinters;
        /// @notice The low 88 bits of the allowed Seaport whose call opened
        ///         the record, packed with the fields above into one slot.
        ///         Only that Seaport can add to the record or clear it.
        uint88 seaport;
        /// @notice The fulfiller of the call, written only when it differs
        ///         from the minter. Zero means the minter.
        address fulfiller;
    }

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
        /// @notice The allowed server-side signers.
        mapping(address => bool) _allowedSigners;
        /// @notice The enumerated allowed signers.
        address[] _enumeratedSigners;
        /// @notice The used signature digests.
        mapping(bytes32 => bool) _usedDigests;
        /// @notice The allowed payers.
        mapping(address => bool) _allowedPayers;
        /// @notice The enumerated allowed payers.
        address[] _enumeratedPayers;
        /// @notice Who the current Seaport call minted to.
        MintRecord _mintRecord;
    }

    bytes32 internal constant STORAGE_SLOT = bytes32(
        uint256(keccak256("contracts.storage.ERC721SeaDropContractOfferer")) - 1
    );

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
