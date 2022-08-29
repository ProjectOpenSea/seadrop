// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    ERC721ContractMetadata,
    IERC721ContractMetadata
} from "./ERC721ContractMetadata.sol";

import {
    IERC721SeaDrop,
    IERC721ContractMetadata
} from "./interfaces/IERC721SeaDrop.sol";

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage
} from "./lib/SeaDropStructs.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

import {
    IERC721
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import {
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/**
 * @title  ERC721SeaDrop
 * @author jameswenzel, ryanio, stephankmin
 * @notice ERC721SeaDrop is a token contract that contains methods
 *         to properly interact with SeaDrop.
 */
contract ERC721SeaDrop is ERC721ContractMetadata, IERC721SeaDrop {
    /// @notice Track the allowed SeaDrop addresses.
    mapping(address => bool) private _allowedSeaDrop;

    /// @notice Track the enumerated allowed SeaDrop addresses.
    address[] internal _enumeratedAllowedSeaDrop;

    /**
     * @notice Modifier to restrict sender exclusively to
     *         allowed SeaDrop contracts.
     */
    modifier onlySeaDrop() {
        if (_allowedSeaDrop[msg.sender] != true) {
            revert OnlySeaDrop();
        }
        _;
    }

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) ERC721ContractMetadata(name, symbol, administrator) {
        // Set the mapping for allowed SeaDrop contracts.
        for (uint256 i = 0; i < allowedSeaDrop.length; ) {
            _allowedSeaDrop[allowedSeaDrop[i]] = true;
            unchecked {
                ++i;
            }
        }

        // Set the enumeration.
        _enumeratedAllowedSeaDrop = allowedSeaDrop;
    }

    /**
     * @notice Update the allowed SeaDrop contracts.
     *
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     */
    function updateAllowedSeaDrop(address[] calldata allowedSeaDrop)
        external
        override
        onlyOwnerOrAdministrator
    {
        // Reset the old mapping.
        for (uint256 i = 0; i < _enumeratedAllowedSeaDrop.length; ) {
            _allowedSeaDrop[_enumeratedAllowedSeaDrop[i]] = false;
            unchecked {
                ++i;
            }
        }

        // Set the new mapping for allowed SeaDrop contracts.
        for (uint256 i = 0; i < allowedSeaDrop.length; ) {
            _allowedSeaDrop[allowedSeaDrop[i]] = true;
            unchecked {
                ++i;
            }
        }

        // Set the enumeration.
        _enumeratedAllowedSeaDrop = allowedSeaDrop;

        // Emit an event for the update.
        emit AllowedSeaDropUpdated(allowedSeaDrop);
    }

    /**
     * @notice Mint tokens, restricted to the SeaDrop contract.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 quantity)
        external
        payable
        override
        onlySeaDrop
    {
        // Mint the quantity of tokens to the minter.
        _mint(minter, quantity);
    }

    /**
     * @notice Update public drop data for this nft contract on SeaDrop.
     *         Use `updatePublicDropFee` to update the fee recipient or feeBps.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external virtual override onlyOwner {
        // Track the previous public drop data.
        PublicDrop memory retrieved = ISeaDrop(seaDropImpl).getPublicDrop(
            address(this)
        );

        // Track the newly supplied drop data.
        PublicDrop memory supplied = publicDrop;

        // Only the administrator (OpenSea) should be able to set feeBps.
        supplied.feeBps = retrieved.feeBps;
        supplied.restrictFeeRecipients = true;

        // Update the public drop data on SeaDrop.
        ISeaDrop(seaDropImpl).updatePublicDrop(supplied);
    }

    /**
     * @notice Update public drop fee for this nft contract on SeaDrop.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param feeBps      The public drop fee basis points.
     */
    function updatePublicDropFee(address seaDropImpl, uint16 feeBps)
        external
        virtual
        onlyAdministrator
    {
        // Track the previous public drop data.
        PublicDrop memory retrieved = ISeaDrop(seaDropImpl).getPublicDrop(
            address(this)
        );

        // Only the administrator (OpenSea) should be able to set feeBps.
        retrieved.feeBps = feeBps;
        retrieved.restrictFeeRecipients = true;

        // Update the public drop data on SeaDrop.
        ISeaDrop(seaDropImpl).updatePublicDrop(retrieved);
    }

    /**
     * @notice Update allow list data for this nft contract on SeaDrop.
     *
     * @param seaDropImpl   The allowed SeaDrop contract.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    ) external virtual override onlyOwnerOrAdministrator {
        // Update the allow list on SeaDrop.
        ISeaDrop(seaDropImpl).updateAllowList(allowListData);
    }

    /**
     * @notice Update token gated drop stage data for this nft contract
     *         on SeaDrop.
     *         Use `updateTokenGatedDropFee` to update the fee basis points.
     *
     * @param seaDropImpl     The allowed SeaDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address seaDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external virtual override onlyOwner {
        // Track the previous drop stage data.
        TokenGatedDropStage memory retrieved = ISeaDrop(seaDropImpl)
            .getTokenGatedDrop(address(this), allowedNftToken);

        // Track the newly supplied drop data.
        TokenGatedDropStage memory supplied = dropStage;

        // Only the administrator (OpenSea) should be able to set feeBps.
        supplied.feeBps = retrieved.feeBps;
        supplied.restrictFeeRecipients = true;

        // Update the token gated drop stage.
        ISeaDrop(seaDropImpl).updateTokenGatedDrop(allowedNftToken, supplied);
    }

    /**
     * @notice Update token gated drop stage fee basis points for this nft
     *         contract on SeaDrop.
     *
     * @param seaDropImpl     The allowed SeaDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param feeBps          The token gated drop fee basis points.
     */
    function updateTokenGatedDropFee(
        address seaDropImpl,
        address allowedNftToken,
        uint16 feeBps
    ) external virtual override onlyAdministrator {
        // Track the previous drop stage data.
        TokenGatedDropStage memory retrieved = ISeaDrop(seaDropImpl)
            .getTokenGatedDrop(address(this), allowedNftToken);

        // Only the administrator (OpenSea) should be able to set feeBps.
        retrieved.feeBps = feeBps;
        retrieved.restrictFeeRecipients = true;

        // Update the token gated drop stage.
        ISeaDrop(seaDropImpl).updateTokenGatedDrop(allowedNftToken, retrieved);
    }

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param dropURI     The new drop URI.
     */
    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        // Update the drop URI.
        ISeaDrop(seaDropImpl).updateDropURI(dropURI);
    }

    /**
     * @notice Update the creator payout address for this nft contract on SeaDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param seaDropImpl   The allowed SeaDrop contract.
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(
        address seaDropImpl,
        address payoutAddress
    ) external onlyOwner {
        // Update the creator payout address.
        ISeaDrop(seaDropImpl).updateCreatorPayoutAddress(payoutAddress);
    }

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on SeaDrop.
     *         Only the administrator can set the allowed fee recipient.
     *
     * @param seaDropImpl  The allowed SeaDrop contract.
     * @param feeRecipient The new fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address seaDropImpl,
        address feeRecipient,
        bool allowed
    ) external onlyAdministrator {
        // Update the allowed fee recipient.
        ISeaDrop(seaDropImpl).updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    /**
     * @notice Update the server-side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can update the signers.
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param signer      The signer to update.
     * @param allowed     Whether signatures are allowed from this signer.
     */
    function updateSigner(
        address seaDropImpl,
        address signer,
        bool allowed
    ) external virtual override onlyOwnerOrAdministrator {
        // Update the signers.
        ISeaDrop(seaDropImpl).updateSigner(signer, allowed);
    }

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists SeaDrop in enforcing maxSupply,
     *         maxMintsPerWallet, and maxTokenSupplyForStage checks.
     *
     * @param minter The minter address.
     */
    function getMintStats(address minter)
        external
        view
        returns (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply
        )
    {
        minterNumMinted = _numberMinted(minter);
        currentTotalSupply = totalSupply();
        maxSupply = _maxSupply;
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721A)
        returns (bool)
    {
        return
            interfaceId == this.supportsInterface.selector || // ERC165
            interfaceId == type(IERC721).interfaceId || // IERC721
            interfaceId == type(IERC721ContractMetadata).interfaceId || // IERC721ContractMetadata
            interfaceId == type(IERC721SeaDrop).interfaceId; // IERC721SeaDrop
    }
}
