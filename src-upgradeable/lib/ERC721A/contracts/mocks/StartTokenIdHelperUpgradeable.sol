// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;
import {StartTokenIdHelperStorage} from './StartTokenIdHelperStorage.sol';
import '../ERC721A__Initializable.sol';

/**
 * This Helper is used to return a dynamic value in the overridden _startTokenId() function.
 * Extending this Helper before the ERC721A contract give us access to the herein set `startTokenId`
 * to be returned by the overridden `_startTokenId()` function of ERC721A in the ERC721AStartTokenId mocks.
 */
contract StartTokenIdHelperUpgradeable is ERC721A__Initializable {
    using StartTokenIdHelperStorage for StartTokenIdHelperStorage.Layout;

    function __StartTokenIdHelper_init(uint256 startTokenId_) internal onlyInitializingERC721A {
        __StartTokenIdHelper_init_unchained(startTokenId_);
    }

    function __StartTokenIdHelper_init_unchained(uint256 startTokenId_) internal onlyInitializingERC721A {
        StartTokenIdHelperStorage.layout().startTokenId = startTokenId_;
    }

    // generated getter for ${varDecl.name}
    function startTokenId() public view returns (uint256) {
        return StartTokenIdHelperStorage.layout().startTokenId;
    }
}
