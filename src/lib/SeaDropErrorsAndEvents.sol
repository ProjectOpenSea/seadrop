// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CreatorPayout,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "./ERC721SeaDropStructs.sol";

interface SeaDropErrorsAndEvents {
    /**
     * @notice The SeaDrop token types, emitted as part of
     *         `event SeaDropTokenDeployed`.
     */
    enum SEADROP_TOKEN_TYPE {
        ERC721_STANDARD,
        ERC721_CLONE,
        ERC721_LAZY,
        ERC721_UPGRADEABLE,
        ERC1155_STANDARD,
        ERC1155_CLONE,
        ERC1155_UPGRADEABLE
    }

    /**
     * @notice An event to signify that a SeaDrop token contract was deployed.
     */
    event SeaDropTokenDeployed(SEADROP_TOKEN_TYPE tokenType);

    /**
     * @notice Revert with an error if the function selector is not supported.
     */
    error UnsupportedFunctionSelector(bytes4 selector);

    /**
     * @notice Revert with an error if the number of token gated
     *         allowedNftTokens doesn't match the length of supplied
     *         drop stages.
     */
    error TokenGatedMismatch();

    /**
     *  @notice Revert with an error if the number of signers doesn't match
     *          the length of supplied signedMintValidationParams.
     */
    error SignersMismatch();

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
     *      Note: The `maxTokenSupplyForStage` for public mint is
     *      always `type(uint).max`.
     */
    error MintQuantityExceedsMaxTokenSupplyForStage(
        uint256 total,
        uint256 maxTokenSupplyForStage
    );

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
    error FeeRecipientNotAllowed(address got);

    /**
     * @dev Revert if the creator payout address is the zero address.
     */
    error CreatorPayoutAddressCannotBeZeroAddress();

    /**
     * @dev Revert if the creator payouts are not set.
     */
    error CreatorPayoutsNotSet();

    /**
     * @dev Revert if the creator payout basis points are zero.
     */
    error CreatorPayoutBasisPointsCannotBeZero();

    /**
     * @dev Revert if the total basis points for the creator payouts
     *      don't equal exactly 10_000.
     */
    error InvalidCreatorPayoutTotalBasisPoints(
        uint256 totalReceivedBasisPoints
    );

    /**
     * @dev Revert if the creator payout basis points don't add up to 10_000.
     */
    error InvalidCreatorPayoutBasisPoints(uint256 totalReceivedBasisPoints);

    /**
     * @dev Revert with an error if the allow list proof is invalid.
     */
    error InvalidProof();

    /**
     * @dev Revert if a supplied signer address is the zero address.
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
     * @dev Revert with an error if a payer is not included in
     *      the enumeration when removing.
     */
    error PayerNotPresent();

    /**
     * @dev Revert with an error if a payer is already included in mapping
     *      when adding.
     *      Note: only applies when adding a single payer, as duplicates in
     *      enumeration can be removed with updatePayer.
     */
    error DuplicatePayer();

    /**
     * @dev Revert with an error if the payer is not allowed. The minter must
     *      pay for their own mint.
     */
    error PayerNotAllowed(address got);

    /**
     * @dev Revert if a supplied payer address is the zero address.
     */
    error PayerCannotBeZeroAddress();

    /**
     * @dev Revert with an error if the token gated token ids and amounts
     *      to mint do not match.
     */
    error TokenGatedTokenIdsAndAmountsLengthMismatch();

    /**
     * @dev Revert with an error if the sender of a token gated supplied
     *      drop stage redeem is not the owner of the token.
     */
    error TokenGatedNotTokenOwner(
        address allowedNftToken,
        uint256 allowedNftTokenId
    );

    /**
     * @dev Revert with an error if the token id has reached its quantity limit
     *      to redeem a token gated drop stage.
     */
    error TokenGatedTokenIdMintExceedsQuantityRemaining(
        address allowedNftToken,
        uint256 allowedNftTokenId,
        uint256 quantityLimit,
        uint256 quantityRedeemed,
        uint256 additionalQuantityToMint
    );

    /**
     * @dev Revert with an error if an empty TokenGatedDropStage is provided
     *      for an already-empty TokenGatedDropStage.
     */
    error TokenGatedDropStageNotPresent();

    /**
     * @dev Revert with an error if an allowedNftToken is set to
     *      the zero address.
     */
    error TokenGatedDropAllowedNftTokenCannotBeZeroAddress();

    /**
     * @dev Revert with an error if an allowedNftToken is set to
     *      the drop token itself.
     */
    error TokenGatedDropAllowedNftTokenCannotBeDropToken();

    /**
     * @dev Revert with an error if the signer payment token is not the same.
     */
    error InvalidSignedPaymentToken(address got, address want);

    /**
     * @dev Revert with an error if supplied signed mint price is less than
     *      the minimum specified.
     */
    error InvalidSignedMintPrice(
        address paymentToken,
        uint256 got,
        uint256 minimum
    );

    /**
     * @dev Revert with an error if supplied signed maxTotalMintableByWallet
     *      is greater than the maximum specified.
     */
    error InvalidSignedMaxTotalMintableByWallet(uint256 got, uint256 maximum);

    /**
     * @dev Revert with an error if supplied signed start time is less than
     *      the minimum specified.
     */
    error InvalidSignedStartTime(uint256 got, uint256 minimum);

    /**
     * @dev Revert with an error if supplied signed end time is greater than
     *      the maximum specified.
     */
    error InvalidSignedEndTime(uint256 got, uint256 maximum);

    /**
     * @dev Revert with an error if supplied signed maxTokenSupplyForStage
     *      is greater than the maximum specified.
     */
    error InvalidSignedMaxTokenSupplyForStage(uint256 got, uint256 maximum);

    /**
     * @dev Revert with an error if supplied signed feeBps is greater than
     *      the maximum specified, or less than the minimum.
     */
    error InvalidSignedFeeBps(uint256 got, uint256 minimumOrMaximum);

    /**
     * @dev Revert with an error if signed mint did not specify to restrict
     *      fee recipients.
     */
    error SignedMintsMustRestrictFeeRecipients();

    /**
     * @dev Revert with an error if a signature for a signed mint has already
     *      been used.
     */
    error SignatureAlreadyUsed();

    /**
     * @dev Revert with an error if the contract has no balance to withdraw.
     */
    error NoBalanceToWithdraw();

    /**
     * @dev Revert with an error if the caller is not an allowed Seaport.
     */
    error InvalidCallerOnlyAllowedSeaport(address caller);

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
     * @dev An event with details of a SeaDrop mint, for analytical purposes.
     *
     * @param payer          The address who payed for the tx.
     * @param dropStageIndex The drop stage index. Items minted through
     *                       public mint have dropStageIndex of 0
     */
    event SeaDropMint(address payer, uint256 dropStageIndex);

    /**
     * @dev An event with updated allow list data for an nft contract.
     *
     * @param previousMerkleRoot The previous allow list merkle root.
     * @param newMerkleRoot      The new allow list merkle root.
     * @param publicKeyURI       If the allow list is encrypted, the public key
     *                           URIs that can decrypt the list.
     *                           Empty if unencrypted.
     * @param allowListURI       The URI for the allow list.
     */
    event AllowListUpdated(
        bytes32 indexed previousMerkleRoot,
        bytes32 indexed newMerkleRoot,
        string[] publicKeyURI,
        string allowListURI
    );

    /**
     * @dev An event with updated drop URI for an nft contract.
     */
    event DropURIUpdated(string newDropURI);

    /**
     * @dev An event with the updated creator payout address for an nft
     *      contract.
     */
    event CreatorPayoutsUpdated(CreatorPayout[] creatorPayouts);

    /**
     * @dev An event with the updated allowed fee recipient for an nft
     *      contract.
     */
    event AllowedFeeRecipientUpdated(
        address indexed feeRecipient,
        bool indexed allowed
    );

    /**
     * @dev An event with the updated payer for an nft contract.
     */
    event PayerUpdated(address indexed payer, bool indexed allowed);
}
