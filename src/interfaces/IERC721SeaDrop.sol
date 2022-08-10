// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    IERC721ContractMetadata
} from "../interfaces/IERC721ContractMetadata.sol";

import {
    AllowListData,
    PublicDrop,
    TokenGatedDropStage
} from "../lib/SeaDropStructs.sol";

import {
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

interface IERC721SeaDrop is IERC721ContractMetadata, IERC165 {
    /**
     * @dev Revert with an error if a contract other than an allowed
     *      SeaDrop address calls an update function.
     */
    error OnlySeaDrop();

    /**
     * @dev Emit an event when allowed SeaDrop contracts are updated.
     */
    event AllowedSeaDropUpdated(address[] allowedSeaDrop);

    /**
     * @notice Update the allowed SeaDrop contracts.
     *
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     */
    function updateAllowedSeaDrop(address[] calldata allowedSeaDrop) external;

    /**
     * @notice Mint tokens, restricted to the SeaDrop contract.
     *
     * @param minter The address to mint to.
     * @param amount The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 amount) external payable;

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
        );

    /**
     * @notice Update public drop data for this nft contract on SeaDrop.
     *         Use `updatePublicDropFee` to update the fee recipient or feeBps.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external;

    /**
     * @notice Update allow list data for this nft contract on SeaDrop.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    ) external;

    /**
     * @notice Update token gated drop stage data for this nft contract
     *         on SeaDrop.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param allowedNftToken The allowed nft token.
     * @param dropStage The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address seaDropImpl,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external;

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param dropURI The new drop URI.
     */
    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external;

    /**
     * @notice Update the creator payout address for this nft contract on SeaDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(
        address seaDropImpl,
        address payoutAddress
    ) external;

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on SeaDrop.
     *         Only the administrator can set the allowed fee recipient.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param feeRecipient The new fee recipient.
     */
    function updateAllowedFeeRecipient(
        address seaDropImpl,
        address feeRecipient,
        bool allowed
    ) external;

    /**
     * @notice Update the server side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can update the signers.
     *
     * @param seaDropImpl The allowed SeaDrop contract.
     * @param newSigners The new signers.
     */
    function updateSigners(address seaDropImpl, address[] calldata newSigners)
        external;

    /**
     * @notice Update the sale token for the nft contract.
     *         A zero address means the sale token is denominated
     *         in the chain's native currency (e.g. ETH, MATIC, etc.)
     *         Only the owner or administrator can update the sale token.
     *
     * @param saleToken The ERC20 token address.
     */
    function updateSaleToken(address seaDropImpl, address saleToken) external;
}
