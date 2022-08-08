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
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { SeaDrop } from "./SeaDrop.sol";

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import { SeaDropErrorsAndEvents } from "./lib/SeaDropErrorsAndEvents.sol";
import {
    PublicDrop,
    AllowListData,
    TokenGatedDropStage
} from "./lib/SeaDropStructs.sol";

contract ERC721SeaDrop is
    ERC721ContractMetadata,
    IERC721SeaDrop,
    SeaDropErrorsAndEvents
{
    // Track the SeaDrop address.
    ISeaDrop internal immutable _SEADROP;

    /**
     * @notice Modifier to restrict access exclusively to the SeaDrop contract.
     */
    modifier onlySeaDrop() {
        if (msg.sender != address(_SEADROP)) {
            revert OnlySeaDrop();
        }
        _;
    }

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and seadrop address.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address seaDrop
    ) ERC721ContractMetadata(name, symbol, administrator) {
        // Set the SeaDrop address.
        _SEADROP = ISeaDrop(seaDrop);
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
        _mintERC2309(minter, amount);
    }

    /**
     * @notice Update public drop data for this nft contract on SeaDrop.
     *         Use `updatePublicDropFee` to update the fee recipient or feeBps.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        virtual
        override
        onlyOwner
    {
        // Track the previous public drop data.
        PublicDrop memory retrieved = _SEADROP.getPublicDrop(address(this));

        // Track the newly supplied drop data.
        PublicDrop memory supplied = publicDrop;

        // Only the administrator (OpenSea) should be able to set feeBps.
        supplied.feeBps = retrieved.feeBps;
        retrieved.restrictFeeRecipients = true;

        // Update the public drop data on SeaDrop.
        _SEADROP.updatePublicDrop(supplied);
    }

    /**
     * @notice Update public drop fee for this nft contract on SeaDrop.
     *
     * @param feeBps The public drop fee basis points.
     */
    function updatePublicDropFee(uint16 feeBps)
        external
        virtual
        onlyAdministrator
    {
        // Track the previous public drop data.
        PublicDrop memory retrieved = _SEADROP.getPublicDrop(address(this));

        // Only the administrator (OpenSea) should be able to set feeBps.
        retrieved.feeBps = feeBps;
        retrieved.restrictFeeRecipients = true;

        // Update the public drop data on SeaDrop.
        _SEADROP.updatePublicDrop(retrieved);
    }

    /**
     * @notice Update allow list data for this nft contract on SeaDrop.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        // Update the allow list on SeaDrop.
        _SEADROP.updateAllowList(allowListData);
    }

    /**
     * @notice Update token gated drop stage data for this nft contract
     *         on SeaDrop.
     *
     * @param allowedNftToken The allowed nft token.
     * @param dropStage The token gated drop stage data.
     */
    function updateTokenGatedDropStage(
        address nftContract,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external virtual override onlyOwnerOrAdministrator {
        // Update the token gated drop stage.
        _SEADROP.updateTokenGatedDropStage(
            nftContract,
            allowedNftToken,
            dropStage
        );
    }

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(string calldata dropURI)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        // Update the drop URI.
        _SEADROP.updateDropURI(dropURI);
    }

    /**
     * @notice Update the creator payout address for this nft contract on SeaDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(address payoutAddress)
        external
        onlyOwner
    {
        // Update the creator payout address.
        _SEADROP.updateCreatorPayoutAddress(payoutAddress);
    }

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on SeaDrop.
     *         Only the administrator can set the allowed fee recipient.
     *
     * @param feeRecipient The new fee recipient.
     * @param allowed If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(address feeRecipient, bool allowed)
        external
        onlyAdministrator
    {
        // Update the allowed fee recipient.
        _SEADROP.updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    /**
     * @notice Update the server side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can update the signers.
     *
     * @param newSigners The new signers.
     */
    function updateSigners(address[] calldata newSigners)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        // Update the signers.
        _SEADROP.updateSigners(newSigners);
    }

    /**
     * @notice Returns the number of tokens minted by the address.
     *
     * @param minter The minter address.
     */
    function numberMinted(address minter) external view returns (uint256) {
        return _numberMinted(minter);
    }

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists SeaDrop in enforcing maxSupply and
     *         maxMintsPerWallet checks, and in the case of allowlist,
     *         max for stage.
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
     * @notice Returns the total supply of tokens.
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
     * @notice Returns the supported interfaces as per ERC165.
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
            interfaceId == type(IERC721ContractMetadata).interfaceId || // IERC721ContractMetadata
            interfaceId == type(IERC721SeaDrop).interfaceId; // IERC721SeaDrop
    }
}
