// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { PublicDrop, TokenGatedDropStage } from "./SeaDropStructs.sol";

interface SeaDropErrorsAndEvents {
    /**
     * @dev Revert with an error if the drop stage is not active.
     */
    error NotActive(
        uint256 currentTimestamp,
        uint256 startTimestamp,
        uint256 endTimestamp
    );

    /**
     * @dev Revert with an error if the mint quantity exceeds the max allowed
     *      to be minted per wallet.
     */
    error MintQuantityExceedsMaxMintedPerWallet(uint256 total, uint256 allowed);

    /**
     * @dev Revert with an error if the mint quantity exceeds the max token
     *      supply.
     */
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);

    /**
     * @dev Revert with an error if the mint quantity exceeds the max token
     *      supply for the stage.
     */
    error MintQuantityExceedsMaxTokenSupplyForStage(uint256 total, uint256 maxTokenSupplyForStage);
    
    /**
     * @dev Revert if the fee recipient is the zero address.
     */
    error FeeRecipientCannotBeZeroAddress();

    /**
     * @dev Revert if the fee recipient is not already included.
     */
    error FeeRecipientNotPresent();

    /**
     * @dev Revert if the fee basis points is greater than 10_000.
     */
     error InvalidFeeBps(uint256 feeBps);

    /**
     * @dev Revert if the fee recipient is already included.
     */
    error DuplicateFeeRecipient();

    /**
     * @dev Revert if the fee recipient is restricted and not allowed.
     */
    error FeeRecipientNotAllowed();

    /**
     * @dev Revert if the creator payout address is the zero address.
     */
    error CreatorPayoutAddressCannotBeZeroAddress();

    /**
     * @dev Revert with an error if the received payment is incorrect.
     */
    error IncorrectPayment(uint256 got, uint256 want);

    /**
     * @dev Revert with an error if the allow list proof is invalid.
     */
    error InvalidProof();

    /**
     * @dev Revert if a supplied signer address is the zero address
     */
    error SignerCannotBeZeroAddress();
    /**
     * @dev Revert with an error if signer's signature is invalid.
     */
    error InvalidSignature(address recoveredSigner);

    /**
     * @dev Revert with an error if a signer is not included in
     *      the enumeration when removing.
     */
    error SignerNotPresent();

    /**
     * @dev Revert with an error if a signer is already included in mapping
     *      when adding.
     *      Note: only applies when adding a single signer, as duplicates in
     *      enumeration can be removed with removeSigner.
     */
    error DuplicateSigner();

    /**
     * @dev Revert with an error if the sender does not
     *      match the IERC721SeaDrop interface.
     */
    error OnlyIERC721SeaDrop(address sender);

    /**
     * @dev Revert with an error if the sender of a token gated supplied
     *      drop stage redeem is not the owner of the token.
     */
    error TokenGatedNotTokenOwner(address nftContract, address allowedNftContract, uint256 tokenId);

    /**
     * @dev Revert with an error if the token id has already been used to
     *      redeem a token gated drop stage.
     */
    error TokenGatedTokenIdAlreadyRedeemed(address nftContract, address allowedNftContract, uint256 tokenId);

    /**
     * @dev Revert with an error if an empty TokenGatedDropStage is provided
     *      for an already-empty TokenGatedDropStage.
     */
     error TokenGatedDropStageNotPresent();

    /**
     * @dev Revert with an error if an allowedNftToken is set for the
     *      drop token itself.
     */
     error TokenGatedDropAllowedNftTokenCannotBeDropToken();

    /**
     * @dev An event with details of a SeaDrop mint, for analytical purposes.
     * 
     * @param nftContract    The nft contract.
     * @param minter         The mint recipient.
     * @param feeRecipient   The fee recipient.
     * @param payer          The address who payed for the tx.
     * @param quantityMinted The number of tokens minted.
     * @param unitMintPrice  The amount paid for each token.
     * @param feeBps         The fee out of 10_000 basis points collected.
     * @param dropStageIndex The drop stage index. Items minted
     *                       through mintPublic() have
     *                       dropStageIndex of 0.
     */
    event SeaDropMint(
        address indexed nftContract,
        address indexed minter,
        address indexed feeRecipient,
        address payer,
        uint256 quantityMinted,
        uint256 unitMintPrice,
        uint256 feeBps,
        uint256 dropStageIndex
    );

    /**
     * @dev An event with updated public drop data for an nft contract.
     */
    event PublicDropUpdated(address indexed nftContract, PublicDrop publicDrop);

    /**
     * @dev An event with updated token gated drop stage data
     *      for an nft contract.
     */
    event TokenGatedDropStageUpdated(
        address indexed nftContract,
        address indexed allowedNftToken,
        TokenGatedDropStage dropStage
    );

/**
 * @dev An event with updated allow list data for an nft contract.
 * 
 * @param nftContract        The nft contract.
 * @param previousMerkleRoot The previous allow list merkle root.
 * @param newMerkleRoot      The new allow list merkle root.
 * @param publicKeyURI       If the allow list is encrypted, the public key
 *                           URIs that can decrypt the list.
 *                           Empty if unencrypted.
 * @param allowListURI       The URI for the allow list.
 */
event AllowListUpdated(
    address indexed nftContract,
    bytes32 indexed previousMerkleRoot,
    bytes32 indexed newMerkleRoot,
    string[] publicKeyURI,
    string allowListURI
);

    /**
     * @dev An event with updated drop URI for an nft contract.
     */
    event DropURIUpdated(address indexed nftContract, string newDropURI);

    /**
     * @dev An event with the updated creator payout address for an nft contract.
     */
    event CreatorPayoutAddressUpdated(
        address indexed nftContract,
        address indexed newPayoutAddress
    );

    /**
     * @dev An event with the updated allowed fee recipient for an nft contract.
     */
    event AllowedFeeRecipientUpdated(
        address indexed nftContract,
        address indexed feeRecipient,
        bool indexed allowed
    );

    /**
     * @dev An event with the updated server-side signers for an nft contract.
     */
    event SignerUpdated(
        address indexed nftContract,
        address indexed signer,
        bool indexed allowed
    );
}
