// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;

import './ERC721AQueryableMockUpgradeable.sol';
import './StartTokenIdHelperUpgradeable.sol';
import {StartTokenIdHelperStorage} from './StartTokenIdHelperStorage.sol';
import '../ERC721A__Initializable.sol';

contract ERC721AQueryableStartTokenIdMockUpgradeable is
    ERC721A__Initializable,
    StartTokenIdHelperUpgradeable,
    ERC721AQueryableMockUpgradeable
{
    using StartTokenIdHelperStorage for StartTokenIdHelperStorage.Layout;

    function __ERC721AQueryableStartTokenIdMock_init(
        string memory name_,
        string memory symbol_,
        uint256 startTokenId_
    ) internal onlyInitializingERC721A {
        __StartTokenIdHelper_init_unchained(startTokenId_);
        __ERC721A_init_unchained(name_, symbol_);
        __ERC721AQueryable_init_unchained();
        __ERC721ABurnable_init_unchained();
        __ERC721AQueryableMock_init_unchained(name_, symbol_);
        __ERC721AQueryableStartTokenIdMock_init_unchained(name_, symbol_, startTokenId_);
    }

    function __ERC721AQueryableStartTokenIdMock_init_unchained(
        string memory,
        string memory,
        uint256
    ) internal onlyInitializingERC721A {}

    function _startTokenId() internal view override returns (uint256) {
        return StartTokenIdHelperStorage.layout().startTokenId;
    }
}
