// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropTokenV3Base } from "./SeaDropTokenV3Base.sol";

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { ERC1155 } from "solmate/tokens/ERC1155.sol";

/**
 * @title  ERC1155SeaDropV3
 * @notice A thin ERC-1155 for SeaDropMinter: owner, allowed minters,
 *         per-id max supply and one URI for every id.
 */
contract ERC1155SeaDropV3 is ERC1155, SeaDropTokenV3Base {
    struct Supply {
        uint128 totalMinted;
        uint128 maxSupply;
    }

    mapping(uint256 id => Supply) internal _supply;

    string internal _uri;

    event MaxSupplyUpdated(uint256 indexed id, uint256 maxSupply);

    error MaxSupplyBelowTotalMinted(uint256 maxSupply, uint256 totalMinted);

    constructor(address minter) SeaDropTokenV3Base(minter) { }

    /// @inheritdoc ISeaDropTokenV3
    function mintSeaDrop(address to, uint256 id, uint256 quantity) external {
        _checkMinter();

        Supply memory supply = _supply[id];
        uint256 total = supply.totalMinted + quantity;
        if (total > supply.maxSupply) {
            revert MintQuantityExceedsMaxSupply(total, supply.maxSupply);
        }
        // total <= maxSupply, which fits in uint128.
        _supply[id].totalMinted = uint128(total);

        _mint(to, id, quantity, "");
    }

    /// @notice Set an id's max supply. It can't go below what's minted.
    function setMaxSupply(uint256 id, uint128 newMaxSupply) external onlyOwner {
        uint256 totalMinted = _supply[id].totalMinted;
        if (newMaxSupply < totalMinted) {
            revert MaxSupplyBelowTotalMinted(newMaxSupply, totalMinted);
        }
        _supply[id].maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(id, newMaxSupply);
    }

    /// @notice Set the URI for every id. Emits ERC-4906's
    ///         BatchMetadataUpdate for every id, minted or not.
    function setURI(string calldata newURI) external onlyOwner {
        _uri = newURI;
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /// @inheritdoc ISeaDropTokenV3
    function mintStats(uint256 id)
        external
        view
        returns (uint256 totalMinted, uint256 maxSupply)
    {
        Supply memory supply = _supply[id];
        return (supply.totalMinted, supply.maxSupply);
    }

    function uri(uint256) public view override returns (string memory) {
        return _uri;
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
}
