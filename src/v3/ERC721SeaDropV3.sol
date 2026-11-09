// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropTokenV3Base } from "./SeaDropTokenV3Base.sol";

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

/**
 * @title  ERC721SeaDropV3
 * @notice A thin ERC-721 for SeaDropMinter: owner, allowed minters, max
 *         supply and metadata. Token ids start at 1.
 */
contract ERC721SeaDropV3 is ERC721A, SeaDropTokenV3Base {
    /// @notice The most tokens that can ever be minted.
    uint256 public maxSupply;

    string internal _tokenBaseURI;

    event MaxSupplyUpdated(uint256 maxSupply);

    error MaxSupplyBelowTotalMinted(uint256 maxSupply, uint256 totalMinted);

    constructor(string memory name, string memory symbol, address minter)
        ERC721A(name, symbol)
        SeaDropTokenV3Base(minter)
    { }

    /// @inheritdoc ISeaDropTokenV3
    function mintSeaDrop(address to, uint256, uint256 quantity) external {
        _checkMinter();

        uint256 total = _totalMinted() + quantity;
        if (total > maxSupply) {
            revert MintQuantityExceedsMaxSupply(total, maxSupply);
        }

        _safeMint(to, quantity);
    }

    /// @notice Set the max supply. It can't go below what's minted.
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        if (newMaxSupply < _totalMinted()) {
            revert MaxSupplyBelowTotalMinted(newMaxSupply, _totalMinted());
        }
        maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }

    /// @notice Set the base URI. Emits ERC-4906's BatchMetadataUpdate for
    ///         every token id, minted or not.
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _tokenBaseURI = newBaseURI;
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /// @inheritdoc ISeaDropTokenV3
    function mintStats(uint256)
        external
        view
        returns (uint256 totalMinted, uint256 maxSupply_)
    {
        return (_totalMinted(), maxSupply);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(ISeaDropTokenV3).interfaceId
            || interfaceId == 0x49064906 // ERC-4906
            || super.supportsInterface(interfaceId);
    }

    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
