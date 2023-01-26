// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {StartTokenIdHelperUpgradeable} from './StartTokenIdHelperUpgradeable.sol';

library StartTokenIdHelperStorage {
    struct Layout {
        uint256 startTokenId;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256('ERC721A.contracts.storage.StartTokenIdHelper');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
