// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";
import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";
import { RevertingRecipient, TestERC20 } from "./utils/Mocks.sol";
import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

/**
 * @dev Only the selected actions are fuzzed. Successful calls are not caught:
 *      fail_on_revert makes unexpected failures fail the campaign. The model
 *      derives charges from requested quantities, not minter accounting.
 */
contract SeaDropInvariantHandler is SeaDropV3TestHelper {
    uint256 internal constant ACTORS = 16;
    uint256 internal constant WALLET_LIMIT = 12;
    uint256 internal constant SUPPLY = 128;
    uint256 internal constant TOKEN_PRICE = 1_000_003;

    TestERC20 internal currency;
    RevertingRecipient internal rejectingCreator;
    address internal withdrawalSink = makeAddr("withdrawalSink");
    address[16] internal actors;
    uint256[2] internal sold;
    uint256[2] internal ownerMinted;
    uint256[2] internal stageCaps;
    uint256[2] internal collected;
    uint256[2] internal donated;
    mapping(uint256 => mapping(address => uint256)) internal spent;
    uint256[2] internal expectedCreatorCredit;
    uint256[2] internal expectedFeeCredit;
    uint256[2] internal withdrawn;
    mapping(uint256 => mapping(address => uint256)) internal walletMints;
    mapping(uint256 => mapping(address => uint256)) internal delivered;
    mapping(address => uint256) internal nextNonce;
    ISeaDropMinter.MintIntent internal lastIntent;
    bytes internal lastIntentSignature;
    ISeaDropMinter.Authorization internal lastAuthorization;
    bool internal hasIntent;
    uint256 public successfulMints;
    uint256 public successfulWithdrawals;
    uint256 public rejectedCalls;

    function setUp() public override {
        super.setUp();
        currency = new TestERC20();
        rejectingCreator = new RevertingRecipient();
        minter.setCurrency(
            address(currency),
            ISeaDropMinter.CurrencyConfig(true, uint16(FEE_BPS), feeRecipient)
        );
        token721.setMaxSupply(SUPPLY);
        token1155.setMaxSupply(ID_1155, uint128(SUPPLY));
        _setSinglePayout(address(token721), address(rejectingCreator));
        _setSinglePayout(address(token1155), address(rejectingCreator));
        for (uint256 i; i < ACTORS; ++i) {
            actors[i] = vm.addr(i + 100);
            vm.deal(actors[i], 1000 ether);
            currency.mint(actors[i], 1_000_000_000);
            vm.prank(actors[i]);
            currency.approve(address(minter), type(uint256).max);
        }
        setCap(0, 63);
        setCap(1, 63);
    }

    function _token(uint256 kind) internal view returns (address) {
        return kind == 0 ? address(token721) : address(token1155);
    }

    function _id(uint256 kind) internal pure returns (uint256) {
        return kind == 0 ? 0 : ID_1155;
    }

    function _currency(uint256 kind) internal view returns (address) {
        return kind == 0 ? address(0) : address(currency);
    }

    function _price(uint256 kind) internal pure returns (uint256) {
        return kind == 0 ? PRICE : TOKEN_PRICE;
    }

    /// @dev Change both stage caps without erasing the cumulative counts.
    function setCap(uint256 kindSeed, uint256 capSeed) public {
        uint256 kind = kindSeed % 2;
        uint256 total = sold[kind] + ownerMinted[kind];
        uint256 cap = bound(capSeed, total == 0 ? 1 : total, SUPPLY);
        stageCaps[kind] = cap;
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.currency = _currency(kind);
        stage.price = uint96(_price(kind));
        stage.maxPerWallet = uint32(WALLET_LIMIT);
        stage.maxTokenSupplyForStage = uint32(cap);
        minter.setStage(_token(kind), _id(kind), 0, stage);
        stage.signer = signer;
        minter.setStage(_token(kind), _id(kind), 1, stage);
    }

    function mint(
        uint256 kindSeed,
        uint256 actorSeed,
        uint256 quantitySeed,
        bool signedStage,
        bool useIntent,
        bool blockCreator,
        bool blockFee
    ) public {
        uint256 kind = kindSeed % 2;
        uint256 actorIndex = actorSeed % ACTORS;
        address wallet = actors[actorIndex];
        uint256 room = stageCaps[kind] - sold[kind] - ownerMinted[kind];
        uint256 walletRoom = WALLET_LIMIT - walletMints[kind][wallet];
        if (room > walletRoom) room = walletRoom;
        if (room == 0) return;
        uint256 quantity = bound(quantitySeed, 1, room > 3 ? 3 : room);
        address payer = actors[(actorIndex + 1) % ACTORS];
        address recipient =
            useIntent ? actors[(actorIndex + 2) % ACTORS] : wallet;
        ISeaDropMinter.MintParams memory params =
            _params(_token(kind), _id(kind), wallet, recipient, quantity);
        params.currency = _currency(kind);
        params.maxTotalPrice = _price(kind) * quantity;
        params.stageIndex = signedStage ? 1 : 0;
        ISeaDropMinter.Authorization memory auth = _noAuth();
        if (signedStage) {
            auth = _authorize(params, signer, signerKey, 0, false, 0);
        }
        currency.setBlocked(address(rejectingCreator), blockCreator);
        currency.setBlocked(feeRecipient, blockFee);
        uint256 value = kind == 0 ? params.maxTotalPrice : 0;
        if (useIntent) {
            ISeaDropMinter.MintIntent memory intent = ISeaDropMinter.MintIntent(
                params, nextNonce[wallet]++, vm.getBlockTimestamp() + 100
            );
            bytes memory signature =
                _sign(actorIndex + 100, _intentDigest(intent));
            vm.prank(payer);
            minter.mintWithIntent{ value: value }(intent, signature, auth);
            assertTrue(minter.intentNonceUsed(wallet, intent.nonce));
            lastIntent = intent;
            lastIntentSignature = signature;
            lastAuthorization = auth;
            hasIntent = true;
        } else {
            vm.prank(payer);
            minter.mint{ value: value }(params, auth);
        }
        _recordMint(kind, params, payer, blockCreator, blockFee);
    }

    function _recordMint(
        uint256 kind,
        ISeaDropMinter.MintParams memory params,
        address payer,
        bool blockCreator,
        bool blockFee
    ) internal {
        uint256 fee = params.maxTotalPrice * FEE_BPS / 10_000;
        if (kind == 0 || blockCreator) {
            expectedCreatorCredit[kind] += params.maxTotalPrice - fee;
        }
        if (kind == 1 && blockFee) expectedFeeCredit[kind] += fee;
        collected[kind] += params.maxTotalPrice;
        spent[kind][payer] += params.maxTotalPrice;
        sold[kind] += params.quantity;
        walletMints[kind][params.wallet] += params.quantity;
        delivered[kind][params.recipient] += params.quantity;
        ++successfulMints;
    }

    /// @dev Owner mints consume supply and future stage headroom, not wallet limits.
    function ownerMint(uint256 kindSeed, uint256 actorSeed) public {
        uint256 kind = kindSeed % 2;
        if (sold[kind] + ownerMinted[kind] == stageCaps[kind]) return;
        address recipient = actors[actorSeed % ACTORS];
        minter.ownerMint(_token(kind), _id(kind), recipient, 1);
        ++ownerMinted[kind];
        ++delivered[kind][recipient];
    }

    function withdraw(uint256 kindSeed, bool fee, bool fail) public {
        uint256 kind = kindSeed % 2;
        uint256 amount =
            fee ? expectedFeeCredit[kind] : expectedCreatorCredit[kind];
        if (amount == 0) return;
        address account = fee ? feeRecipient : address(rejectingCreator);
        address to = fail ? address(rejectingCreator) : withdrawalSink;
        currency.setBlocked(to, fail);
        vm.prank(account);
        if (fail) {
            if (kind == 0) {
                vm.expectRevert(ISeaDropMinter.WithdrawalFailed.selector);
            } else {
                vm.expectRevert(bytes("blocked"));
            }
            minter.withdraw(_currency(kind), to);
            ++rejectedCalls;
        } else {
            minter.withdraw(_currency(kind), to);
            if (fee) expectedFeeCredit[kind] = 0;
            else expectedCreatorCredit[kind] = 0;
            withdrawn[kind] += amount;
            ++successfulWithdrawals;
        }
    }

    /// @dev Rejected calls must leave all modeled balances and counts unchanged.
    function rejectUnauthorized(uint256 kindSeed, uint256 attackSeed) public {
        uint256 kind = kindSeed % 2;
        address token = _token(kind);
        address wallet = actors[0];
        address attacker = actors[1];
        ISeaDropMinter.MintParams memory params =
            _params(token, _id(kind), wallet, actors[2], 1);
        params.currency = _currency(kind);
        params.maxTotalPrice = _price(kind);
        uint256 value = kind == 0 ? params.maxTotalPrice : 0;
        uint256 attack = attackSeed % 3;
        if (attack == 0) {
            vm.prank(attacker);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISeaDropMinter.RecipientNotApproved.selector,
                    wallet,
                    actors[2]
                )
            );
            minter.mint{ value: value }(params, _noAuth());
        } else if (attack == 1) {
            params.recipient = wallet;
            params.stageIndex = 1;
            ISeaDropMinter.Authorization memory auth =
                _authorize(params, signer, 101, 0, false, 0);
            vm.prank(attacker);
            vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
            minter.mint{ value: value }(params, auth);
        } else {
            vm.prank(attacker);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISeaDropMinter.OnlyTokenOwner.selector, token, attacker
                )
            );
            minter.ownerMint(token, _id(kind), attacker, 1);
        }
        ++rejectedCalls;
    }

    function rejectReplay() public {
        if (!hasIntent) return;
        ISeaDropMinter.MintIntent memory intent = lastIntent;
        uint256 value = intent.params.currency == address(0)
            ? intent.params.maxTotalPrice
            : 0;
        vm.prank(actors[1]);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.IntentNonceUsed.selector,
                intent.params.wallet,
                intent.nonce
            )
        );
        minter.mintWithIntent{ value: value }(
            intent, lastIntentSignature, lastAuthorization
        );
        ++rejectedCalls;
    }

    /// @dev Force an actual limit violation; successful actions alone cannot
    ///      detect a removed wallet or stage guard because they stay in bounds.
    function rejectLimit(uint256 kindSeed, uint256 actorSeed, bool walletLimit)
        public
    {
        uint256 kind = kindSeed % 2;
        address wallet = actors[actorSeed % ACTORS];
        uint256 quantity = walletLimit
            ? WALLET_LIMIT - walletMints[kind][wallet] + 1
            : stageCaps[kind] - sold[kind] - ownerMinted[kind] + 1;
        // The wallet guard runs before the supply guard.
        if (!walletLimit && walletMints[kind][wallet] + quantity > WALLET_LIMIT)
        {
            return;
        }
        ISeaDropMinter.MintParams memory params =
            _params(_token(kind), _id(kind), wallet, wallet, quantity);
        params.currency = _currency(kind);
        params.maxTotalPrice = _price(kind) * quantity;
        vm.prank(wallet);
        if (walletLimit) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISeaDropMinter.MintQuantityExceedsWalletLimit.selector,
                    walletMints[kind][wallet] + quantity,
                    WALLET_LIMIT
                )
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISeaDropMinter.MintQuantityExceedsMaxTokenSupplyForStage
                    .selector,
                    sold[kind] + ownerMinted[kind] + quantity,
                    stageCaps[kind]
                )
            );
        }
        minter.mint{ value: kind == 0 ? params.maxTotalPrice : 0 }(
            params, _noAuth()
        );
        ++rejectedCalls;
    }

    /// @dev Model unsolicited surplus separately from proceeds and liabilities.
    function donate(uint256 kindSeed, uint256 amountSeed) public {
        uint256 kind = kindSeed % 2;
        uint256 amount = bound(amountSeed, 1, 1000);
        if (kind == 0) {
            // A contract without receive() can still receive forced ETH.
            vm.deal(address(minter), address(minter).balance + amount);
        } else {
            vm.prank(actors[0]);
            currency.transfer(address(minter), amount);
            spent[kind][actors[0]] += amount;
        }
        donated[kind] += amount;
    }

    /// @dev An underpayment must not spend the earlier recipients' credits.
    function rejectPayment(uint256 kindSeed) public {
        uint256 kind = kindSeed % 2;
        address wallet = actors[ACTORS - 1];
        if (
            walletMints[kind][wallet] == WALLET_LIMIT
                || sold[kind] + ownerMinted[kind] == stageCaps[kind]
        ) return;
        ISeaDropMinter.MintParams memory params =
            _params(_token(kind), _id(kind), wallet, wallet, 1);
        params.currency = _currency(kind);
        params.maxTotalPrice = _price(kind);
        if (kind == 1) currency.setTransferFeeBps(100);
        vm.prank(wallet);
        if (kind == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISeaDropMinter.IncorrectPayment.selector, PRICE - 1, PRICE
                )
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISeaDropMinter.ERC20AmountNotReceived.selector,
                    TOKEN_PRICE - TOKEN_PRICE / 100,
                    TOKEN_PRICE
                )
            );
        }
        minter.mint{ value: kind == 0 ? PRICE - 1 : 0 }(params, _noAuth());
        if (kind == 1) currency.setTransferFeeBps(0);
        ++rejectedCalls;
    }

    function assertAccountingAndSupply() external view {
        for (uint256 kind; kind < 2; ++kind) {
            address asset = _currency(kind);
            uint256 held = kind == 0
                ? address(minter).balance
                : currency.balanceOf(address(minter));
            uint256 paidCreator = kind == 0
                ? address(rejectingCreator).balance
                : currency.balanceOf(address(rejectingCreator));
            uint256 paidFee = kind == 0
                ? feeRecipient.balance
                : currency.balanceOf(feeRecipient);
            uint256 sink = kind == 0
                ? withdrawalSink.balance
                : currency.balanceOf(withdrawalSink);
            assertEq(
                minter.credited(address(rejectingCreator), asset),
                expectedCreatorCredit[kind]
            );
            assertEq(
                minter.credited(feeRecipient, asset), expectedFeeCredit[kind]
            );
            assertEq(
                held,
                expectedCreatorCredit[kind] + expectedFeeCredit[kind]
                    + donated[kind]
            );
            assertEq(sink, withdrawn[kind]);
            assertEq(
                collected[kind] + donated[kind],
                held + paidCreator + paidFee + sink
            );
            uint256 supply = sold[kind] + ownerMinted[kind];
            assertLe(supply, stageCaps[kind]);
            assertLe(supply, SUPPLY);
            uint256 sumBalances;
            for (uint256 i; i < ACTORS; ++i) {
                address wallet = actors[i];
                uint256 funding = kind == 0 ? 1000 ether : 1_000_000_000;
                uint256 funds =
                    kind == 0 ? wallet.balance : currency.balanceOf(wallet);
                assertEq(funds, funding - spent[kind][wallet]);
                assertEq(
                    minter.mintedByWallet(_token(kind), _id(kind), wallet),
                    walletMints[kind][wallet]
                );
                assertLe(walletMints[kind][wallet], WALLET_LIMIT);
                uint256 balance = kind == 0
                    ? token721.balanceOf(wallet)
                    : token1155.balanceOf(wallet, ID_1155);
                assertEq(balance, delivered[kind][wallet]);
                sumBalances += balance;
            }
            assertEq(sumBalances, supply);
        }
    }
}

contract SeaDropMinterInvariantTest is StdInvariant, Test {
    SeaDropInvariantHandler internal handler;

    function setUp() public {
        handler = new SeaDropInvariantHandler();
        handler.setUp();
        // Exercise success, credit creation, failed withdrawal, withdrawal,
        // signature authorization and nonce rejection before every campaign.
        handler.mint(0, 0, 1, false, false, false, false);
        handler.mint(1, 0, 1, true, true, true, true);
        handler.withdraw(0, false, true);
        handler.withdraw(1, false, true);
        handler.withdraw(0, false, false);
        handler.withdraw(1, false, false);
        handler.rejectPayment(0);
        handler.rejectPayment(1);
        handler.donate(0, 17);
        handler.donate(1, 19);
        handler.rejectReplay();
        handler.rejectUnauthorized(0, 0);
        handler.rejectUnauthorized(1, 1);
        handler.rejectUnauthorized(0, 2);
        handler.rejectLimit(0, 0, true);
        handler.setCap(1, 1);
        handler.rejectLimit(1, 1, false);
        handler.setCap(1, 63);

        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = handler.mint.selector;
        selectors[1] = handler.ownerMint.selector;
        selectors[2] = handler.setCap.selector;
        selectors[3] = handler.withdraw.selector;
        selectors[4] = handler.rejectUnauthorized.selector;
        selectors[5] = handler.rejectReplay.selector;
        selectors[6] = handler.rejectLimit.selector;
        selectors[7] = handler.donate.selector;
        selectors[8] = handler.rejectPayment.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
        targetContract(address(handler));
    }

    function invariant_paymentsAndTokenAccounting() public view {
        handler.assertAccountingAndSupply();
        assertGe(handler.successfulMints(), 2);
        assertGe(handler.successfulWithdrawals(), 2);
        assertGe(handler.rejectedCalls(), 10);
    }
}
