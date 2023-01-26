// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC721ReceiverMockUpgradeable} from './ERC721ReceiverMockUpgradeable.sol';

library ERC721ReceiverMockStorage {
    struct Layout {
        bytes4 _retval;
        address _erc721aMock;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256('ERC721A.contracts.storage.ERC721ReceiverMock');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}
