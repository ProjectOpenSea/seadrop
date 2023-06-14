// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ERC721RaribleDropStorage {
    struct Layout {
        /// @notice Track the allowed RaribleDrop addresses.
        mapping(address => bool) _allowedRaribleDrop;
        /// @notice Track the enumerated allowed RaribleDrop addresses.
        address[] _enumeratedAllowedRaribleDrop;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("openzepplin.contracts.storage.ERC721RaribleDrop");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
