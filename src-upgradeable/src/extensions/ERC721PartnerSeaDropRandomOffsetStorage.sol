// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {
    ERC721PartnerSeaDropRandomOffsetUpgradeable
} from "./ERC721PartnerSeaDropRandomOffsetUpgradeable.sol";
import {
    ERC721ContractMetadataUpgradeable
} from "../ERC721ContractMetadataUpgradeable.sol";

library ERC721PartnerSeaDropRandomOffsetStorage {
    struct Layout {
        /// @notice The random offset, between 1 and the MAX_SUPPLY at the time of
        ///         being set.
        uint256 randomOffset;
        /// @notice If the collection has been revealed and the randomOffset has
        ///         been set.
        bool revealed;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256(
            "openzepplin.contracts.storage.ERC721PartnerSeaDropRandomOffset"
        );

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
