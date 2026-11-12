// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ISeaDropMinter } from "./interfaces/ISeaDropMinter.sol";

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { IDelegateRegistry } from "./interfaces/IDelegateRegistry.sol";

import {
    INonFungibleSeaDropToken
} from "../interfaces/INonFungibleSeaDropToken.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import { EIP712 } from "openzeppelin-contracts/utils/cryptography/EIP712.sol";

import {
    SignatureChecker
} from "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";

import { IERC20 } from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {
    SafeERC20
} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {
    IERC165
} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

interface IOwnable {
    function owner() external view returns (address);
}

/**
 * @title  SeaDropMinter
 * @notice SeaDrop v3's minter: one contract per chain that holds drop
 *         configuration, mint logic and payments for thin tokens.
 *
 *         A token's owner configures its drop here directly. Each
 *         `(token, id)` has stages, each public or signed. Each mint
 *         separates three roles: the payer (`msg.sender`), the eligible
 *         wallet (whose signatures and wallet limits apply) and the
 *         recipient. Any caller can pay for a wallet. Tokens go to the
 *         wallet unless the caller is the wallet or its delegate.xyz
 *         delegate.
 *
 *         The minter's admin manages what's shared across drops: allowed
 *         currencies and their minimum protocol fee, and signer sets.
 *
 *         The minter mints through ISeaDropTokenV3 when a token supports
 *         it, and otherwise through v1's INonFungibleSeaDropToken, so
 *         existing v1 tokens can add it with `updateAllowedSeaDrop`.
 */
contract SeaDropMinter is ISeaDropMinter, EIP712, TwoStepOwnable {
    using SafeERC20 for IERC20;

    /// @notice The schema version of the config events.
    uint256 public constant CONFIG_EVENT_VERSION = 1;

    /// @notice The stage index SeaDropMint reports for owner mints.
    uint256 public constant OWNER_MINT_STAGE = type(uint256).max;

    /// @notice delegate.xyz's v2 registry, at its canonical address.
    address public constant DELEGATE_REGISTRY =
        0x00000000000000447e69651d841bD8D104Bed493;

    /// @notice The most payout recipients a token can have.
    uint256 public constant MAX_PAYOUT_RECIPIENTS = 10;

    /// @notice The gas an ETH payout push gets. A recipient that needs
    ///         more is credited instead.
    uint256 public constant ETH_PAYOUT_GAS = 100_000;

    /// @notice The gas an ERC-20 payout push gets. A transfer that needs
    ///         more is rolled back and the recipient is credited instead.
    uint256 public constant ERC20_PAYOUT_GAS = 100_000;

    uint256 internal constant _BPS = 10_000;

    /// @dev ERC-165 id of ERC-721.
    bytes4 internal constant _ERC721_INTERFACE_ID = 0x80ac58cd;

    bytes32 public constant MINT_AUTHORIZATION_TYPEHASH = keccak256(
        "MintAuthorization(address token,uint256 id,uint256 stageIndex,"
        "address wallet,address sender,address currency,uint256 maxQuantity,"
        "bool hasPrice,uint256 price,uint256 expiry)"
    );

    bytes32 public constant MINT_PARAMS_TYPEHASH = keccak256(
        "MintParams(address token,uint256 id,uint256 stageIndex,"
        "address wallet,address recipient,uint256 quantity,"
        "address currency,uint256 maxTotalPrice)"
    );

    bytes32 public constant MINT_INTENT_TYPEHASH = keccak256(
        "MintIntent(MintParams params,uint256 nonce,uint256 expiry)"
        "MintParams(address token,uint256 id,uint256 stageIndex,"
        "address wallet,address recipient,uint256 quantity,"
        "address currency,uint256 maxTotalPrice)"
    );

    mapping(
        address token
            => mapping(uint256 id => mapping(uint256 stageIndex => Stage))
    ) internal _stages;

    mapping(address token => PayoutRecipient[]) internal _payoutRecipients;

    mapping(address currency => CurrencyConfig) internal _currencies;

    /// @notice Signer set members, managed by the admin.
    mapping(uint32 signerSetId => mapping(address signer => bool)) public
        signerSets;

    /// @notice How many each eligible wallet minted in each stage that has
    ///         a wallet limit.
    mapping(
        address token
            => mapping(
            uint256 id
                => mapping(
                uint256 stageIndex => mapping(address wallet => uint256)
            )
        )
    ) public mintedByWallet;

    /// @notice Which intent nonces each wallet used or cancelled.
    mapping(address wallet => mapping(uint256 nonce => bool used)) public
        intentNonceUsed;

    /// @notice Payments whose push failed, withdrawable by the account.
    mapping(address account => mapping(address currency => uint256 amount))
        public credited;

    bool private transient _entered;

    modifier nonReentrant() {
        _enter();
        _;
        _entered = false;
    }

    modifier onlyTokenOwner(address token) {
        _checkTokenOwner(token);
        _;
    }

    /// @param initialOwner The admin. Passed in so a CREATE2 deployer
    ///                     doesn't end up owning the minter.
    constructor(address initialOwner) EIP712("SeaDrop", "3") {
        _transferOwnership(initialOwner);
    }

    /// @inheritdoc ISeaDropMinter
    function setStage(
        address token,
        uint256 id,
        uint256 stageIndex,
        Stage calldata stage
    ) external onlyTokenOwner(token) {
        // Owner mints emit OWNER_MINT_STAGE, so no stage can use it
        if (stageIndex == OWNER_MINT_STAGE) {
            revert StageIndexReserved(stageIndex);
        }
        // An ERC-721 token ignores ids, so stages and wallet limits at
        // other ids would give each wallet extra limits in one collection.
        if (id != 0 && _supportsInterface(token, _ERC721_INTERFACE_ID)) {
            revert ERC721StageIdNotZero(id);
        }
        if (stage.endTime < stage.startTime) {
            revert StageEndsBeforeStart(stage.startTime, stage.endTime);
        }
        // A stage ending at 0 is never active, so clearing one skips the
        // currency and fee checks.
        if (stage.endTime != 0) _checkCurrencyAndFee(stage);

        _stages[token][id][stageIndex] = stage;

        emit StageUpdated(CONFIG_EVENT_VERSION, token, id, stageIndex, stage);
    }

    /// @inheritdoc ISeaDropMinter
    function setPayoutRecipients(
        address token,
        PayoutRecipient[] calldata recipients
    ) external onlyTokenOwner(token) {
        uint256 count = recipients.length;
        if (count == 0) revert NoPayoutRecipients();
        if (count > MAX_PAYOUT_RECIPIENTS) {
            revert TooManyPayoutRecipients(count);
        }

        delete _payoutRecipients[token];
        PayoutRecipient[] storage stored = _payoutRecipients[token];

        uint256 totalBps = 0;
        for (uint256 i = 0; i < count; ++i) {
            PayoutRecipient calldata recipient = recipients[i];
            if (recipient.recipient == address(0)) {
                revert PayoutRecipientIsZeroAddress();
            }
            // ETH paid to the minter would be credited to an account no
            // one can withdraw from, and an ERC-20 not credited at all
            if (recipient.recipient == address(this)) {
                revert PayoutRecipientIsMinter();
            }
            if (recipient.bps == 0) revert PayoutBpsIsZero();
            totalBps += recipient.bps;
            stored.push(recipient);
        }
        if (totalBps != _BPS) revert PayoutBpsTotalNot10000(totalBps);

        emit PayoutRecipientsUpdated(CONFIG_EVENT_VERSION, token, recipients);
    }

    /// @inheritdoc ISeaDropMinter
    function setCurrency(address currency, CurrencyConfig calldata config)
        external
        onlyOwner
    {
        if (config.minFeeBps > _BPS) revert FeeBpsTooHigh(config.minFeeBps);
        if (config.minFeeBps != 0 && config.feeRecipient == address(0)) {
            revert FeeRecipientIsZeroAddress();
        }
        if (config.feeRecipient == address(this)) {
            revert FeeRecipientIsMinter();
        }

        _currencies[currency] = config;

        emit CurrencyUpdated(CONFIG_EVENT_VERSION, currency, config);
    }

    /// @inheritdoc ISeaDropMinter
    function setSignerSetMember(
        uint32 signerSetId,
        address signer,
        bool allowed
    ) external onlyOwner {
        if (signerSetId == 0) revert SignerSetIdIsZero();

        signerSets[signerSetId][signer] = allowed;

        emit SignerSetUpdated(
            CONFIG_EVENT_VERSION,
            signerSetId,
            signer,
            allowed
        );
    }

    /**
     * @notice Mint, paid by the caller.
     *
     *         Any caller can pay for the eligible wallet. Tokens go to the
     *         wallet unless the caller is the wallet or its delegate.xyz
     *         delegate for the token, who can name another recipient. A
     *         signed stage's authorization with a nonzero `sender` can only
     *         be used by that sender.
     *
     *         ETH stages take exactly the total price. Excess ETH is
     *         rejected, not refunded.
     *
     * @param params        What to mint and what the caller pays.
     * @param authorization A signer's authorization for the wallet. Empty
     *                      for public stages.
     */
    function mint(
        MintParams calldata params,
        Authorization calldata authorization
    ) external payable nonReentrant {
        if (
            msg.sender != params.wallet && params.recipient != params.wallet
                && !_isDelegate(msg.sender, params.wallet, params.token)
        ) {
            revert RecipientNotApproved(params.wallet, params.recipient);
        }

        _mint(params, authorization);
    }

    /**
     * @notice Mint a wallet's signed intent. Anyone can submit it and pay.
     *         The signature is the wallet's consent to the payer and the
     *         recipient.
     *
     * @param intent          The intent `intent.params.wallet` signed.
     * @param intentSignature The wallet's EIP-712 signature, or its
     *                        ERC-1271 signature if it's a contract.
     * @param authorization   A signer's authorization for the wallet.
     *                        Empty for public stages.
     */
    function mintWithIntent(
        MintIntent calldata intent,
        bytes calldata intentSignature,
        Authorization calldata authorization
    ) external payable nonReentrant {
        MintParams calldata params = intent.params;

        if (block.timestamp > intent.expiry) {
            revert IntentExpired(intent.expiry);
        }
        if (intentNonceUsed[params.wallet][intent.nonce]) {
            revert IntentNonceUsed(params.wallet, intent.nonce);
        }

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    MINT_INTENT_TYPEHASH,
                    _hashMintParams(params),
                    intent.nonce,
                    intent.expiry
                )
            )
        );
        bool valid = SignatureChecker.isValidSignatureNow(
            params.wallet, digest, intentSignature
        );
        if (!valid) revert InvalidSignature();

        intentNonceUsed[params.wallet][intent.nonce] = true;

        _mint(params, authorization);
    }

    /// @inheritdoc ISeaDropMinter
    function ownerMint(
        address token,
        uint256 id,
        address recipient,
        uint256 quantity
    ) external nonReentrant onlyTokenOwner(token) {
        if (quantity == 0) revert QuantityIsZero();

        // Owner mints aren't capped by stages, but they raise the total
        // that stages' caps compare against.
        bool isV3 = _checkSupply(token, id, recipient, quantity, 0);
        _mintToken(token, id, recipient, quantity, isV3);

        emit SeaDropMint(
            token,
            id,
            OWNER_MINT_STAGE,
            msg.sender,
            msg.sender,
            recipient,
            quantity,
            0,
            address(0),
            address(0),
            0
        );
    }

    /// @inheritdoc ISeaDropMinter
    function cancelIntent(uint256 nonce) external {
        intentNonceUsed[msg.sender][nonce] = true;

        emit IntentCancelled(msg.sender, nonce);
    }

    /// @inheritdoc ISeaDropMinter
    function withdraw(address currency, address to) external nonReentrant {
        uint256 amount = credited[msg.sender][currency];
        if (amount == 0) revert NothingToWithdraw();

        credited[msg.sender][currency] = 0;

        if (currency == address(0)) {
            // The balance is zeroed first, and the only write after this
            // call is nonReentrant's unlock.
            // forge-lint: disable-next-line(reentrancy-eth)
            (bool success,) = to.call{ value: amount }("");
            if (!success) revert WithdrawalFailed();
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }

        emit Withdrawal(msg.sender, currency, to, amount);
    }

    /// @notice Renouncing also cancels a pending transfer, so a pending
    ///         owner can't claim the minter afterwards.
    function renounceOwnership() public override onlyOwner {
        cancelOwnershipTransfer();
        super.renounceOwnership();
    }

    /// @inheritdoc ISeaDropMinter
    function getStage(address token, uint256 id, uint256 stageIndex)
        external
        view
        returns (Stage memory)
    {
        return _stages[token][id][stageIndex];
    }

    /// @inheritdoc ISeaDropMinter
    function getPayoutRecipients(address token)
        external
        view
        returns (PayoutRecipient[] memory)
    {
        return _payoutRecipients[token];
    }

    /// @inheritdoc ISeaDropMinter
    function getCurrency(address currency)
        external
        view
        returns (CurrencyConfig memory)
    {
        return _currencies[currency];
    }

    /**
     * @dev The mint path `mint` and `mintWithIntent` share, once the
     *      recipient is approved. Any caller can pay. A nonzero
     *      authorization `sender` must be the caller. Every check runs
     *      before payment: the stage window, the authorization, the
     *      wallet limit, the currency policy, then the token's supply and
     *      the stage's `maxTokenSupplyForStage`, which compares against
     *      the token's total minted from every stage and owner mints.
     */
    function _mint(
        MintParams calldata params,
        Authorization calldata authorization
    ) internal {
        Stage memory stage = _stages[params.token][params.id][params.stageIndex];

        if (
            block.timestamp < stage.startTime || block.timestamp > stage.endTime
        ) {
            revert StageNotActive(
                block.timestamp,
                stage.startTime,
                stage.endTime
            );
        }
        if (params.quantity == 0) revert QuantityIsZero();

        uint256 unitPrice = stage.price;
        uint256 walletLimit = stage.maxPerWallet;
        if (stage.signer != address(0) || stage.signerSetId != 0) {
            (unitPrice, walletLimit) =
                _useAuthorization(params, stage, authorization);
        } else if (authorization.sender != address(0)) {
            // Nothing signed this sender link.
            revert SenderNeedsSignedStage();
        }

        _countWalletMint(params, walletLimit);

        // The admin may have disabled the currency or raised its minimum
        // fee since the stage was set.
        _checkCurrencyPolicy(stage.currency, stage.feeBps);

        uint256 totalPrice = unitPrice * params.quantity;
        // Copy the payout list before the first call that can change state
        // (the payment), so no callback during the mint can change where
        // its proceeds go
        PayoutRecipient[] memory recipients =
            _payoutSnapshot(params.token, stage, totalPrice);

        {
            // Check supply and the stage's cap before taking payment.
            bool isV3 = _checkSupply(
                params.token,
                params.id,
                params.recipient,
                params.quantity,
                stage.maxTokenSupplyForStage
            );

            _collectPayment(params, stage.currency, totalPrice);

            _mintToken(
                params.token, params.id, params.recipient, params.quantity, isV3
            );
        }

        _payOut(stage, totalPrice, recipients);

        emit SeaDropMint(
            params.token,
            params.id,
            params.stageIndex,
            msg.sender,
            params.wallet,
            params.recipient,
            params.quantity,
            unitPrice,
            stage.currency,
            stage.feeRecipient,
            stage.feeBps
        );
    }

    /**
     * @dev Check a signed stage's authorization. Returns the wallet's unit
     *      price and limit, with the authorization's overrides applied.
     */
    function _useAuthorization(
        MintParams calldata params,
        Stage memory stage,
        Authorization calldata authorization
    ) internal view returns (uint256 unitPrice, uint256 walletLimit) {
        address signer = authorization.signer;
        if (
            signer == address(0)
                || (signer != stage.signer
                    && !signerSets[stage.signerSetId][signer])
        ) {
            revert SignerNotAllowed(signer);
        }

        if (block.timestamp > authorization.expiry) {
            revert AuthorizationExpired(authorization.expiry);
        }

        address sender = authorization.sender;
        if (sender != address(0) && sender != msg.sender) {
            revert SenderMismatch(sender, msg.sender);
        }

        if (authorization.currency != stage.currency) {
            revert AuthorizationCurrencyMismatch(
                stage.currency,
                authorization.currency
            );
        }

        bytes32 digest =
            _hashTypedDataV4(_hashAuthorization(params, authorization));
        bool valid = SignatureChecker.isValidSignatureNow(
            signer, digest, authorization.signature
        );
        if (!valid) revert InvalidSignature();

        unitPrice = authorization.hasPrice ? authorization.price : stage.price;
        walletLimit = authorization.maxQuantity != 0
            ? authorization.maxQuantity
            : stage.maxPerWallet;
    }

    /**
     * @dev Count the mint against the eligible wallet's limit in the
     *      stage. A limit of 0 means no limit, and then nothing is counted,
     *      since limits are per stage and nothing else reads the count. So
     *      a limit added to a live stage starts every wallet at 0.
     */
    function _countWalletMint(MintParams calldata params, uint256 walletLimit)
        internal
    {
        if (walletLimit == 0) return;

        mapping(address wallet => uint256) storage minted =
            mintedByWallet[params.token][params.id][params.stageIndex];

        uint256 walletTotal = minted[params.wallet] + params.quantity;
        if (walletTotal > walletLimit) {
            revert MintQuantityExceedsWalletLimit(walletTotal, walletLimit);
        }
        minted[params.wallet] = walletTotal;
    }

    /**
     * @dev Take the payment from the payer. ETH must match the total
     *      exactly; ERC-20s are pulled into the minter, then paid out.
     */
    function _collectPayment(
        MintParams calldata params,
        address currency,
        uint256 totalPrice
    ) internal {
        if (params.currency != currency) {
            revert CurrencyMismatch(currency, params.currency);
        }
        if (totalPrice > params.maxTotalPrice) {
            revert TotalPriceExceedsMax(totalPrice, params.maxTotalPrice);
        }

        if (currency == address(0)) {
            if (msg.value != totalPrice) {
                revert IncorrectPayment(msg.value, totalPrice);
            }
            return;
        }

        if (msg.value != 0) revert IncorrectPayment(msg.value, 0);
        if (totalPrice == 0) return;

        // Check what arrived, so a fee-on-transfer token can't pay out
        // other accounts' credited balances.
        uint256 balanceBefore = IERC20(currency).balanceOf(address(this));
        IERC20(currency).safeTransferFrom(msg.sender, address(this), totalPrice);
        uint256 received =
            IERC20(currency).balanceOf(address(this)) - balanceBefore;
        if (received != totalPrice) {
            revert ERC20AmountNotReceived(received, totalPrice);
        }
    }

    /**
     * @dev Check a mint against the token's supply before any payment, and
     *      return whether the token is v3. A v3 token enforces its own max
     *      supply. v1 SeaDrop checked supply itself through getMintStats,
     *      so v1 tokens get the same check here.
     *
     *      A nonzero `stageCap` is the stage's `maxTokenSupplyForStage`,
     *      checked against the token's total minted (the id's, for an
     *      ERC-1155). A v3 token's total is only read when there's a cap,
     *      so uncapped mints cost nothing extra. A v1 token's total comes
     *      from the getMintStats call its max supply check already makes.
     *
     *      The reads are view calls into the token, made through
     *      staticcall, so they can't change state. Every mint entry point
     *      is nonReentrant, so the token can't reenter the minter to mint
     *      between this check and the mint.
     */
    function _checkSupply(
        address token,
        uint256 id,
        address recipient,
        uint256 quantity,
        uint256 stageCap
    ) internal view returns (bool isV3) {
        uint256 minted;
        if (_supportsInterface(token, type(ISeaDropTokenV3).interfaceId)) {
            if (stageCap == 0) return true;
            isV3 = true;
            // forge-lint: disable-next-line(unused-return)
            (minted,) = ISeaDropTokenV3(token).mintStats(id);
        } else {
            bytes4 v1InterfaceId = type(INonFungibleSeaDropToken).interfaceId;
            if (!_supportsInterface(token, v1InterfaceId)) {
                revert UnsupportedToken(token);
            }

            // getMintStats' first value counts the recipient's mints, not
            // the eligible wallet's, so the minter keeps its own count
            // instead.
            INonFungibleSeaDropToken v1Token = INonFungibleSeaDropToken(token);
            uint256 max;
            // forge-lint: disable-next-line(unused-return)
            (, minted, max) = v1Token.getMintStats(recipient);
            if (minted + quantity > max) {
                revert MintQuantityExceedsMaxSupply(minted + quantity, max);
            }
            if (stageCap == 0) return false;
        }

        if (minted + quantity > stageCap) {
            revert MintQuantityExceedsMaxTokenSupplyForStage(
                minted + quantity,
                stageCap
            );
        }
    }

    /**
     * @dev Mint through ISeaDropTokenV3, or through v1's
     *      INonFungibleSeaDropToken, after `_checkSupply`.
     */
    function _mintToken(
        address token,
        uint256 id,
        address recipient,
        uint256 quantity,
        bool isV3
    ) internal {
        if (isV3) {
            ISeaDropTokenV3(token).mintSeaDrop(recipient, id, quantity);
        } else {
            INonFungibleSeaDropToken(token).mintSeaDrop(recipient, quantity);
        }
    }

    /**
     * @dev The payout list a mint pays from, read before any external call
     *      that can change state. Empty when nothing goes to the payout
     *      recipients.
     */
    function _payoutSnapshot(
        address token,
        Stage memory stage,
        uint256 totalPrice
    ) internal view returns (PayoutRecipient[] memory recipients) {
        if (totalPrice - totalPrice * stage.feeBps / _BPS == 0) {
            return recipients;
        }
        recipients = _payoutRecipients[token];
        if (recipients.length == 0) revert NoPayoutRecipients();
    }

    /**
     * @dev Pay the stage fee, then split the rest across the token's
     *      payout recipients. The last recipient gets the rounding
     *      remainder.
     */
    function _payOut(
        Stage memory stage,
        uint256 totalPrice,
        PayoutRecipient[] memory recipients
    ) internal {
        if (totalPrice == 0) return;

        uint256 fee = totalPrice * stage.feeBps / _BPS;
        uint256 proceeds = totalPrice - fee;

        _send(stage.currency, stage.feeRecipient, fee);
        if (proceeds == 0) return;

        uint256 last = recipients.length - 1;

        uint256 paid = 0;
        for (uint256 i = 0; i < last; ++i) {
            PayoutRecipient memory recipient = recipients[i];
            uint256 amount = proceeds * recipient.bps / _BPS;
            paid += amount;
            _send(stage.currency, recipient.recipient, amount);
        }
        _send(stage.currency, recipients[last].recipient, proceeds - paid);
    }

    /**
     * @dev Push a payment. If the push fails, credit the recipient so a
     *      reverting recipient can't block minting.
     */
    function _send(address currency, address to, uint256 amount) internal {
        if (amount == 0) return;

        bool success = currency == address(0)
            ? _trySendETH(to, amount)
            : _tryTransferERC20(currency, to, amount);

        if (!success) {
            credited[to][currency] += amount;
            emit PaymentCredited(to, currency, amount);
        }
    }

    /**
     * @dev Send ETH with capped gas and without copying return data, so a
     *      recipient can't make the mint run out of gas.
     */
    function _trySendETH(address to, uint256 amount)
        internal
        returns (bool success)
    {
        assembly ("memory-safe") {
            success := call(ETH_PAYOUT_GAS, to, amount, 0, 0, 0, 0)
        }
    }

    /**
     * @notice Transfer an ERC-20 payout. Only the minter itself calls this,
     *         from `_tryTransferERC20`, so that a transfer the token
     *         rejects, or answers with anything other than nothing or
     *         `true`, reverts here and is rolled back.
     */
    function pushERC20(address currency, address to, uint256 amount) external {
        if (msg.sender != address(this)) revert OnlyMinterItself(msg.sender);
        IERC20(currency).safeTransfer(to, amount);
    }

    /**
     * @dev Transfer an ERC-20 with capped gas, returning false instead of
     *      reverting. The transfer runs in its own call, so one that fails
     *      or runs out of gas is rolled back before the caller credits the
     *      recipient, and its revert data isn't copied.
     */
    function _tryTransferERC20(address currency, address to, uint256 amount)
        internal
        returns (bool)
    {
        try this.pushERC20{ gas: ERC20_PAYOUT_GAS }(currency, to, amount) {
            return true;
        } catch {
            return false;
        }
    }

    /**
     * @dev A stage must price in an allowed currency, and meet the
     *      currency's minimum fee to its required fee recipient.
     */
    function _checkCurrencyAndFee(Stage calldata stage) internal view {
        if (stage.feeBps > _BPS) revert FeeBpsTooHigh(stage.feeBps);
        if (stage.feeBps != 0 && stage.feeRecipient == address(0)) {
            revert FeeRecipientIsZeroAddress();
        }
        if (stage.feeBps != 0 && stage.feeRecipient == address(this)) {
            revert FeeRecipientIsMinter();
        }

        CurrencyConfig memory config =
            _checkCurrencyPolicy(stage.currency, stage.feeBps);
        if (config.minFeeBps == 0) return;
        if (stage.feeRecipient != config.feeRecipient) {
            revert FeeRecipientNotRequired(
                stage.feeRecipient,
                config.feeRecipient
            );
        }
    }

    /**
     * @dev The currency must be allowed and the fee at least its minimum,
     *      under the admin's current config. `setStage` and every mint
     *      check this.
     */
    function _checkCurrencyPolicy(address currency, uint256 feeBps)
        internal
        view
        returns (CurrencyConfig memory config)
    {
        config = _currencies[currency];
        if (!config.allowed) revert CurrencyNotAllowed(currency);
        if (feeBps < config.minFeeBps) {
            revert FeeBelowMinimum(feeBps, config.minFeeBps);
        }
    }

    /**
     * @dev Whether `delegate` may act for `vault` on `token` in
     *      delegate.xyz's v2 registry. Where the registry isn't deployed,
     *      there are no delegates.
     */
    function _isDelegate(address delegate, address vault, address token)
        internal
        view
        returns (bool)
    {
        if (DELEGATE_REGISTRY.code.length == 0) return false;
        return IDelegateRegistry(DELEGATE_REGISTRY)
            .checkDelegateForContract(delegate, vault, token, bytes32(0));
    }

    /**
     * @dev ERC-165 detection that returns false instead of reverting for
     *      contracts without supportsInterface.
     */
    function _supportsInterface(address token, bytes4 interfaceId)
        internal
        view
        returns (bool)
    {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeCall(IERC165.supportsInterface, (interfaceId))
        );
        return success && data.length == 32 && abi.decode(data, (bool));
    }

    function _hashAuthorization(
        MintParams calldata params,
        Authorization calldata authorization
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                MINT_AUTHORIZATION_TYPEHASH,
                params.token,
                params.id,
                params.stageIndex,
                params.wallet,
                authorization.sender,
                authorization.currency,
                authorization.maxQuantity,
                authorization.hasPrice,
                authorization.price,
                authorization.expiry
            )
        );
    }

    function _hashMintParams(MintParams calldata params)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                MINT_PARAMS_TYPEHASH,
                params.token,
                params.id,
                params.stageIndex,
                params.wallet,
                params.recipient,
                params.quantity,
                params.currency,
                params.maxTotalPrice
            )
        );
    }

    function _checkTokenOwner(address token) internal view {
        if (IOwnable(token).owner() != msg.sender) {
            revert OnlyTokenOwner(token, msg.sender);
        }
    }

    function _enter() internal {
        if (_entered) revert Reentrancy();
        _entered = true;
    }
}
