// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;

import '../ERC721AUpgradeable.sol';
import '../ERC721A__Initializable.sol';

contract ERC721AMockUpgradeable is ERC721A__Initializable, ERC721AUpgradeable {
    function __ERC721AMock_init(string memory name_, string memory symbol_) internal onlyInitializingERC721A {
        __ERC721A_init_unchained(name_, symbol_);
        __ERC721AMock_init_unchained(name_, symbol_);
    }

    function __ERC721AMock_init_unchained(string memory, string memory) internal onlyInitializingERC721A {}

    function numberMinted(address owner) public view returns (uint256) {
        return _numberMinted(owner);
    }

    function totalMinted() public view returns (uint256) {
        return _totalMinted();
    }

    function totalBurned() public view returns (uint256) {
        return _totalBurned();
    }

    function nextTokenId() public view returns (uint256) {
        return _nextTokenId();
    }

    function getAux(address owner) public view returns (uint64) {
        return _getAux(owner);
    }

    function setAux(address owner, uint64 aux) public {
        _setAux(owner, aux);
    }

    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function safeMint(address to, uint256 quantity) public {
        _safeMint(to, quantity);
    }

    function safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) public {
        _safeMint(to, quantity, _data);
    }

    function mint(address to, uint256 quantity) public {
        _mint(to, quantity);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function burn(uint256 tokenId, bool approvalCheck) public {
        _burn(tokenId, approvalCheck);
    }

    function toString(uint256 x) public pure returns (string memory) {
        return _toString(x);
    }

    function getOwnershipAt(uint256 index) public view returns (TokenOwnership memory) {
        return _ownershipAt(index);
    }

    function getOwnershipOf(uint256 index) public view returns (TokenOwnership memory) {
        return _ownershipOf(index);
    }

    function initializeOwnershipAt(uint256 index) public {
        _initializeOwnershipAt(index);
    }
}
