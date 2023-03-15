// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ERC721SeaDropStorage {
    struct Layout {
        /// @notice Track the allowed SeaDrop addresses.
        mapping(address => bool) _allowedSeaDrop;
        /// @notice Track the enumerated allowed SeaDrop addresses.
        address[] _enumeratedAllowedSeaDrop;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("openzepplin.contracts.storage.ERC721SeaDrop");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
