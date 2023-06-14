// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721RaribleDropUpgradeable } from "./ERC721RaribleDropUpgradeable.sol";

import { IRaribleDropUpgradeable } from "./interfaces/IRaribleDropUpgradeable.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage,
    SignedMintValidationParams
} from "./lib/RaribleDropStructsUpgradeable.sol";

import {
    TwoStepAdministeredUpgradeable
} from "../lib-upgradeable/utility-contracts/src/TwoStepAdministeredUpgradeable.sol";
import {
    TwoStepAdministeredStorage
} from "../lib-upgradeable/utility-contracts/src/TwoStepAdministeredStorage.sol";

/**
 * @title  ERC721PartnerRaribleDropUpgradeable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerRaribleDrop is a token contract that contains methods
 *         to properly interact with RaribleDrop, with additional administrative
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
 *         Note: An Administrator is not required to interface with RaribleDrop.
 */
contract ERC721PartnerRaribleDropUpgradeable is
    ERC721RaribleDropUpgradeable,
    TwoStepAdministeredUpgradeable
{
    using TwoStepAdministeredStorage for TwoStepAdministeredStorage.Layout;

    /// @notice To prevent Owner from overriding fees, Administrator must
    ///         first initialize with fee.
    error AdministratorMustInitializeWithFee();

    /**
     * @dev Reverts if the sender is not the owner or administrator
     *      or the contract itself.
     *      This function is inlined instead of being a modifier
     *      to save contract space from being inlined N times.
     */
    function _onlyOwnerOrAdministratorOrSelf() internal view {
        if (
            _cast(msg.sender == owner()) |
                _cast(
                    msg.sender ==
                        TwoStepAdministeredStorage.layout().administrator
                ) |
                _cast(msg.sender == address(this)) ==
            0
        ) {
            revert OnlyOwnerOrAdministrator();
        }
    }

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed RaribleDrop addresses.
     */
    function __ERC721PartnerRaribleDrop_init(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedRaribleDrop
    ) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
        __ReentrancyGuard_init_unchained();
        __ERC721RaribleDrop_init_unchained(name, symbol, allowedRaribleDrop);
        __TwoStepAdministered_init_unchained(administrator);
        __ERC721PartnerRaribleDrop_init_unchained(
            name,
            symbol,
            administrator,
            allowedRaribleDrop
        );
    }

    function __ERC721PartnerRaribleDrop_init_unchained(
        string memory,
        string memory,
        address,
        address[] memory
    ) internal onlyInitializing {}

    /**
     * @notice Mint tokens, restricted to the RaribleDrop contract.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintRaribleDrop(address minter, uint256 quantity)
        external
        virtual
        override
    {
        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(msg.sender);

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
     * @notice Update the allowed RaribleDrop contracts.
     *         Only the owner or administrator can use this function.
     *
     * @param allowedRaribleDrop The allowed RaribleDrop addresses.
     */
    function updateAllowedRaribleDrop(
        address[] calldata allowedRaribleDrop
    ) external override {
        // Ensure the sender is only the owner or administrator or
        // contract itself.
        _onlyOwnerOrAdministratorOrSelf();

        _updateAllowedRaribleDrop(allowedRaribleDrop);
    }

    /**
     * @notice Update the public drop data for this nft contract on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator can only update `feeBps`.
     *
     * @param raribleDropImpl The allowed RaribleDrop contract.
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(
        address raribleDropImpl,
        PublicDrop calldata publicDrop
    ) external virtual override {
        // Ensure the sender is only the owner or administrator or
        // contract itself.
        _onlyOwnerOrAdministratorOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Track the previous public drop data.
        PublicDrop memory retrieved = IRaribleDropUpgradeable(raribleDropImpl)
            .getPublicDrop(address(this));

        // Track the newly supplied drop data.
        PublicDrop memory supplied = publicDrop;

        // Only the administrator (Rarible) can set feeBps.
        if (msg.sender != TwoStepAdministeredStorage.layout().administrator) {
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

        // Update the public drop data on RaribleDrop.
        IRaribleDropUpgradeable(raribleDropImpl).updatePublicDrop(supplied);
    }

    /**
     * @notice Update the allow list data for this nft contract on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param raribleDropImpl   The allowed RaribleDrop contract.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address raribleDropImpl,
        AllowListData calldata allowListData
    ) external virtual override {
        // Ensure the sender is only the owner or administrator or
        // contract itself.
        _onlyOwnerOrAdministratorOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the allow list on RaribleDrop.
        IRaribleDropUpgradeable(raribleDropImpl).updateAllowList(allowListData);
    }

    /**
     * @notice Update the token gated drop stage data for this nft contract
     *         on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator must first set `feeBps`.
     *
     *         Note: If two INonFungibleRaribleDropToken tokens are doing
     *         simultaneous token gated drop promotions for each other,
     *         they can be minted by the same actor until
     *         `maxTokenSupplyForStage` is reached. Please ensure the
     *         `allowedNftToken` is not running an active drop during the
     *         `dropStage` time period.
     *
     * @param raribleDropImpl     The allowed RaribleDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address raribleDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external virtual override {
        // Ensure the sender is only the owner or administrator or
        // contract itself.
        _onlyOwnerOrAdministratorOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Track the previous drop stage data.
        TokenGatedDropStage memory retrieved = IRaribleDropUpgradeable(raribleDropImpl)
            .getTokenGatedDrop(address(this), allowedNftToken);

        // Track the newly supplied drop data.
        TokenGatedDropStage memory supplied = dropStage;

        // Only the administrator (Rarible) can set feeBps on Partner
        // contracts.
        if (msg.sender != TwoStepAdministeredStorage.layout().administrator) {
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
        IRaribleDropUpgradeable(raribleDropImpl).updateTokenGatedDrop(
            allowedNftToken,
            supplied
        );
    }

    /**
     * @notice Update the drop URI for this nft contract on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param raribleDropImpl The allowed RaribleDrop contract.
     * @param dropURI     The new drop URI.
     */
    function updateDropURI(
        address raribleDropImpl,
        string calldata dropURI
    ) external virtual override {
        // Ensure the sender is only the owner or administrator or
        // contract itself.
        _onlyOwnerOrAdministratorOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the drop URI.
        IRaribleDropUpgradeable(raribleDropImpl).updateDropURI(dropURI);
    }

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on RaribleDrop.
     *         Only the administrator can set the allowed fee recipient.
     *
     * @param raribleDropImpl  The allowed RaribleDrop contract.
     * @param feeRecipient The new fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address raribleDropImpl,
        address feeRecipient,
        bool allowed
    ) external override onlyAdministrator {
        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the allowed fee recipient.
        IRaribleDropUpgradeable(raribleDropImpl).updateAllowedFeeRecipient(
            feeRecipient,
            allowed
        );
    }

    /**
     * @notice Update the server-side signers for this nft contract
     *         on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param raribleDropImpl                The allowed RaribleDrop contract.
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters to
     *                                   enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address raribleDropImpl,
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    ) external virtual override {
        // Ensure the sender is only the owner or administrator or
        // contract itself.
        _onlyOwnerOrAdministratorOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Track the previous signed mint validation params.
        SignedMintValidationParams memory retrieved = IRaribleDropUpgradeable(
            raribleDropImpl
        ).getSignedMintValidationParams(address(this), signer);

        // Track the newly supplied params.
        SignedMintValidationParams memory supplied = signedMintValidationParams;

        // Only the administrator (Rarible) can set feeBps on Partner
        // contracts.
        if (msg.sender != TwoStepAdministeredStorage.layout().administrator) {
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
        IRaribleDropUpgradeable(raribleDropImpl).updateSignedMintValidationParams(
            signer,
            supplied
        );
    }

    /**
     * @notice Update the allowed payers for this nft contract on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param raribleDropImpl The allowed RaribleDrop contract.
     * @param payer       The payer to update.
     * @param allowed     Whether the payer is allowed.
     */
    function updatePayer(
        address raribleDropImpl,
        address payer,
        bool allowed
    ) external virtual override {
        // Ensure the sender is only the owner or administrator or
        // contract itself.
        _onlyOwnerOrAdministratorOrSelf();

        // Ensure the RaribleDrop is allowed.
        _onlyAllowedRaribleDrop(raribleDropImpl);

        // Update the payer.
        IRaribleDropUpgradeable(raribleDropImpl).updatePayer(payer, allowed);
    }
}
