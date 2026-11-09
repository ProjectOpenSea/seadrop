// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

/**
 * @title  ISeaDropMinter
 * @notice Structs, events, errors and entry points of the v3 minter.
 */
interface ISeaDropMinter {
    /**
     * @notice One mint stage of a `(token, id)`. A stage is active from
     *         `startTime` through `endTime`, both inclusive, so an unset
     *         stage is never active. A stage is signed when it names a
     *         signer, a signer set or both, and public otherwise.
     *
     * @param price        The price per token, in `currency` units.
     * @param currency     address(0) for ETH, otherwise an ERC-20.
     * @param startTime    The first second the stage is active.
     * @param endTime      The last second the stage is active.
     * @param feeBps       The fee recipient's share of the total, in basis
     *                     points.
     * @param feeRecipient Who receives the fee.
     * @param maxPerWallet The most an eligible wallet can mint in this
     *                     stage. 0 means no limit.
     * @param signerSetId  A signer set the minter's admin manages. 0 means
     *                     none.
     * @param signer       The stage's own signer, an EOA or an ERC-1271
     *                     contract. address(0) means none.
     */
    struct Stage {
        uint96 price;
        address currency;
        uint40 startTime;
        uint40 endTime;
        uint16 feeBps;
        address feeRecipient;
        uint32 maxPerWallet;
        uint64 signerSetId;
        address signer;
    }

    /**
     * @notice A share of a token's mint proceeds after the stage fee.
     */
    struct PayoutRecipient {
        address recipient;
        uint16 bps;
    }

    /**
     * @notice The admin's terms for a currency. Stages can only price in
     *         allowed currencies, and when `minFeeBps` is set, a stage's
     *         fee must go to `feeRecipient` at `minFeeBps` or more.
     *
     *         `setStage` checks all three. Each mint checks `allowed` and
     *         `minFeeBps` again, so disabling a currency or raising its
     *         minimum applies to stages already set. A new `feeRecipient`
     *         applies only to stages set afterwards.
     */
    struct CurrencyConfig {
        bool allowed;
        uint16 minFeeBps;
        address feeRecipient;
    }

    /**
     * @notice What to mint, for whom, and what the payer agrees to pay.
     *
     * @param token         The token contract.
     * @param id            The token id. Use 0 for ERC-721 tokens.
     * @param stageIndex    The stage to mint in.
     * @param wallet        The eligible wallet. Signatures and wallet
     *                      limits are checked against it.
     * @param recipient     Who receives the tokens. Anything other than
     *                      `wallet` needs the wallet's consent.
     * @param quantity      The number of tokens.
     * @param currency      The currency the payer pays in. Must match the
     *                      stage.
     * @param maxTotalPrice The most the payer pays for the whole mint.
     */
    struct MintParams {
        address token;
        uint256 id;
        uint256 stageIndex;
        address wallet;
        address recipient;
        uint256 quantity;
        address currency;
        uint256 maxTotalPrice;
    }

    /**
     * @notice A signer's authorization for `wallet` to mint in a signed
     *         stage, with optional per-wallet overrides. The token, id,
     *         stage and wallet come from the mint's MintParams. Leave it
     *         empty for public stages.
     *
     * @param signer      Who signed: the stage's signer or a member of its
     *                    signer set.
     * @param sender      An address the signer linked to `wallet`, such as
     *                    the same user's embedded wallet. When set, only it
     *                    can use the authorization, and it can pay for the
     *                    wallet without being a trusted payer, an allowed
     *                    payer or a delegate. Tokens still go to the wallet
     *                    unless the usual recipient rules allow otherwise.
     *                    address(0) means any caller the usual rules allow.
     * @param currency    The stage currency the signer priced this in. It
     *                    must still match the stage's, so a price override
     *                    can't carry over to a new currency.
     * @param maxQuantity The wallet's limit in this stage. 0 keeps the
     *                    stage's `maxPerWallet`.
     * @param hasPrice    Whether `price` replaces the stage's price.
     * @param price       The wallet's price per token when `hasPrice`.
     * @param expiry      The last second the authorization is valid.
     * @param signature   The signer's EIP-712 signature, or its ERC-1271
     *                    signature if it's a contract.
     */
    struct Authorization {
        address signer;
        address sender;
        address currency;
        uint256 maxQuantity;
        bool hasPrice;
        uint256 price;
        uint256 expiry;
        bytes signature;
    }

    /**
     * @notice An eligible wallet's signed request to mint. Anyone can
     *         submit it and pay. `params.wallet` signs it.
     */
    struct MintIntent {
        MintParams params;
        uint256 nonce;
        uint256 expiry;
    }

    /// @notice A stage was set. `version` is the event schema version.
    event StageUpdated(
        uint256 version,
        address indexed token,
        uint256 indexed id,
        uint256 indexed stageIndex,
        Stage stage
    );

    /// @notice A token's payout recipients were set.
    event PayoutRecipientsUpdated(
        uint256 version,
        address indexed token,
        PayoutRecipient[] recipients
    );

    /// @notice A token's owner allowed or disallowed a payer.
    event AllowedPayerUpdated(
        uint256 version,
        address indexed token,
        address indexed payer,
        bool allowed
    );

    /// @notice The admin set a currency's terms.
    event CurrencyUpdated(
        uint256 version,
        address indexed currency,
        CurrencyConfig config
    );

    /// @notice The admin added a signer to a signer set or removed one.
    event SignerSetUpdated(
        uint256 version,
        uint64 indexed signerSetId,
        address indexed signer,
        bool allowed
    );

    /// @notice The admin trusted or untrusted a payer for every token.
    event TrustedPayerUpdated(
        uint256 version,
        address indexed payer,
        bool trusted
    );

    /**
     * @notice Tokens were minted. Owner mints use stage index
     *         OWNER_MINT_STAGE, the owner as payer and wallet, and zero
     *         price and fee.
     */
    event SeaDropMint(
        address indexed token,
        uint256 indexed id,
        uint256 stageIndex,
        address payer,
        address indexed wallet,
        address recipient,
        uint256 quantity,
        uint256 unitPrice,
        address currency,
        address feeRecipient,
        uint256 feeBps
    );

    /// @notice A payment push failed, so `account` can withdraw it later.
    event PaymentCredited(
        address indexed account,
        address indexed currency,
        uint256 amount
    );

    /// @notice `account` withdrew its credited balance to `to`.
    event Withdrawal(
        address indexed account,
        address indexed currency,
        address to,
        uint256 amount
    );

    /// @notice `wallet` cancelled an unused intent nonce.
    event IntentCancelled(address indexed wallet, uint256 nonce);

    error OnlyTokenOwner(address token, address caller);
    error FeeBpsTooHigh(uint256 feeBps);
    error FeeRecipientIsZeroAddress();
    error StageEndsBeforeStart(uint256 startTime, uint256 endTime);
    error CurrencyNotAllowed(address currency);
    error FeeBelowMinimum(uint256 feeBps, uint256 minFeeBps);
    error FeeRecipientNotRequired(address feeRecipient, address required);
    error SignerSetIdIsZero();
    error NoPayoutRecipients();
    error TooManyPayoutRecipients(uint256 count);
    error PayoutRecipientIsZeroAddress();
    error PayoutBpsIsZero();
    error PayoutBpsTotalNot10000(uint256 total);
    error StageNotActive(
        uint256 currentTime,
        uint256 startTime,
        uint256 endTime
    );
    error QuantityIsZero();
    error PayerNotAllowed(address payer);
    error RecipientNotApproved(address wallet, address recipient);
    error MintQuantityExceedsWalletLimit(uint256 total, uint256 limit);
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);
    error CurrencyMismatch(address expected, address given);
    error TotalPriceExceedsMax(uint256 totalPrice, uint256 maxTotalPrice);
    error IncorrectPayment(uint256 received, uint256 expected);
    error ERC20AmountNotReceived(uint256 received, uint256 expected);
    error UnsupportedToken(address token);
    error AuthorizationExpired(uint256 expiry);
    error SignerNotAllowed(address signer);
    error SenderMismatch(address sender, address caller);
    error SenderNeedsSignedStage();
    error AuthorizationCurrencyMismatch(
        address stageCurrency,
        address authorizedCurrency
    );
    error InvalidSignature();
    error IntentExpired(uint256 expiry);
    error IntentNonceUsed(address wallet, uint256 nonce);
    error NothingToWithdraw();
    error WithdrawalFailed();
    error Reentrancy();

    /// @notice Set a stage. Only the token's owner can call this.
    function setStage(
        address token,
        uint256 id,
        uint256 stageIndex,
        Stage calldata stage
    ) external;

    /// @notice Set a token's payout recipients. Their bps must sum to
    ///         10,000. Only the token's owner can call this.
    function setPayoutRecipients(
        address token,
        PayoutRecipient[] calldata recipients
    ) external;

    /// @notice Allow or disallow a payer for one token. Only the token's
    ///         owner can call this.
    function setAllowedPayer(address token, address payer, bool allowed)
        external;

    /// @notice Set a currency's terms. Only the admin can call this.
    function setCurrency(address currency, CurrencyConfig calldata config)
        external;

    /// @notice Add a signer to a signer set or remove one. Only the admin
    ///         can call this.
    function setSignerSetMember(
        uint64 signerSetId,
        address signer,
        bool allowed
    ) external;

    /// @notice Trust or untrust a payer for every token. Only the admin
    ///         can call this.
    function setTrustedPayer(address payer, bool trusted) external;

    /// @notice Mint, paid by the caller.
    function mint(
        MintParams calldata params,
        Authorization calldata authorization
    ) external payable;

    /// @notice Mint a wallet's signed intent, paid by the caller.
    function mintWithIntent(
        MintIntent calldata intent,
        bytes calldata intentSignature,
        Authorization calldata authorization
    ) external payable;

    /// @notice Mint without payment, stages or wallet limits. Only the
    ///         token's owner can call this.
    function ownerMint(
        address token,
        uint256 id,
        address recipient,
        uint256 quantity
    ) external;

    /// @notice Mark one of the caller's intent nonces used.
    function cancelIntent(uint256 nonce) external;

    /// @notice Withdraw the caller's credited balance of `currency` to
    ///         `to`.
    function withdraw(address currency, address to) external;

    function getStage(address token, uint256 id, uint256 stageIndex)
        external
        view
        returns (Stage memory);

    function getPayoutRecipients(address token)
        external
        view
        returns (PayoutRecipient[] memory);

    function getCurrency(address currency)
        external
        view
        returns (CurrencyConfig memory);
}
