// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { ERC721SeaDrop } from "./ERC721SeaDrop.sol";

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage
} from "./lib/SeaDropStructs.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

import {
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { TwoStepAdministered } from "utility-contracts/TwoStepAdministered.sol";

/**
 * @title  ERC721PartnerSeaDrop
 * @author jameswenzel, ryanio, stephankmin
 * @notice ERC721PartnerSeaDrop is a token contract that contains methods
 *         to properly interact with SeaDrop, with additional administrative
 *         functionality tailored for business requirements around partnered
 *         mints with off-chain agreements in place between two parties.
 *
 *         The "Owner" should control mint specifics such as price and start
 *         The "Administrator" should control fee parameters
 *
 *         Otherwise, for ease of administration, either Owner or Administrator
 *         should be able to configure mint parameters. They have the ability
 *         to override each other's actions in many circumstances, which is
 *         why the establishment of off-chain trust is important.
 *
 *         Note: An Administrator is not required to interface with SeaDrop.
 */
contract ERC721PartnerSeaDrop is ERC721SeaDrop, TwoStepAdministered {
    /// @notice To prevent Owner from overriding PublicDrop or
    //          TokenGatedDropStage fees, administrator must first
    //          initialize with fee.
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
     * @notice Update the allowed SeaDrop contracts.
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
     * @notice Update public drop data for this nft contract on SeaDrop.
     *         Note: Only the administrator can update `feeBps`.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external virtual override onlyOwnerOrAdministrator {
        // Track the previous public drop data.
        PublicDrop memory retrieved = ISeaDrop(seaDropImpl).getPublicDrop(
            address(this)
        );

        // Track the newly supplied drop data.
        PublicDrop memory supplied = publicDrop;

        // Only the administrator (OpenSea) should be able to set feeBps.
        if (msg.sender != administrator) {
            // Administrator must first set fee.
            if (retrieved.maxTotalMintableByWallet == 0) {
                revert AdministratorMustInitializeWithFee();
            }
            supplied.feeBps = retrieved.feeBps;
            supplied.restrictFeeRecipients = true;
        } else {
            // administrator should only be able to initialize (maxtotalmintablebywallet > 0)
            // and/or set feeBps/restrictFeeRecipients
            uint40 maxTotalMintableByWallet = retrieved
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
     * @notice Update allow list data for this nft contract on SeaDrop.
     *
     *         Note: Only authorized users can call this.
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
     *         on SeaDrop. The administrator must first set `feeBps`.
     *
     *         Note: If two INonFungibleSeaDropToken tokens are doing simultaneous
     *         token gated drop promotions for each other, they can be
     *         minted by the same actor until `maxTokenSupplyForStage`
     *         is reached. Please ensure the `allowedNftToken` is not
     *         running an active drop during the `dropStage` time period.
     *
     * @param seaDropImpl     The allowed SeaDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address seaDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external virtual override onlyOwnerOrAdministrator {
        // Track the previous drop stage data.
        TokenGatedDropStage memory retrieved = ISeaDrop(seaDropImpl)
            .getTokenGatedDrop(address(this), allowedNftToken);

        // Track the newly supplied drop data.
        TokenGatedDropStage memory supplied = dropStage;

        // Only the administrator (OpenSea) should be able to set feeBps on Partner contracts
        if (msg.sender != administrator) {
            // Administrator must first set fee.
            if (retrieved.maxTotalMintableByWallet == 0) {
                revert AdministratorMustInitializeWithFee();
            }
            supplied.feeBps = retrieved.feeBps;
            supplied.restrictFeeRecipients = true;
        } else {
            // administrator should only be able to initialize (maxtotalmintablebywallet > 0)
            // and/or set feeBps/restrictFeeRecipients

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
    ) external override onlyAdministrator {
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
}
