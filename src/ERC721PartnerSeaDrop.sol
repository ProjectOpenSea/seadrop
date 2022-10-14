// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "./ERC721SeaDrop.sol";

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage,
    SignedMintValidationParams
} from "./lib/SeaDropStructs.sol";

import { TwoStepAdministered } from "utility-contracts/TwoStepAdministered.sol";

/**
 * @title  ERC721PartnerSeaDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerSeaDrop is a token contract that contains methods
 *         to properly interact with SeaDrop, with additional administrative
 *         functionality tailored for business requirements around partnered
 *         mints with off-chain agreements in place between two parties.
 *
 *         The "Owner" should control mint specifics such as price and start.
 *         The "Administrator" should control fee parameters.
 *
 *         Otherwise, for ease of administration, either Owner or Administrator
 *         should be able to configure mint parameters. They have the ability
 *         to override each other's actions in many circumstances, which is
 *         why the establishment of off-chain trust is important.
 *
 *         Note: An Administrator is not required to interface with SeaDrop.
 */
contract ERC721PartnerSeaDrop is ERC721SeaDrop, TwoStepAdministered {
    /// @notice To prevent Owner from overriding fees, Administrator must
    ///         first initialize with fee.
    error AdministratorMustInitializeWithFee();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    )
        ERC721SeaDrop(name, symbol, allowedSeaDrop)
        TwoStepAdministered(administrator)
    {}

    /**
     * @notice Mint tokens, restricted to the SeaDrop contract.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 quantity)
        external
        payable
        virtual
        override
        onlyAllowedSeaDrop(msg.sender)
    {
        // Extra safety check to ensure the max supply is not exceeded.
        if (_totalMinted() + quantity > maxSupply()) {
            revert MintQuantityExceedsMaxSupply(
                _totalMinted() + quantity,
                maxSupply()
            );
        }

        // Mint the quantity of tokens to the minter.
        _mint(minter, quantity);
    }

    /**
     * @notice Update the allowed SeaDrop contracts.
     *         Only the owner or administrator can use this function.
     *
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     */
    function updateAllowedSeaDrop(address[] calldata allowedSeaDrop)
        external
        override
        onlyOwnerOrAdministrator
    {
        _updateAllowedSeaDrop(allowedSeaDrop);
    }

    /**
     * @notice Update the public drop data for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator can only update `feeBps`.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    )
        external
        virtual
        override
        onlyOwnerOrAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
    {
        // Track the previous public drop data.
        PublicDrop memory retrieved = ISeaDrop(seaDropImpl).getPublicDrop(
            address(this)
        );

        // Track the newly supplied drop data.
        PublicDrop memory supplied = publicDrop;

        // Only the administrator (OpenSea) can set feeBps.
        if (msg.sender != administrator) {
            // Administrator must first set fee.
            if (retrieved.maxTotalMintableByWallet == 0) {
                revert AdministratorMustInitializeWithFee();
            }
            supplied.feeBps = retrieved.feeBps;
            supplied.restrictFeeRecipients = true;
        } else {
            // Administrator can only initialize
            // (maxTotalMintableByWallet > 0) and set
            // feeBps/restrictFeeRecipients.
            uint16 maxTotalMintableByWallet = retrieved
                .maxTotalMintableByWallet;
            retrieved.maxTotalMintableByWallet = maxTotalMintableByWallet > 0
                ? maxTotalMintableByWallet
                : 1;
            retrieved.feeBps = supplied.feeBps;
            retrieved.restrictFeeRecipients = true;
            supplied = retrieved;
        }

        // Update the public drop data on SeaDrop.
        ISeaDrop(seaDropImpl).updatePublicDrop(supplied);
    }

    /**
     * @notice Update the allow list data for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl   The allowed SeaDrop contract.
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
     * @notice Update the token gated drop stage data for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator must first set `feeBps`.
     *
     *         Note: If two INonFungibleSeaDropToken tokens are doing
     *         simultaneous token gated drop promotions for each other,
     *         they can be minted by the same actor until
     *         `maxTokenSupplyForStage` is reached. Please ensure the
     *         `allowedNftToken` is not running an active drop during the
     *         `dropStage` time period.
     *
     * @param seaDropImpl     The allowed SeaDrop contract.
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
        // Track the previous drop stage data.
        TokenGatedDropStage memory retrieved = ISeaDrop(seaDropImpl)
            .getTokenGatedDrop(address(this), allowedNftToken);

        // Track the newly supplied drop data.
        TokenGatedDropStage memory supplied = dropStage;

        // Only the administrator (OpenSea) can set feeBps on Partner
        // contracts.
        if (msg.sender != administrator) {
            // Administrator must first set fee.
            if (retrieved.maxTotalMintableByWallet == 0) {
                revert AdministratorMustInitializeWithFee();
            }
            supplied.feeBps = retrieved.feeBps;
            supplied.restrictFeeRecipients = true;
        } else {
            // Administrator can only initialize
            // (maxTotalMintableByWallet > 0) and set
            // feeBps/restrictFeeRecipients.
            uint16 maxTotalMintableByWallet = retrieved
                .maxTotalMintableByWallet;
            retrieved.maxTotalMintableByWallet = maxTotalMintableByWallet > 0
                ? maxTotalMintableByWallet
                : 1;
            retrieved.feeBps = supplied.feeBps;
            retrieved.restrictFeeRecipients = true;
            supplied = retrieved;
        }

        // Update the token gated drop stage.
        ISeaDrop(seaDropImpl).updateTokenGatedDrop(allowedNftToken, supplied);
    }

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param dropURI     The new drop URI.
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
    ) external override onlyAdministrator onlyAllowedSeaDrop(seaDropImpl) {
        // Update the allowed fee recipient.
        ISeaDrop(seaDropImpl).updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    /**
     * @notice Update the server-side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl                The allowed SeaDrop contract.
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters to
     *                                   enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address seaDropImpl,
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    )
        external
        virtual
        override
        onlyOwnerOrAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
    {
        // Track the previous signed mint validation params.
        SignedMintValidationParams memory retrieved = ISeaDrop(seaDropImpl)
            .getSignedMintValidationParams(address(this), signer);

        // Track the newly supplied params.
        SignedMintValidationParams memory supplied = signedMintValidationParams;

        // Only the administrator (OpenSea) can set feeBps on Partner
        // contracts.
        if (msg.sender != administrator) {
            // Administrator must first set fee.
            if (retrieved.maxMaxTotalMintableByWallet == 0) {
                revert AdministratorMustInitializeWithFee();
            }
            supplied.minFeeBps = retrieved.minFeeBps;
            supplied.maxFeeBps = retrieved.maxFeeBps;
        } else {
            // Administrator can only initialize
            // (maxTotalMintableByWallet > 0) and set
            // feeBps/restrictFeeRecipients.
            uint24 maxMaxTotalMintableByWallet = retrieved
                .maxMaxTotalMintableByWallet;
            retrieved
                .maxMaxTotalMintableByWallet = maxMaxTotalMintableByWallet > 0
                ? maxMaxTotalMintableByWallet
                : 1;
            retrieved.minFeeBps = supplied.minFeeBps;
            retrieved.maxFeeBps = supplied.maxFeeBps;
            supplied = retrieved;
        }

        // Update the signed mint validation params.
        ISeaDrop(seaDropImpl).updateSignedMintValidationParams(
            signer,
            supplied
        );
    }

    /**
     * @notice Update the allowed payers for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param payer       The payer to update.
     * @param allowed     Whether the payer is allowed.
     */
    function updatePayer(
        address seaDropImpl,
        address payer,
        bool allowed
    )
        external
        virtual
        override
        onlyOwnerOrAdministrator
        onlyAllowedSeaDrop(seaDropImpl)
    {
        // Update the payer.
        ISeaDrop(seaDropImpl).updatePayer(payer, allowed);
    }
}
