// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    PublicDrop,
    MintParams,
    AllowListData,
    TokenGatedDropStage,
    TokenGatedMintParams
} from "../lib/SeaDropStructs.sol";
import { SeaDropErrorsAndEvents } from "../lib/SeaDropErrorsAndEvents.sol";

interface ISeaDrop is SeaDropErrorsAndEvents {
    /**
     * @notice Mint a public drop.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param numToMint The number of tokens to mint.
     */
    function mintPublic(
        address nftContract,
        address feeRecipient,
        uint256 numToMint
    ) external payable;

    /**
     * @notice Mint from an allow list.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param numToMint The number of tokens to mint.
     * @param mintParams The mint parameters.
     * @param proof The proof for the leaf of the allow list.
     */
    function mintAllowList(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes32[] calldata proof
    ) external payable;

    /**
     * @notice Mint with a server side signature.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param numToMint The number of tokens to mint.
     * @param mintParams The mint parameters.
     * @param signature The server side signature, must be an allowed signer.
     */
    function mintSigned(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes calldata signature
    ) external payable;

    /**
     * @notice Mint as an allowed token holder.
     *         This will mark the token id as reedemed and will revert if the
     *         same token id is attempted to be redeemed twice.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param tokenGatedMintParams The token gated mint params.
     */
    function mintAllowedTokenHolder(
        address nftContract,
        address feeRecipient,
        TokenGatedMintParams[] calldata tokenGatedMintParams
    ) external payable;

    /**
     * @notice Returns the public drop data for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getPublicDrop(address nftContract)
        external
        view
        returns (PublicDrop memory);

    /**
     * @notice Returns the creator payout address for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getCreatorPayoutAddress(address nftContract)
        external
        view
        returns (address);

    /**
     * @notice Returns the allow list merkle root for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getMerkleRoot(address nftContract) external view returns (bytes32);

    /**
     * @notice Returns if the specified fee recipient is allowed
     *         for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getAllowedFeeRecipient(address nftContract, address feeRecipient)
        external
        view
        returns (bool);

    /**
     * @notice Returns the server side signers for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getSigners(address nftContract)
        external
        view
        returns (address[] memory);

    /**
     * The following methods assume msg.sender is an nft contract;
     * The ERC165 of the sender is ingesting events
     *.

    /**
     * @notice Updates the public drop data for the nft contract
     *         and emits an event.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop) external;

    /**
     * @notice Updates the allow list merkle root for the nft contract
     *         and emits an event.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData) external;

    /**
     * @notice Updates the drop URI and emits an event.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(string calldata dropURI) external;

    /**
     * @notice Updates the creator payout address and emits an event.
     *
     * @param payoutAddress The creator payout address.
     */
    function updateCreatorPayoutAddress(address payoutAddress) external;

    /**
     * @notice Updates the allowed fee recipient and emits an event.
     *
     * @param feeRecipient The fee recipient.
     * @param allowed If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(address feeRecipient, bool allowed)
        external;

    /**
     * @notice Updates the allowed server side signers and emits an event.
     *
     * @param newSigners The new list of signers.
     */
    function updateSigners(address[] calldata newSigners) external;

    /**
     * @notice Updates the token gated drop stage for the nft contract
     *         and emits an event.
     *
     * @param nftContract The nft contract.
     * @param allowedNftToken The token gated nft token.
     * @param dropStage The token gated drop stage data.
     */
    function updateTokenGatedDropStage(
        address nftContract,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external;

    /**
     * @notice Returns the allowed token gated drop tokens for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getTokenGatedAllowedTokens(address nftContract)
        external
        view
        returns (address[] memory);

    /**
     * @notice Returns the token gated drop data for the nft contract
     *         and token gated nft.
     *
     * @param nftContract The nft contract.
     * @param allowedNftToken The token gated nft token.
     */
    function getTokenGatedDrop(address nftContract, address allowedNftToken)
        external
        view
        returns (TokenGatedDropStage memory);
}
