// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface SeaDropStructsErrorsAndEvents {
    /**
     * @notice A struct defining a creator payout address and basis points.
     *
     * @param payoutAddress The payout address.
     * @param basisPoints   The basis points to pay out to the creator.
     *                      The total creator payouts must equal 10_000 bps.
     */
    struct CreatorPayout {
        address payoutAddress;
        uint16 basisPoints;
    }

    /**
     * @notice A struct defining public drop data.
     *         Designed to fit efficiently in two storage slots.
     *
     * @param startPrice               The start price per token. (Up to 1.2m
     *                                 of native token, e.g. ETH, MATIC)
     * @param endPrice                 The end price per token. If this differs
     *                                 from startPrice, the current price will
     *                                 be calculated based on the current time.
     * @param paymentToken             The payment token address. Null for
     *                                 native token.
     * @param startTime                The start time, ensure this is not zero.
     * @param endTime                  The end time, ensure this is not zero.
     * @param maxTotalMintableByWallet Maximum total number of mints a user is
     *                                 allowed. (The limit for this field is
     *                                 2^16 - 1)
     * @param feeBps                   Fee out of 10_000 basis points to be
     *                                 collected.
     * @param restrictFeeRecipients    If false, allow any fee recipient;
     *                                 if true, check fee recipient is allowed.
     */
    struct PublicDrop {
        uint80 startPrice; // 80/512 bits
        uint80 endPrice; // 160/512 bits
        address paymentToken; // 320/512 bits
        uint48 startTime; // 368/512 bits
        uint48 endTime; // 416/512 bits
        uint16 maxTotalMintableByWallet; // 432/512 bits
        uint16 feeBps; // 448/512 bits
        bool restrictFeeRecipients; // 456/512 bits
    }

    /**
     * @notice A struct defining token gated drop stage data.
     *         Designed to fit efficiently in two storage slots.
     *
     * @param startPrice               The start price per token. (Up to 1.2m
     *                                 of native token, e.g. ETH, MATIC)
     * @param endPrice                 The end price per token. If this differs
     *                                 from startPrice, the current price will
     *                                 be calculated based on the current time.
     * @param paymentToken             The payment token for the mint. Null for
     *                                 native token.
     * @param maxTotalMintableByWallet Maximum total number of mints a user is
     *                                 allowed. (The limit for this field is
     *                                 2^16 - 1)
     * @param startTime                The start time, ensure this is not zero.
     * @param endTime                  The end time, ensure this is not zero.
     * @param dropStageIndex           The drop stage index to emit with the event
     *                                 for analytical purposes. This should be
     *                                 non-zero since the public mint emits
     *                                 with index zero.
     * @param maxTokenSupplyForStage   The limit of token supply this stage can
     *                                 mint within. (The limit for this field is
     *                                 2^16 - 1)
     * @param feeBps                   Fee out of 10_000 basis points to be
     *                                 collected.
     * @param restrictFeeRecipients    If false, allow any fee recipient;
     *                                 if true, check fee recipient is allowed.
     */
    struct TokenGatedDropStage {
        uint80 startPrice; // 80/512 bits
        uint80 endPrice; // 160/512 bits
        address paymentToken; // 320/512 bits
        uint16 maxMintablePerRedeemedToken; // 346/512 bits
        uint24 maxTotalMintableByWallet; // 370/512 bits
        uint48 startTime; // 418/512 bits
        uint48 endTime; // 466/512 bits
        uint8 dropStageIndex; // non-zero. 474/512 bits
        uint32 maxTokenSupplyForStage; // 506/512 bits
        uint16 feeBps; // 522/512 bits
        bool restrictFeeRecipients; // 530/512 bits
    }

    /**
     * @notice A struct defining mint params for an allow list.
     *         An allow list leaf will be composed of `msg.sender` and
     *         the following params.
     *
     *         Note: Since feeBps is encoded in the leaf, backend should ensure
     *         that feeBps is acceptable before generating a proof.
     *
     * @param startPrice               The start price per token. (Up to 1.2m
     *                                 of native token, e.g. ETH, MATIC)
     * @param endPrice                 The end price per token. If this differs
     *                                 from startPrice, the current price will
     *                                 be calculated based on the current time.
     * @param paymentToken             The payment token for the mint. Null for
     *                                 native token.
     * @param maxTotalMintableByWallet Maximum total number of mints a user is
     *                                 allowed.
     * @param startTime                The start time, ensure this is not zero.
     * @param endTime                  The end time, ensure this is not zero.
     * @param dropStageIndex           The drop stage index to emit with the event
     *                                 for analytical purposes. This should be
     *                                 non-zero since the public mint emits with
     *                                 index zero.
     * @param maxTokenSupplyForStage   The limit of token supply this stage can
     *                                 mint within.
     * @param feeBps                   Fee out of 10_000 basis points to be
     *                                 collected.
     * @param restrictFeeRecipients    If false, allow any fee recipient;
     *                                 if true, check fee recipient is allowed.
     */
    struct MintParams {
        uint256 startPrice;
        uint256 endPrice;
        address paymentToken;
        uint256 maxTotalMintableByWallet;
        uint256 startTime;
        uint256 endTime;
        uint256 dropStageIndex; // non-zero
        uint256 maxTokenSupplyForStage;
        uint256 feeBps;
        bool restrictFeeRecipients;
    }

    /**
     * @notice A struct defining token gated mint params.
     *
     * @param allowedNftToken    The allowed nft token contract address.
     * @param allowedNftTokenIds The token ids to redeem.
     * @param amounts            The token amounts to redeem, per allowedNftTokenId.
     */
    struct TokenGatedMintParams {
        address allowedNftToken;
        uint256[] allowedNftTokenIds;
        uint256[] amounts;
    }

    /**
     * @notice A struct defining allow list data (for minting an allow list).
     *
     * @param merkleRoot    The merkle root for the allow list.
     * @param publicKeyURIs If the allowListURI is encrypted, a list of URIs
     *                      pointing to the public keys. Empty if unencrypted.
     * @param allowListURI  The URI for the allow list.
     */
    struct AllowListData {
        bytes32 merkleRoot;
        string[] publicKeyURIs;
        string allowListURI;
    }

    /**
     * @notice A struct defining the minimum mint price and payment token
     *         for SignedMintValidationParams.
     *
     * @param paymentToken The required payment token. Null for native token.
     * @param minMintPrice The minimum mint price allowed.
     */
    struct SignedMintValidationMinMintPrice {
        address paymentToken;
        uint80 minMintPrice;
    }

    /**
     * @notice A struct defining minimum and maximum parameters to validate for
     *         signed mints, to minimize negative effects of a compromised signer.
     *
     * @param minMintPrices               The minimum mint prices allowed
     *                                    by payment token.
     * @param maxMaxTotalMintableByWallet The maximum total number of mints allowed
     *                                    by a wallet.
     * @param minStartTime                The minimum start time allowed.
     * @param maxEndTime                  The maximum end time allowed.
     * @param maxMaxTokenSupplyForStage   The maximum token supply allowed.
     * @param minFeeBps                   The minimum fee allowed.
     * @param maxFeeBps                   The maximum fee allowed.
     */
    struct SignedMintValidationParams {
        SignedMintValidationMinMintPrice[] minMintPrices;
        uint24 maxMaxTotalMintableByWallet; // 104/256 bits
        uint40 minStartTime; // 144/256 bits
        uint40 maxEndTime; // 184/256 bits
        uint40 maxMaxTokenSupplyForStage; // 224/256 bits
        uint16 minFeeBps; // 240/256 bits
        uint16 maxFeeBps; // 256/256 bits
    }

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
     * @dev Revert with an error if the mint quantity is zero.
     */
    error MintQuantityCannotBeZero();

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
     * @dev Revert with an error if a min mint price is not set in the signed
     *      mint validation params.
     */
    error SignedMintValidationParamsMinMintPriceNotSet();

    /**
     * @dev Revert with an error if the min mint price for a given
     *      paymentToken is not set.
     */
    error SignedMintValidationParamsMinMintPriceNotSetForToken(
        address paymentToken
    );

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
     * @dev An event with details of a SeaDrop mint, for analytical purposes.
     *
     * @param minter         The mint recipient.
     * @param feeRecipient   The fee recipient.
     * @param payer          The address who payed for the tx.
     * @param quantityMinted The number of tokens minted.
     * @param unitMintPrice  The amount paid for each token.
     * @param paymentToken   The payment token for the mint.
     * @param feeBps         The fee out of 10_000 basis points collected.
     * @param dropStageIndex The drop stage index. Items minted
     *                       through mintPublic() have
     *                       dropStageIndex of 0.
     */
    event SeaDropMint(
        address indexed minter,
        address indexed feeRecipient,
        address payer,
        uint256 quantityMinted,
        uint256 unitMintPrice,
        address paymentToken,
        uint256 feeBps,
        uint256 dropStageIndex
    );

    /**
     * @dev An event with updated public drop data for an nft contract.
     */
    event PublicDropUpdated(PublicDrop publicDrop);

    /**
     * @dev An event with updated token gated drop stage data
     *      for an nft contract.
     */
    event TokenGatedDropStageUpdated(
        address indexed allowedNftToken,
        TokenGatedDropStage dropStage
    );

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
     * @dev An event with the updated validation parameters for server-side
     *      signers.
     */
    event SignedMintValidationParamsUpdated(
        address indexed signer,
        SignedMintValidationParams signedMintValidationParams
    );

    /**
     * @dev An event with the updated payer for an nft contract.
     */
    event PayerUpdated(address indexed payer, bool indexed allowed);
}
