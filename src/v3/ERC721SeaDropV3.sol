// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropTokenV3Base } from "./SeaDropTokenV3Base.sol";

import { ISeaDropMinter } from "./interfaces/ISeaDropMinter.sol";

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { ERC721AUpgradeable } from "ERC721A-Upgradeable/ERC721AUpgradeable.sol";

/**
 * @title  ERC721SeaDropV3
 * @notice A thin ERC-721 for SeaDropMinter: owner, allowed minters, max
 *         supply and metadata. Token ids start at 1.
 *
 *         It builds on ERC721A-Upgradeable 4.2.2, the same release as
 *         ERC721A 4.2.2 with its state in one hashed slot
 *         (`keccak256("ERC721A.contracts.storage.ERC721A")`) and an
 *         initializer instead of a constructor. Its transfer functions
 *         aren't payable. This contract's own state is in ERC-7201
 *         namespaced storage.
 */
contract ERC721SeaDropV3 is ERC721AUpgradeable, SeaDropTokenV3Base {
    struct StageConfig {
        uint256 stageIndex;
        ISeaDropMinter.Stage stage;
    }

    struct MultiConfigureStruct {
        uint256 maxSupply;
        string baseURI;
        string contractURI;
        address minter;
        ISeaDropMinter.PayoutRecipient[] payoutRecipients;
        StageConfig[] stages;
    }

    /// @custom:storage-location erc7201:seadrop.v3.ERC721SeaDropV3
    struct ERC721Storage {
        uint256 maxSupply;
        string baseURI;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256(
    ///      "seadrop.v3.ERC721SeaDropV3")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant ERC721_STORAGE_SLOT =
        0xe88258efc68c2124d32107a295743c18ce3fcb3efcd888edc1efbbb996fd2f00;

    event MaxSupplyUpdated(uint256 maxSupply);

    error MaxSupplyBelowTotalMinted(uint256 maxSupply, uint256 totalMinted);

    error IdNotZero(uint256 id);

    /// @dev Deploys the implementation. See SeaDropTokenV3Base.
    constructor(address conduit) SeaDropTokenV3Base(conduit) { }

    /**
     * @notice Initialize a clone. Only the factory can call this, once.
     *
     * @param initialOwner The token's owner.
     * @param minter       The first allowed minter, the chain's
     *                     SeaDropMinter.
     * @param name_        The token's name.
     * @param symbol_      The token's symbol.
     */
    function initialize(
        address initialOwner,
        address minter,
        string calldata name_,
        string calldata symbol_
    ) external initializerERC721A {
        _initializeBase(initialOwner, minter);
        __ERC721A_init_unchained(name_, symbol_);
    }

    /// @inheritdoc ISeaDropTokenV3
    function mintSeaDrop(address to, uint256 id, uint256 quantity) external {
        _checkMinter();
        if (id != 0) revert IdNotZero(id);

        uint256 max = _erc721Storage().maxSupply;
        uint256 total = _totalMinted() + quantity;
        if (total > max) revert MintQuantityExceedsMaxSupply(total, max);

        _safeMint(to, quantity);
    }

    /// @notice Set the max supply. It can't go below what's minted.
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        _setMaxSupply(newMaxSupply);
    }

    /// @notice The most tokens that can ever be minted.
    function maxSupply() external view returns (uint256) {
        return _erc721Storage().maxSupply;
    }

    /// @notice Set the base URI. Emits ERC-4906's BatchMetadataUpdate for
    ///         every token id, minted or not.
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _setBaseURI(newBaseURI);
    }

    /**
     * @notice Configure token supply, metadata, payout recipients and minter
     *         stages in one transaction.
     *
     *         Zero-value or empty fields are skipped. Use the individual
     *         setters to reset `maxSupply` to 0 or clear a URI.
     *
     * @param config The configuration struct.
     */
    function multiConfigure(MultiConfigureStruct calldata config)
        external
        onlyOwner
    {
        if (config.maxSupply > 0) {
            _setMaxSupply(config.maxSupply);
        }
        if (bytes(config.baseURI).length != 0) {
            _setBaseURI(config.baseURI);
        }
        if (bytes(config.contractURI).length != 0) {
            _setContractURI(config.contractURI);
        }

        uint256 stageCount = config.stages.length;
        if (config.payoutRecipients.length != 0 || stageCount != 0) {
            address previousMinter = _beginConfigure(config.minter);
            if (config.payoutRecipients.length != 0) {
                ISeaDropMinter(config.minter)
                    .setPayoutRecipients(address(this), config.payoutRecipients);
            }
            for (uint256 i = 0; i < stageCount; ++i) {
                StageConfig calldata entry = config.stages[i];
                ISeaDropMinter(config.minter)
                    .setStage(address(this), 0, entry.stageIndex, entry.stage);
            }
            _endConfigure(previousMinter);
        }
    }

    /// @inheritdoc ISeaDropTokenV3
    function mintStats(uint256)
        external
        view
        returns (uint256 totalMinted, uint256 maxSupply_)
    {
        return (_totalMinted(), _erc721Storage().maxSupply);
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
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(ISeaDropTokenV3).interfaceId
            || interfaceId == 0x49064906 // ERC-4906
            || super.supportsInterface(interfaceId);
    }

    function _setMaxSupply(uint256 newMaxSupply) internal {
        if (newMaxSupply < _totalMinted()) {
            revert MaxSupplyBelowTotalMinted(newMaxSupply, _totalMinted());
        }
        _erc721Storage().maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }

    function _setBaseURI(string calldata newBaseURI) internal {
        _erc721Storage().baseURI = newBaseURI;
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    function _baseURI() internal view override returns (string memory) {
        return _erc721Storage().baseURI;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function _erc721Storage() internal pure returns (ERC721Storage storage $) {
        assembly {
            $.slot := ERC721_STORAGE_SLOT
        }
    }
}
