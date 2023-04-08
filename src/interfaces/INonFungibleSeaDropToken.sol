// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ContractOffererInterface
} from "seaport/interfaces/ContractOffererInterface.sol";

import {
    ISeaDropTokenContractMetadata
} from "./ISeaDropTokenContractMetadata.sol";

import {
    SeaDropStructsErrorsAndEvents
} from "../lib/SeaDropStructsErrorsAndEvents.sol";

// TODO rename to IERC721SeaDrop?
interface INonFungibleSeaDropToken is
    ISeaDropTokenContractMetadata,
    SeaDropStructsErrorsAndEvents,
    ContractOffererInterface
{
    /**
     * @dev Revert with an error if the caller is not an allowed Seaport
     *      or conduit address.
     */
    error InvalidCallerOnlyAllowedSeaportOrConduit(address caller);

    /**
     * @dev Revert with an error if the order does not have the ERC1155 magic
     *      consideration item to signify a consecutive mint.
     */
    error MustSpecifyERC1155ConsiderationItemForSeaDropConsecutiveMint();

    /**
     * @dev Revert with an error if the extra data version is not supported.
     */
    error UnsupportedExtraDataVersion(uint8 version);

    /**
     * @dev Revert with an error if the extra data encoding is not supported.
     */
    error InvalidExtraDataEncoding(uint8 version);

    /**
     * @dev Revert with an error if the provided substandard is not supported.
     */
    error InvalidSubstandard(uint8 substandard);

    /**
     * @dev Emit an event when allowed Seaport contracts are updated.
     */
    event AllowedSeaportUpdated(address[] allowedSeaport);

    /**
     * @notice Update the allowed Seaport contracts.
     *         Only the owner can use this function.
     *
     * @param allowedSeaport The allowed Seaport addresses.
     */
    function updateAllowedSeaport(address[] calldata allowedSeaport) external;

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists SeaDrop in enforcing maxSupply,
     *         maxTotalMintableByWallet, and maxTokenSupplyForStage checks.
     *
     * @dev    NOTE: Implementing contracts should always update these numbers
     *         before transferring any tokens with _safeMint() to mitigate
     *         consequences of malicious onERC721Received() hooks.
     *
     * @param minter The minter address.
     */
    function getMintStats(
        address minter
    )
        external
        view
        returns (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply
        );

    /**
     * @notice Update the public drop data.
     *         Only the owner can use this function.
     *
     * @param publicDrop  The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop) external;

    /**
     * @notice Update the allow list data for this nft contract on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData) external;

    /**
     * @notice Update the token gated drop stage data for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can use this function.
     *
     *         The administrator, when present, must first set `feeBps`.
     *
     *         Note: If two INonFungibleSeaDropToken tokens are doing
     *         simultaneous token gated drop promotions for each other,
     *         they can be minted by the same actor until
     *         `maxTokenSupplyForStage` is reached. Please ensure the
     *         `allowedNftToken` is not running an active drop during the
     *         `dropStage` time period.
     *
     *
     * @param allowedNftToken The allowed nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external;

    /**
     * @notice Update the Drop URI.
     *         Only the owner can use this function.
     *
     * @param dropURI     The new drop URI.
     */
    function updateDropURI(string calldata dropURI) external;

    /**
     * @notice Update the creator payouts.
     *         Only the owner can use this function.
     *
     * @param creatorPayouts The creator payouts.
     */
    function updateCreatorPayouts(
        CreatorPayout[] calldata creatorPayouts
    ) external;

    /**
     * @notice Update the allowed fee recipient.
     *         Only the owner can use this function.
     *
     * @param feeRecipient The new fee recipient.
     */
    function updateAllowedFeeRecipient(
        address feeRecipient,
        bool allowed
    ) external;

    /**
     * @notice Update the server-side signers.
     *         Only the owner can use this function.
     *
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters
     *                                   to enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address signer,
        SignedMintValidationParams memory signedMintValidationParams
    ) external;

    /**
     * @notice Update the allowed payers for this nft contract on SeaDrop.
     *         Only the owner can use this function.
     *
     * @param payer       The payer to update.
     * @param allowed     Whether the payer is allowed.
     */
    function updatePayer(address payer, bool allowed) external;

    // TODO add multiconfigure to ensure contract interface supports self serve
}
