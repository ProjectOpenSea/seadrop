// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;

import '../extensions/ERC4907AUpgradeable.sol';
import '../ERC721A__Initializable.sol';

contract ERC4907AMockUpgradeable is ERC721A__Initializable, ERC721AUpgradeable, ERC4907AUpgradeable {
    function __ERC4907AMock_init(string memory name_, string memory symbol_) internal onlyInitializingERC721A {
        __ERC721A_init_unchained(name_, symbol_);
        __ERC4907A_init_unchained();
        __ERC4907AMock_init_unchained(name_, symbol_);
    }

    function __ERC4907AMock_init_unchained(string memory, string memory) internal onlyInitializingERC721A {}

    function mint(address to, uint256 quantity) public {
        _mint(to, quantity);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721AUpgradeable, ERC4907AUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function explicitUserOf(uint256 tokenId) public view returns (address) {
        return _explicitUserOf(tokenId);
    }
}
