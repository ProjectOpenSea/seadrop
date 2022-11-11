// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;

import '../extensions/ERC721ABurnableUpgradeable.sol';
import '../ERC721A__Initializable.sol';

contract ERC721ABurnableMockUpgradeable is ERC721A__Initializable, ERC721AUpgradeable, ERC721ABurnableUpgradeable {
    function __ERC721ABurnableMock_init(string memory name_, string memory symbol_) internal onlyInitializingERC721A {
        __ERC721A_init_unchained(name_, symbol_);
        __ERC721ABurnable_init_unchained();
        __ERC721ABurnableMock_init_unchained(name_, symbol_);
    }

    function __ERC721ABurnableMock_init_unchained(string memory, string memory) internal onlyInitializingERC721A {}

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function safeMint(address to, uint256 quantity) public {
        _safeMint(to, quantity);
    }

    function getOwnershipAt(uint256 index) public view returns (TokenOwnership memory) {
        return _ownershipAt(index);
    }

    function totalMinted() public view returns (uint256) {
        return _totalMinted();
    }

    function totalBurned() public view returns (uint256) {
        return _totalBurned();
    }

    function numberBurned(address owner) public view returns (uint256) {
        return _numberBurned(owner);
    }
}
