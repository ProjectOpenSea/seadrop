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
     * @dev Revert with an error if amount exceeds the max allowed
     *      per transaction.
     */
    error AmountExceedsMaxPerTransaction(uint256 amount, uint256 allowed);

    /**
     * @dev Revert with an error if amount exceeds the max allowed
     *      to be minted per wallet.
     */
    error AmountExceedsMaxMintedPerWallet(uint256 total, uint256 allowed);

    /**
     * @dev Revert with an error if amount exceeds the max token supply.
     */
    error AmountExceedsMaxSupply(uint256 total, uint256 maxSupply);

    /**
     * @dev Revert with an error if amount exceeds the max token supply for the stage.
     */
    error AmountExceedsMaxTokenSupplyForStage(uint256 total, uint256 maxTokenSupplyForStage);

    /**
     * @dev Revert with an error if the allow list is already redeemed.
     *      TODO should you only be able to redeem from an allow list once?
     *           would otherwise be capped by maxTotalMintableByWallet
     */
    error AllowListRedeemed();

    /**
     * @dev Revert with an error if the received payment is incorrect.
     */
    error IncorrectPayment(uint256 got, uint256 want);

    /**
     * @dev Revert with an error if the allow list proof is invalid.
     */
    error InvalidProof();

    /**
     * @dev Revert with an error if signer's signatuer is invalid.
     */
    error InvalidSignature(address recoveredSigner);

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
     * @dev Revert with an error if sender has insufficient
     *      sale token balance.
     */
    error InsufficientSaleTokenBalance(address saleToken, uint256 balance, uint256 totalCost);

    /**
     * @dev Revert with an error if sender has insufficient
     *      sale token allowance.
     */
    error InsufficientSaleTokenAllowance(address saleToken, uint256 allowance, uint256 totalCost);

    /**
     * @dev An event with details of a SeaDrop mint, for analytics purposes.
     */
    event SeaDropMint(
        address indexed nftContract,
        address indexed minter,
        address indexed feeRecipient,
        uint256 numberMinted,
        uint256 unitMintPrice,
        uint256 feeBps,
        uint256 dropStageIndex // non-zero is an allow-list tier
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
     */
    event AllowListUpdated(
        address indexed nftContract,
        bytes32 indexed previousMerkleRoot,
        bytes32 indexed newMerkleRoot,
        string[] publicKeyURI, // empty if unencrypted
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
     * @dev An event with the updated server side signers for an nft contract.
     */
    event SignersUpdated(
        address indexed nftContract,
        address[] oldSigners,
        address[] newSigners
    );

    /**
     * @dev An event with the updated sale token.
     */
    event SaleTokenUpdated(
        address indexed nftContract,
        address saleToken
    );
}
