// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library ERC721SeaDropRandomOffsetStorage {
    struct Layout {
        /// @notice The random offset, between 0 and maxSupply - 2 at the time
        ///         of being set (0 when maxSupply is 1).
        uint256 randomOffset;
        /// @notice If the collection has been revealed and the randomOffset has
        ///         been set.
        bool revealed;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("openzepplin.contracts.storage.ERC721SeaDropRandomOffset");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
