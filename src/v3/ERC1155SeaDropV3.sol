// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropTokenV3Base } from "./SeaDropTokenV3Base.sol";

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { ERC1155 } from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";

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

    event MaxSupplyUpdated(uint256 indexed id, uint256 maxSupply);

    error MaxSupplyBelowTotalMinted(uint256 maxSupply, uint256 totalMinted);

    constructor(address minter, address conduit)
        ERC1155("")
        SeaDropTokenV3Base(minter, conduit)
    { }

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
        _setURI(newURI);
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

    /**
     * @notice Every holder starts with the preapproved conduit approved
     *         for all their tokens. A holder revokes or restores that with
     *         `setApprovalForAll(preapprovedConduit, approved)`.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        if (_isConduit(operator)) return !_conduitRevoked[owner];
        return super.isApprovedForAll(owner, operator);
    }

    /// @notice Approve or revoke an operator, the preapproved conduit
    ///         included.
    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        if (_isConduit(operator)) {
            _conduitRevoked[msg.sender] = !approved;
            emit ApprovalForAll(msg.sender, operator, approved);
            return;
        }
        super.setApprovalForAll(operator, approved);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        // ERC-4906 extends ERC-721, so this token emits its
        // BatchMetadataUpdate event without claiming the interface.
        return interfaceId == type(ISeaDropTokenV3).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
