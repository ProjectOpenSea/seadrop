// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropTokenV3Base } from "./SeaDropTokenV3Base.sol";

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { ERC1155 } from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";

/**
 * @title  ERC1155SeaDropV3
 * @notice A thin ERC-1155 for SeaDropMinter: owner, allowed minters,
 *         per-id max supply and one URI for every id.
 *
 *         This contract's own state, the URI included, is in ERC-7201
 *         namespaced storage. OpenZeppelin 4.9's ERC1155 keeps balances and
 *         operator approvals in sequential slots 0 and 1. Its URI slot (2)
 *         stays empty, since `uri` reads the namespaced URI instead.
 */
contract ERC1155SeaDropV3 is ERC1155, SeaDropTokenV3Base {
    struct Supply {
        uint128 totalMinted;
        uint128 maxSupply;
    }

    /// @custom:storage-location erc7201:seadrop.v3.ERC1155SeaDropV3
    struct ERC1155Storage {
        mapping(uint256 id => Supply) supply;
        string uri;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256(
    ///      "seadrop.v3.ERC1155SeaDropV3")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant ERC1155_STORAGE_SLOT =
        0x2032b18d202658b0d56f376a10c2e031b632a48d257145366b93b7ac14da9d00;

    event MaxSupplyUpdated(uint256 indexed id, uint256 maxSupply);

    error MaxSupplyBelowTotalMinted(uint256 maxSupply, uint256 totalMinted);

    /// @dev Deploys the implementation. See SeaDropTokenV3Base.
    constructor(address conduit) ERC1155("") SeaDropTokenV3Base(conduit) { }

    /**
     * @notice Initialize a clone. Only the factory can call this, once.
     *
     * @param initialOwner The token's owner.
     * @param minter       The first allowed minter, the chain's
     *                     SeaDropMinter.
     */
    function initialize(address initialOwner, address minter) external {
        _initializeBase(initialOwner, minter);
    }

    /// @inheritdoc ISeaDropTokenV3
    function mintSeaDrop(address to, uint256 id, uint256 quantity) external {
        _checkMinter();

        Supply storage supply = _erc1155Storage().supply[id];
        Supply memory current = supply;
        uint256 total = current.totalMinted + quantity;
        if (total > current.maxSupply) {
            revert MintQuantityExceedsMaxSupply(total, current.maxSupply);
        }
        // total <= maxSupply, which fits in uint128.
        supply.totalMinted = uint128(total);

        _mint(to, id, quantity, "");
    }

    /// @notice Set an id's max supply. It can't go below what's minted.
    function setMaxSupply(uint256 id, uint128 newMaxSupply) external onlyOwner {
        Supply storage supply = _erc1155Storage().supply[id];
        uint256 totalMinted = supply.totalMinted;
        if (newMaxSupply < totalMinted) {
            revert MaxSupplyBelowTotalMinted(newMaxSupply, totalMinted);
        }
        supply.maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(id, newMaxSupply);
    }

    /// @notice Set the URI for every id. Emits ERC-4906's
    ///         BatchMetadataUpdate for every id, minted or not.
    function setURI(string calldata newURI) external onlyOwner {
        _erc1155Storage().uri = newURI;
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /// @notice The URI for every id, with `{id}` for clients to substitute.
    function uri(uint256) public view override returns (string memory) {
        return _erc1155Storage().uri;
    }

    /// @inheritdoc ISeaDropTokenV3
    function mintStats(uint256 id)
        external
        view
        returns (uint256 totalMinted, uint256 maxSupply)
    {
        Supply memory supply = _erc1155Storage().supply[id];
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
        if (_isConduit(operator)) return !_conduitRevoked(owner);
        return super.isApprovedForAll(owner, operator);
    }

    /// @notice Approve or revoke an operator, the preapproved conduit
    ///         included.
    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        if (_isConduit(operator)) {
            _setConduitRevoked(msg.sender, !approved);
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

    function _erc1155Storage()
        internal
        pure
        returns (ERC1155Storage storage $)
    {
        assembly {
            $.slot := ERC1155_STORAGE_SLOT
        }
    }
}
