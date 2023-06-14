// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    IRaribleDropTokenContractMetadataUpgradeable
} from "./IRaribleDropTokenContractMetadataUpgradeable.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage,
    SignedMintValidationParams
} from "../lib/RaribleDropStructsUpgradeable.sol";

interface INonFungibleRaribleDropTokenUpgradeable is
    IRaribleDropTokenContractMetadataUpgradeable
{
    /**
     * @dev Revert with an error if a contract is not an allowed
     *      RaribleDrop address.
     */
    error OnlyAllowedRaribleDrop();

    /**
     * @dev Emit an event when allowed RaribleDrop contracts are updated.
     */
    event AllowedRaribleDropUpdated(address[] allowedRaribleDrop);

    /**
     * @notice Update the allowed RaribleDrop contracts.
     *         Only the owner or administrator can use this function.
     *
     * @param allowedRaribleDrop The allowed RaribleDrop addresses.
     */
    function updateAllowedRaribleDrop(address[] calldata allowedRaribleDrop) external;

    /**
     * @notice Mint tokens, restricted to the RaribleDrop contract.
     *
     * @dev    NOTE: If a token registers itself with multiple RaribleDrop
     *         contracts, the implementation of this function should guard
     *         against reentrancy. If the implementing token uses
     *         _safeMint(), or a feeRecipient with a malicious receive() hook
     *         is specified, the token or fee recipients may be able to execute
     *         another mint in the same transaction via a separate RaribleDrop
     *         contract.
     *         This is dangerous if an implementing token does not correctly
     *         update the minterNumMinted and currentTotalSupply values before
     *         transferring minted tokens, as RaribleDrop references these values
     *         to enforce token limits on a per-wallet and per-stage basis.
     *
     * @param minter   The address to mint to.
     * @param quantity The number of tokens to mint.
     */
    function mintRaribleDrop(address minter, uint256 quantity) external;

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists RaribleDrop in enforcing maxSupply,
     *         maxTotalMintableByWallet, and maxTokenSupplyForStage checks.
     *
     * @dev    NOTE: Implementing contracts should always update these numbers
     *         before transferring any tokens with _safeMint() to mitigate
     *         consequences of malicious onERC721Received() hooks.
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
        );

    /**
     * @notice Update the public drop data for this nft contract on
     *         RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator can only update `feeBps`.
     *
     * @param seaDropImpl The allowed RaribleDrop contract.
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external;

    /**
     * @notice Update the allow list data for this nft contract on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl   The allowed RaribleDrop contract.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    ) external;

    /**
     * @notice Update the token gated drop stage data for this nft contract
     *         on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator, when present, must first set `feeBps`.
     *
     *         Note: If two INonFungibleRaribleDropToken tokens are doing
     *         simultaneous token gated drop promotions for each other,
     *         they can be minted by the same actor until
     *         `maxTokenSupplyForStage` is reached. Please ensure the
     *         `allowedNftToken` is not running an active drop during the
     *         `dropStage` time period.
     *
     *
     * @param seaDropImpl     The allowed RaribleDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address seaDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external;

    /**
     * @notice Update the drop URI for this nft contract on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl The allowed RaribleDrop contract.
     * @param dropURI     The new drop URI.
     */
    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external;

    /**
     * @notice Update the creator payout address for this nft contract on RaribleDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param seaDropImpl   The allowed RaribleDrop contract.
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(
        address seaDropImpl,
        address payoutAddress
    ) external;

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on RaribleDrop.
     *         Only the administrator can set the allowed fee recipient.
     *
     * @param seaDropImpl  The allowed RaribleDrop contract.
     * @param feeRecipient The new fee recipient.
     */
    function updateAllowedFeeRecipient(
        address seaDropImpl,
        address feeRecipient,
        bool allowed
    ) external;

    /**
     * @notice Update the server-side signers for this nft contract
     *         on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl                The allowed RaribleDrop contract.
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters
     *                                   to enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address seaDropImpl,
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    ) external;

    /**
     * @notice Update the allowed payers for this nft contract on RaribleDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param seaDropImpl The allowed RaribleDrop contract.
     * @param payer       The payer to update.
     * @param allowed     Whether the payer is allowed.
     */
    function updatePayer(
        address seaDropImpl,
        address payer,
        bool allowed
    ) external;
}
