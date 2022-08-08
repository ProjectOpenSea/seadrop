// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    IERC721ContractMetadata
} from "../interfaces/IERC721ContractMetadata.sol";
import {
    PublicDrop,
    AllowListData,
    TokenGatedDropStage
} from "../lib/SeaDropStructs.sol";

import {
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

interface IERC721SeaDrop is IERC721ContractMetadata, IERC165 {
    /**
     * @dev Revert with an error if a contract other than
     *      SeaDrop calls an update function.
     */
    error OnlySeaDrop();

    /**
     * @notice Mint tokens, restricted to the SeaDrop contract.
     *
     * @param minter The address to mint to.
     * @param amount The number of tokens to mint.
     */
    function mintSeaDrop(address minter, uint256 amount) external payable;

    /**
     * @notice Returns the number of tokens minted by the address.
     *
     * @param minter The minter address.
     */
    function numberMinted(address minter) external view returns (uint256);

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
        );

    /**
     * @notice Update public drop data for this nft contract on SeaDrop.
     *         Use `updatePublicDropFee` to update the fee recipient or feeBps.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop) external;

    /**
     * @notice Update allow list data for this nft contract on SeaDrop.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData) external;

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
    ) external;

    /**
     * @notice Update the drop URI for this nft contract on SeaDrop.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(string calldata dropURI) external;

    /**
     * @notice Update the creator payout address for this nft contract on SeaDrop.
     *         Only the owner can set the creator payout address.
     *
     * @param payoutAddress The new payout address.
     */
    function updateCreatorPayoutAddress(address payoutAddress) external;

    /**
     * @notice Update the allowed fee recipient for this nft contract
     *         on SeaDrop.
     *         Only the administrator can set the allowed fee recipient.
     *
     * @param feeRecipient The new fee recipient.
     */
    function updateAllowedFeeRecipient(address feeRecipient, bool allowed)
        external;

    /**
     * @notice Update the server side signers for this nft contract
     *         on SeaDrop.
     *         Only the owner or administrator can update the signers.
     *
     * @param newSigners The new signers.
     */
    function updateSigners(address[] calldata newSigners) external;
}
