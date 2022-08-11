// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    IERC721SeaDrop,
    IERC721ContractMetadata
} from "./interfaces/IERC721SeaDrop.sol";

import {
    ERC721ContractMetadata,
    IERC721ContractMetadata
} from "./ERC721ContractMetadata.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

import { TwoStepAdministered } from "utility-contracts/TwoStepAdministered.sol";

import {
    IERC721
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import {
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { SeaDrop } from "./SeaDrop.sol";

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import { SeaDropErrorsAndEvents } from "./lib/SeaDropErrorsAndEvents.sol";
import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage
} from "./lib/SeaDropStructs.sol";

contract ERC721SeaDrop is
    ERC721ContractMetadata,
    IERC721SeaDrop,
    SeaDropErrorsAndEvents
{
    // Track the allowed SeaDrop addresses.
    mapping(address => bool) private _allowedSeaDrop;

    // Track the enumrated allowed SeaDrop addresses.
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
     * @notice Modifier to restrict access exclusively to
     *         allowed SeaDrop contracts.
     */
    modifier onlyAllowedSeaDrop(address seaDrop) {
        if (_allowedSeaDrop[seaDrop] != true) {
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
     * @param minter The address to mint to.
     * @param amount The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 amount)
        external
        payable
        override
        onlySeaDrop
    {
        // Emit a ConsecutiveTransfer event.
        _mint(minter, amount);
    }

    /**
     * @notice Update public drop data for this nft contract on SeaDrop.
     *         Use `updatePublicDropFee` to update the fee recipient or feeBps.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external virtual override onlyOwner onlyAllowedSeaDrop(seaDropImpl) {
        // Track the previous public drop data.
        PublicDrop memory retrieved = ISeaDrop(seaDropImpl).getPublicDrop(
            address(this)
        );

        // Track the newly supplied drop data.
        PublicDrop memory supplied = publicDrop;

        // Only the administrator (OpenSea) should be able to set feeBps.
        supplied.feeBps = retrieved.feeBps;
        retrieved.restrictFeeRecipients = true;

        // Update the public drop data on SeaDrop.
        ISeaDrop(seaDropImpl).updatePublicDrop(supplied);
    }

    /**
     * @notice Update public drop fee for this nft contract on SeaDrop.
     *
     * @param feeBps The public drop fee basis points.
     */
    function updatePublicDropFee(address seaDropImpl, uint16 feeBps)
        external
        virtual
        onlyAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
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
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    )
        external
        virtual
        override
        onlyOwnerOrAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
    {
        // Update the allow list on SeaDrop.
        ISeaDrop(seaDropImpl).updateAllowList(allowListData);
    }

    /**
     * @notice Update token gated drop stage data for this nft contract
     *         on SeaDrop.
     *
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address seaDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    )
        external
        virtual
        override
        onlyOwnerOrAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
    {
        // Update the token gated drop stage.
        ISeaDrop(seaDropImpl).updateTokenGatedDrop(
            address(this),
            allowedNftToken,
            dropStage
        );
    }

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external
        virtual
        override
        onlyOwnerOrAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
    {
        // Update the drop URI.
        ISeaDrop(seaDropImpl).updateDropURI(dropURI);
    }

    /**
     * @notice Update the creator payout address for this nft contract on SeaDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(
        address seaDropImpl,
        address payoutAddress
    ) external onlyOwner onlyAllowedSeaDrop(seaDropImpl) {
        // Update the creator payout address.
        ISeaDrop(seaDropImpl).updateCreatorPayoutAddress(payoutAddress);
    }

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on SeaDrop.
     *         Only the administrator can set the allowed fee recipient.
     *
     * @param feeRecipient The new fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address seaDropImpl,
        address feeRecipient,
        bool allowed
    ) external onlyAdministrator onlyAllowedSeaDrop(seaDropImpl) {
        // Update the allowed fee recipient.
        ISeaDrop(seaDropImpl).updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    /**
     * @notice Update the server side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can update the signers.
     *
     * @param newSigners The new signers.
     */
    function updateSigners(address seaDropImpl, address[] calldata newSigners)
        external
        virtual
        override
        onlyOwnerOrAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
    {
        // Update the signers.
        ISeaDrop(seaDropImpl).updateSigners(newSigners);
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
     * @notice Returns the total token supply.
     */
    function totalSupply()
        public
        view
        virtual
        override(IERC721ContractMetadata, ERC721ContractMetadata)
        returns (uint256)
    {
        return ERC721A.totalSupply();
    }

    /**
     * @notice Returns if the interface is supported.
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
