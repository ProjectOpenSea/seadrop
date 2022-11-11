// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;

import './ERC721AMockUpgradeable.sol';
import '../ERC721A__Initializable.sol';

contract ERC721ATransferCounterMockUpgradeable is ERC721A__Initializable, ERC721AMockUpgradeable {
    function __ERC721ATransferCounterMock_init(string memory name_, string memory symbol_)
        internal
        onlyInitializingERC721A
    {
        __ERC721A_init_unchained(name_, symbol_);
        __ERC721AMock_init_unchained(name_, symbol_);
        __ERC721ATransferCounterMock_init_unchained(name_, symbol_);
    }

    function __ERC721ATransferCounterMock_init_unchained(string memory, string memory)
        internal
        onlyInitializingERC721A
    {}

    function _extraData(
        address from,
        address to,
        uint24 previousExtraData
    ) internal view virtual override returns (uint24) {
        if (from == address(0)) {
            return 42;
        }
        if (to == address(0)) {
            return 1337;
        }
        return previousExtraData + 1;
    }

    function setExtraDataAt(uint256 index, uint24 extraData) public {
        _setExtraDataAt(index, extraData);
    }
}
