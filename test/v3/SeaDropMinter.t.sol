// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import {
    GasBurningRecipient,
    PayoutListChanger,
    MockDelegateRegistry,
    MockERC1271Wallet,
    NotASeaDropToken,
    ReentrantReceiver,
    RevertingRecipient,
    TestERC20
} from "./utils/Mocks.sol";

import { ISeaDropMinter } from "seadrop/v3/interfaces/ISeaDropMinter.sol";

import { SeaDropTokenV3Base } from "seadrop/v3/SeaDropTokenV3Base.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

contract SeaDropMinterTest is SeaDropV3TestHelper {
    address internal constant REGISTRY =
        0x00000000000000447e69651d841bD8D104Bed493;

    // ---------------------------------------------------------------------
    // Public mints, through one code path for ERC-721 and ERC-1155
    // ---------------------------------------------------------------------

    function test_mintPublic_ERC721() public {
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SeaDropMint(
            address(token721),
            0,
            0,
            alice,
            alice,
            alice,
            2,
            PRICE,
            address(0),
            feeRecipient,
            FEE_BPS
        );
        vm.prank(alice);
        minter.mint{ value: 2 * PRICE }(
            _params(address(token721), 0, alice, alice, 2), _noAuth()
        );

        assertEq(token721.ownerOf(1), alice);
        assertEq(token721.ownerOf(2), alice);
        assertEq(feeRecipient.balance, 2 * PRICE * FEE_BPS / 10_000);
        assertEq(creator.balance, 2 * PRICE * (10_000 - FEE_BPS) / 10_000);
        assertEq(address(minter).balance, 0);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, alice), 2);
    }

    function test_mintPublic_ERC1155() public {
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SeaDropMint(
            address(token1155),
            ID_1155,
            0,
            alice,
            alice,
            alice,
            2,
            PRICE,
            address(0),
            feeRecipient,
            FEE_BPS
        );
        vm.prank(alice);
        minter.mint{ value: 2 * PRICE }(
            _params(address(token1155), ID_1155, alice, alice, 2), _noAuth()
        );

        assertEq(token1155.balanceOf(alice, ID_1155), 2);
        assertEq(feeRecipient.balance, 2 * PRICE * FEE_BPS / 10_000);
        assertEq(creator.balance, 2 * PRICE * (10_000 - FEE_BPS) / 10_000);
        (uint256 totalMinted, uint256 maxSupply) = token1155.mintStats(ID_1155);
        assertEq(totalMinted, 2);
        assertEq(maxSupply, MAX_SUPPLY);
    }

    function test_mintPublic_bothTokensThroughSamePath() public {
        address[2] memory tokens = [address(token721), address(token1155)];
        uint256[2] memory ids = [uint256(0), ID_1155];
        for (uint256 i = 0; i < 2; ++i) {
            vm.prank(alice);
            minter.mint{ value: 3 * PRICE }(
                _params(tokens[i], ids[i], alice, alice, 3), _noAuth()
            );
            assertEq(minter.mintedByWallet(tokens[i], ids[i], 0, alice), 3);
        }
        assertEq(token721.balanceOf(alice), 3);
        assertEq(token1155.balanceOf(alice, ID_1155), 3);
    }

    function test_mintPublic_freeStage() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.price = 0;
        minter.setStage(address(token721), 0, 0, stage);

        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        params.maxTotalPrice = 0;
        vm.prank(alice);
        minter.mint(params, _noAuth());

        assertEq(token721.ownerOf(1), alice);
        assertEq(creator.balance, 0);
    }

    function test_revert_mint_excessETHIsRejected() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.IncorrectPayment.selector, 3 * PRICE, 2 * PRICE
            )
        );
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 2);
        params.maxTotalPrice = 3 * PRICE;
        minter.mint{ value: 3 * PRICE }(params, _noAuth());
    }

    function test_revert_mint_insufficientETH() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.IncorrectPayment.selector, PRICE, 2 * PRICE
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 2), _noAuth()
        );
    }

    function test_revert_mint_priceAboveMax() public {
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 2);
        params.maxTotalPrice = PRICE;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.TotalPriceExceedsMax.selector, 2 * PRICE, PRICE
            )
        );
        minter.mint{ value: 2 * PRICE }(params, _noAuth());
    }

    function test_revert_mint_currencyMismatch() public {
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        params.currency = address(1);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.CurrencyMismatch.selector, address(0), address(1)
            )
        );
        minter.mint{ value: PRICE }(params, _noAuth());
    }

    function test_revert_mint_quantityZero() public {
        vm.prank(alice);
        vm.expectRevert(ISeaDropMinter.QuantityIsZero.selector);
        minter.mint(_params(address(token721), 0, alice, alice, 0), _noAuth());
    }

    function test_revert_mint_unsupportedToken() public {
        NotASeaDropToken notToken = new NotASeaDropToken();
        minter.setStage(address(notToken), 0, 0, _publicStage());
        _setSinglePayout(address(notToken), creator);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.UnsupportedToken.selector, address(notToken)
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(notToken), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_revert_mint_reentrancy() public {
        ReentrantReceiver receiver = new ReentrantReceiver(minter);
        vm.deal(address(receiver), 1 ether);
        minter.setTrustedPayer(alice, true);
        receiver.setParams(
            _params(
                address(token721), 0, address(receiver), address(receiver), 1
            )
        );

        vm.prank(alice);
        vm.expectRevert(ISeaDropMinter.Reentrancy.selector);
        minter.mint{ value: PRICE }(
            _params(
                address(token721), 0, address(receiver), address(receiver), 1
            ),
            _noAuth()
        );
    }

    // ---------------------------------------------------------------------
    // Stage windows
    // ---------------------------------------------------------------------

    function test_mint_windowIsInclusive() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.startTime = uint40(vm.getBlockTimestamp() + 10);
        stage.endTime = uint40(vm.getBlockTimestamp() + 20);
        minter.setStage(address(token721), 0, 0, stage);

        vm.warp(vm.getBlockTimestamp() + 10);
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );

        vm.warp(vm.getBlockTimestamp() + 10);
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
        assertEq(token721.balanceOf(alice), 2);
    }

    function test_revert_mint_beforeStart() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.startTime = uint40(vm.getBlockTimestamp() + 10);
        minter.setStage(address(token721), 0, 0, stage);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.StageNotActive.selector,
                vm.getBlockTimestamp(),
                stage.startTime,
                stage.endTime
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_revert_mint_afterEnd() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        vm.warp(uint256(stage.endTime) + 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.StageNotActive.selector,
                vm.getBlockTimestamp(),
                stage.startTime,
                stage.endTime
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_revert_mint_unsetStage() public {
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        params.stageIndex = 9;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.StageNotActive.selector,
                vm.getBlockTimestamp(),
                0,
                0
            )
        );
        minter.mint{ value: PRICE }(params, _noAuth());
    }

    // ---------------------------------------------------------------------
    // Wallet limits, per stage
    // ---------------------------------------------------------------------

    function test_revert_mint_walletLimit() public {
        vm.prank(alice);
        minter.mint{ value: 5 * PRICE }(
            _params(address(token721), 0, alice, alice, 5), _noAuth()
        );

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.MintQuantityExceedsWalletLimit.selector, 6, 5
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_mint_walletLimitIsPerStage() public {
        ISeaDropMinter.Stage memory stage1 = _publicStage();
        stage1.maxPerWallet = 2;
        minter.setStage(address(token721), 0, 1, stage1);

        vm.prank(alice);
        minter.mint{ value: 5 * PRICE }(
            _params(address(token721), 0, alice, alice, 5), _noAuth()
        );

        // Stage 0's five don't count toward stage 1's limit of two.
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 2);
        params.stageIndex = 1;
        vm.prank(alice);
        minter.mint{ value: 2 * PRICE }(params, _noAuth());

        assertEq(minter.mintedByWallet(address(token721), 0, 0, alice), 5);
        assertEq(minter.mintedByWallet(address(token721), 0, 1, alice), 2);

        params.quantity = 1;
        params.maxTotalPrice = PRICE;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.MintQuantityExceedsWalletLimit.selector, 3, 2
            )
        );
        minter.mint{ value: PRICE }(params, _noAuth());
    }

    function test_mint_zeroWalletLimitIsUnlimited() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.maxPerWallet = 0;
        minter.setStage(address(token721), 0, 0, stage);

        vm.prank(alice);
        minter.mint{ value: 20 * PRICE }(
            _params(address(token721), 0, alice, alice, 20), _noAuth()
        );
        assertEq(token721.balanceOf(alice), 20);
        // An unlimited stage doesn't count, to save the storage write.
        assertEq(minter.mintedByWallet(address(token721), 0, 0, alice), 0);
    }

    // ---------------------------------------------------------------------
    // Max supply
    // ---------------------------------------------------------------------

    function test_revert_mint_maxSupply_ERC721() public {
        token721.setMaxSupply(3);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.MintQuantityExceedsMaxSupply.selector, 4, 3
            )
        );
        minter.mint{ value: 4 * PRICE }(
            _params(address(token721), 0, alice, alice, 4), _noAuth()
        );
    }

    function test_revert_mint_maxSupply_ERC1155IsPerId() public {
        token1155.setMaxSupply(ID_1155, 3);
        token1155.setMaxSupply(ID_1155 + 1, 10);
        minter.setStage(address(token1155), ID_1155 + 1, 0, _publicStage());

        vm.prank(alice);
        minter.mint{ value: 4 * PRICE }(
            _params(address(token1155), ID_1155 + 1, alice, alice, 4), _noAuth()
        );

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.MintQuantityExceedsMaxSupply.selector, 4, 3
            )
        );
        minter.mint{ value: 4 * PRICE }(
            _params(address(token1155), ID_1155, alice, alice, 4), _noAuth()
        );
    }

    // ---------------------------------------------------------------------
    // Signed stages
    // ---------------------------------------------------------------------

    function _setSignedStage(address stageSigner, uint64 signerSetId) internal {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.signer = stageSigner;
        stage.signerSetId = signerSetId;
        minter.setStage(address(token721), 0, 0, stage);
    }

    function test_mintSigned_stageSignerEOA() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 2);

        vm.prank(alice);
        minter.mint{ value: 2 * PRICE }(
            params, _authorize(params, signer, signerKey, 0, false, 0)
        );
        assertEq(token721.balanceOf(alice), 2);
    }

    function test_mintSigned_stageSignerERC1271() public {
        MockERC1271Wallet signerContract = new MockERC1271Wallet(signer);
        _setSignedStage(address(signerContract), 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);

        vm.prank(alice);
        minter.mint{ value: PRICE }(
            params,
            _authorize(params, address(signerContract), signerKey, 0, false, 0)
        );
        assertEq(token721.ownerOf(1), alice);
    }

    function test_mintSigned_signerSet() public {
        minter.setSignerSetMember(1, signer, true);
        _setSignedStage(address(0), 1);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);

        vm.prank(alice);
        minter.mint{ value: PRICE }(
            params, _authorize(params, signer, signerKey, 0, false, 0)
        );
        assertEq(token721.ownerOf(1), alice);
    }

    function test_mintSigned_signerSetRotationNeedsNoCreatorChange() public {
        minter.setSignerSetMember(1, signer, true);
        _setSignedStage(address(0), 1);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        ISeaDropMinter.Authorization memory oldAuth =
            _authorize(params, signer, signerKey, 0, false, 0);

        // The admin rotates the key. The stage is untouched.
        (address newSigner, uint256 newKey) = makeAddrAndKey("newSigner");
        minter.setSignerSetMember(1, signer, false);
        minter.setSignerSetMember(1, newSigner, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.SignerNotAllowed.selector, signer
            )
        );
        minter.mint{ value: PRICE }(params, oldAuth);

        vm.prank(alice);
        minter.mint{ value: PRICE }(
            params, _authorize(params, newSigner, newKey, 0, false, 0)
        );
        assertEq(token721.ownerOf(1), alice);
    }

    function test_revert_mintSigned_signerNotAllowed() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.SignerNotAllowed.selector, bob
            )
        );
        minter.mint{ value: PRICE }(
            params, _authorize(params, bob, bobKey, 0, false, 0)
        );
    }

    function test_revert_mintSigned_withoutAuthorization() public {
        minter.setSignerSetMember(1, signer, true);
        _setSignedStage(address(0), 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.SignerNotAllowed.selector, address(0)
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_revert_mintSigned_wrongKey() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);

        vm.prank(alice);
        vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(
            params, _authorize(params, signer, bobKey, 0, false, 0)
        );
    }

    function test_revert_mintSigned_expired() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        ISeaDropMinter.Authorization memory auth =
            _authorize(params, signer, signerKey, 0, false, 0);

        vm.warp(auth.expiry + 1);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.AuthorizationExpired.selector, auth.expiry
            )
        );
        minter.mint{ value: PRICE }(params, auth);
    }

    function test_revert_mintSigned_authorizationIsForOneWallet() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.Authorization memory aliceAuth = _authorize(
            _params(address(token721), 0, alice, alice, 1),
            signer,
            signerKey,
            0,
            false,
            0
        );

        vm.prank(bob);
        vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, bob, bob, 1), aliceAuth
        );
    }

    function test_mintSigned_priceOverride() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 2);
        params.maxTotalPrice = 2 * 0.05 ether;

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SeaDropMint(
            address(token721),
            0,
            0,
            alice,
            alice,
            alice,
            2,
            0.05 ether,
            address(0),
            feeRecipient,
            FEE_BPS
        );
        vm.prank(alice);
        minter.mint{ value: 2 * 0.05 ether }(
            params, _authorize(params, signer, signerKey, 0, true, 0.05 ether)
        );
        assertEq(creator.balance, 0.1 ether * (10_000 - FEE_BPS) / 10_000);
    }

    function test_mintSigned_freePriceOverride() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        params.maxTotalPrice = 0;

        vm.prank(alice);
        minter.mint(params, _authorize(params, signer, signerKey, 0, true, 0));
        assertEq(token721.ownerOf(1), alice);
    }

    function test_revert_mintSigned_tamperedPrice() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        ISeaDropMinter.Authorization memory auth =
            _authorize(params, signer, signerKey, 0, true, 0.05 ether);
        auth.price = 0;
        params.maxTotalPrice = 0;

        vm.prank(alice);
        vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
        minter.mint(params, auth);
    }

    function test_mintSigned_maxQuantityOverridesStageLimit() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 4);
        // The stage allows 5 per wallet; this wallet's allocation is 7.
        ISeaDropMinter.Authorization memory auth =
            _authorize(params, signer, signerKey, 7, false, 0);

        vm.prank(alice);
        minter.mint{ value: 4 * PRICE }(params, auth);

        // The same authorization can be reused up to the wallet's limit,
        // since it's counted against the wallet's stage total.
        params.quantity = 3;
        params.maxTotalPrice = 3 * PRICE;
        vm.prank(alice);
        minter.mint{ value: 3 * PRICE }(params, auth);

        params.quantity = 1;
        params.maxTotalPrice = PRICE;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.MintQuantityExceedsWalletLimit.selector, 8, 7
            )
        );
        minter.mint{ value: PRICE }(params, auth);
    }

    function test_revert_mintSigned_zeroMaxQuantityKeepsStageLimit() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.MintQuantityExceedsWalletLimit.selector, 6, 5
            )
        );
        minter.mint{ value: 6 * PRICE }(
            params, _authorize(params, signer, signerKey, 0, false, 0)
        );
    }

    // ---------------------------------------------------------------------
    // Payer, eligible wallet and recipient
    // ---------------------------------------------------------------------

    function test_revert_mint_untrustedPayerForAnotherWallet() public {
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ISeaDropMinter.PayerNotAllowed.selector, bob)
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_mint_trustedPayerPaysForWallet() public {
        address router = makeAddr("router");
        vm.deal(router, 1 ether);
        minter.setTrustedPayer(router, true);

        vm.prank(router);
        minter.mint{ value: 2 * PRICE }(
            _params(address(token721), 0, alice, alice, 2), _noAuth()
        );

        assertEq(token721.balanceOf(alice), 2);
        assertEq(token721.balanceOf(router), 0);
        // Open design question: a payer minting to someone else's wallet
        // uses up that wallet's per-wallet limit. Here the router spent two
        // of alice's five. Only payers alice delegated to, payers the admin
        // trusts, and payers the token's owner allowed can do this.
        assertEq(minter.mintedByWallet(address(token721), 0, 0, alice), 2);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, router), 0);

        minter.setTrustedPayer(router, false);
        vm.prank(router);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.PayerNotAllowed.selector, router
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
    }

    function test_mint_allowedPayerIsPerToken() public {
        minter.setAllowedPayer(address(token721), bob, true);
        assertTrue(minter.allowedPayers(address(token721), bob));

        vm.prank(bob);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
        assertEq(token721.ownerOf(1), alice);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ISeaDropMinter.PayerNotAllowed.selector, bob)
        );
        minter.mint{ value: PRICE }(
            _params(address(token1155), ID_1155, alice, alice, 1), _noAuth()
        );
    }

    function test_revert_mint_trustedPayerCannotRedirect() public {
        address router = makeAddr("router");
        vm.deal(router, 1 ether);
        minter.setTrustedPayer(router, true);

        vm.prank(router);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.RecipientNotApproved.selector, alice, router
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, router, 1), _noAuth()
        );
    }

    function test_mint_walletChoosesRecipient() public {
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, carol, 1), _noAuth()
        );
        assertEq(token721.ownerOf(1), carol);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, alice), 1);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, carol), 0);
    }

    function _etchRegistry() internal {
        vm.etch(REGISTRY, address(new MockDelegateRegistry()).code);
    }

    function test_mint_delegateMintsForVaultToItself() public {
        _etchRegistry();
        address vault = alice;
        address hot = bob;
        vm.prank(vault);
        MockDelegateRegistry(REGISTRY)
            .delegateContract(hot, address(token721), "", true);

        // The hot wallet uses the vault's signed allocation and keeps the
        // tokens.
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, vault, hot, 2);
        ISeaDropMinter.Authorization memory auth =
            _authorize(params, signer, signerKey, 0, false, 0);

        vm.prank(hot);
        minter.mint{ value: 2 * PRICE }(params, auth);

        assertEq(token721.balanceOf(hot), 2);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, vault), 2);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, hot), 0);
    }

    function test_mint_delegateAllCoversEveryToken() public {
        _etchRegistry();
        vm.prank(alice);
        MockDelegateRegistry(REGISTRY).delegateAll(bob, "", true);

        vm.prank(bob);
        minter.mint{ value: PRICE }(
            _params(address(token1155), ID_1155, alice, bob, 1), _noAuth()
        );
        assertEq(token1155.balanceOf(bob, ID_1155), 1);
    }

    function test_mint_delegatePaysForVault() public {
        _etchRegistry();
        vm.prank(alice);
        MockDelegateRegistry(REGISTRY)
            .delegateContract(bob, address(token721), "", true);

        vm.prank(bob);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
        assertEq(token721.ownerOf(1), alice);
    }

    function test_revert_mint_delegateForAnotherContract() public {
        _etchRegistry();
        vm.prank(alice);
        MockDelegateRegistry(REGISTRY)
            .delegateContract(bob, address(token1155), "", true);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.RecipientNotApproved.selector, alice, bob
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, bob, 1), _noAuth()
        );
    }

    function test_revert_mint_noRegistryMeansNoDelegates() public {
        assertEq(REGISTRY.code.length, 0);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.RecipientNotApproved.selector, alice, bob
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, bob, 1), _noAuth()
        );
    }

    // ---------------------------------------------------------------------
    // Senders a stage signer links to the eligible wallet
    // ---------------------------------------------------------------------

    /// @dev alice is on the allow list; bob is her embedded wallet, which
    ///      OpenSea's signer links to her without any onchain delegation.
    function _setSignerSetStage() internal {
        minter.setSignerSetMember(1, signer, true);
        _setSignedStage(address(0), 1);
    }

    function test_mintSigned_linkedSenderMintsForWallet() public {
        _setSignerSetStage();
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 2);
        assertFalse(minter.trustedPayers(bob));

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SeaDropMint(
            address(token721),
            0,
            0,
            bob,
            alice,
            alice,
            2,
            PRICE,
            address(0),
            feeRecipient,
            FEE_BPS
        );
        vm.prank(bob);
        minter.mint{ value: 2 * PRICE }(params, _authorizeLinked(params, bob));

        assertEq(token721.balanceOf(alice), 2);
        assertEq(token721.balanceOf(bob), 0);
        assertEq(bob.balance, 100 ether - 2 * PRICE);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, alice), 2);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, bob), 0);

        // The count is alice's: she mints her other 3 herself, and then
        // bob can't mint more for her.
        params.quantity = 3;
        params.maxTotalPrice = 3 * PRICE;
        vm.prank(alice);
        minter.mint{ value: 3 * PRICE }(
            params, _authorize(params, signer, signerKey, 0, false, 0)
        );

        params.quantity = 1;
        params.maxTotalPrice = PRICE;
        ISeaDropMinter.Authorization memory auth = _authorizeLinked(params, bob);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.MintQuantityExceedsWalletLimit.selector, 6, 5
            )
        );
        minter.mint{ value: PRICE }(params, auth);
    }

    function test_revert_mintSigned_linkedSenderIsTheOnlyCaller() public {
        _setSignerSetStage();
        address router = makeAddr("router");
        vm.deal(router, 1 ether);
        minter.setTrustedPayer(router, true);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        ISeaDropMinter.Authorization memory auth = _authorizeLinked(params, bob);

        // Not an untrusted caller, a trusted payer, or the wallet itself.
        address[3] memory callers = [carol, router, alice];
        vm.deal(carol, 1 ether);
        for (uint256 i = 0; i < callers.length; ++i) {
            vm.prank(callers[i]);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ISeaDropMinter.SenderMismatch.selector, bob, callers[i]
                )
            );
            minter.mint{ value: PRICE }(params, auth);
        }
    }

    function test_revert_mintSigned_linkedSenderCannotRedirect() public {
        _setSignerSetStage();
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, bob, 1);
        ISeaDropMinter.Authorization memory auth = _authorizeLinked(params, bob);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.RecipientNotApproved.selector, alice, bob
            )
        );
        minter.mint{ value: PRICE }(params, auth);
    }

    function test_mintSigned_linkedSenderDelegateCanRedirect() public {
        _etchRegistry();
        vm.prank(alice);
        MockDelegateRegistry(REGISTRY)
            .delegateContract(bob, address(token721), "", true);
        _setSignerSetStage();
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, bob, 1);

        vm.prank(bob);
        minter.mint{ value: PRICE }(params, _authorizeLinked(params, bob));
        assertEq(token721.ownerOf(1), bob);
    }

    function test_revert_mintSigned_tamperedSender() public {
        _setSignerSetStage();
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        ISeaDropMinter.Authorization memory auth = _authorizeLinked(params, bob);
        auth.sender = carol;
        vm.deal(carol, 1 ether);

        vm.prank(carol);
        vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
        minter.mint{ value: PRICE }(params, auth);
    }

    function test_revert_mint_senderOnPublicStage() public {
        // Unsigned, a sender would let anyone skip the payer rules.
        ISeaDropMinter.Authorization memory auth = _noAuth();
        auth.sender = bob;

        vm.prank(bob);
        vm.expectRevert(ISeaDropMinter.SenderNeedsSignedStage.selector);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), auth
        );
    }

    function test_mintSigned_zeroSenderKeepsPayerRules() public {
        _setSignerSetStage();
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        ISeaDropMinter.Authorization memory auth =
            _authorize(params, signer, signerKey, 0, false, 0);
        assertEq(auth.sender, address(0));

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ISeaDropMinter.PayerNotAllowed.selector, bob)
        );
        minter.mint{ value: PRICE }(params, auth);

        minter.setTrustedPayer(bob, true);
        vm.prank(bob);
        minter.mint{ value: PRICE }(params, auth);
        assertEq(token721.ownerOf(1), alice);
    }

    function test_mintWithIntent_linkedSenderMustSubmit() public {
        _setSignerSetStage();
        address relayer = makeAddr("relayer");
        vm.deal(relayer, 1 ether);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, carol, 1);
        ISeaDropMinter.MintIntent memory intent = _intent(params, 1);
        bytes memory intentSignature = _sign(aliceKey, _intentDigest(intent));
        ISeaDropMinter.Authorization memory auth =
            _authorizeLinked(params, relayer);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.SenderMismatch.selector, relayer, bob
            )
        );
        minter.mintWithIntent{ value: PRICE }(intent, intentSignature, auth);

        vm.prank(relayer);
        minter.mintWithIntent{ value: PRICE }(intent, intentSignature, auth);
        assertEq(token721.ownerOf(1), carol);
    }

    // ---------------------------------------------------------------------
    // Signed intents
    // ---------------------------------------------------------------------

    function _intent(ISeaDropMinter.MintParams memory params, uint256 nonce)
        internal
        view
        returns (ISeaDropMinter.MintIntent memory)
    {
        return ISeaDropMinter.MintIntent({
            params: params,
            nonce: nonce,
            expiry: vm.getBlockTimestamp() + 100
        });
    }

    function test_mintWithIntent_relayerPays() public {
        address relayer = makeAddr("relayer");
        vm.deal(relayer, 1 ether);
        ISeaDropMinter.MintIntent memory intent =
            _intent(_params(address(token721), 0, alice, carol, 2), 1);
        bytes memory signature = _sign(aliceKey, _intentDigest(intent));

        vm.prank(relayer);
        minter.mintWithIntent{ value: 2 * PRICE }(intent, signature, _noAuth());

        assertEq(token721.balanceOf(carol), 2);
        assertEq(relayer.balance, 1 ether - 2 * PRICE);
        assertEq(alice.balance, 100 ether);
        assertEq(minter.mintedByWallet(address(token721), 0, 0, alice), 2);
        assertTrue(minter.intentNonceUsed(alice, 1));
    }

    function test_mintWithIntent_smartAccountWallet() public {
        MockERC1271Wallet account = new MockERC1271Wallet(alice);
        ISeaDropMinter.MintIntent memory intent = _intent(
            _params(
                address(token1155),
                ID_1155,
                address(account),
                address(account),
                1
            ),
            1
        );
        bytes memory signature = _sign(aliceKey, _intentDigest(intent));

        vm.prank(bob);
        minter.mintWithIntent{ value: PRICE }(intent, signature, _noAuth());
        assertEq(token1155.balanceOf(address(account), ID_1155), 1);
    }

    function test_mintWithIntent_signedStage() public {
        _setSignedStage(signer, 0);
        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, carol, 1);
        ISeaDropMinter.MintIntent memory intent = _intent(params, 1);

        vm.prank(bob);
        minter.mintWithIntent{ value: PRICE }(
            intent,
            _sign(aliceKey, _intentDigest(intent)),
            _authorize(params, signer, signerKey, 0, false, 0)
        );
        assertEq(token721.ownerOf(1), carol);
    }

    function test_revert_mintWithIntent_nonceReused() public {
        ISeaDropMinter.MintIntent memory intent =
            _intent(_params(address(token721), 0, alice, carol, 1), 1);
        bytes memory signature = _sign(aliceKey, _intentDigest(intent));

        vm.prank(bob);
        minter.mintWithIntent{ value: PRICE }(intent, signature, _noAuth());

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.IntentNonceUsed.selector, alice, 1
            )
        );
        minter.mintWithIntent{ value: PRICE }(intent, signature, _noAuth());
    }

    function test_revert_mintWithIntent_cancelled() public {
        ISeaDropMinter.MintIntent memory intent =
            _intent(_params(address(token721), 0, alice, carol, 1), 1);
        bytes memory signature = _sign(aliceKey, _intentDigest(intent));

        vm.prank(alice);
        minter.cancelIntent(1);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.IntentNonceUsed.selector, alice, 1
            )
        );
        minter.mintWithIntent{ value: PRICE }(intent, signature, _noAuth());
    }

    function test_revert_mintWithIntent_expired() public {
        ISeaDropMinter.MintIntent memory intent =
            _intent(_params(address(token721), 0, alice, carol, 1), 1);
        bytes memory signature = _sign(aliceKey, _intentDigest(intent));

        vm.warp(intent.expiry + 1);
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.IntentExpired.selector, intent.expiry
            )
        );
        minter.mintWithIntent{ value: PRICE }(intent, signature, _noAuth());
    }

    function test_revert_mintWithIntent_tamperedRecipient() public {
        ISeaDropMinter.MintIntent memory intent =
            _intent(_params(address(token721), 0, alice, carol, 1), 1);
        bytes memory signature = _sign(aliceKey, _intentDigest(intent));
        intent.params.recipient = bob;

        vm.prank(bob);
        vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
        minter.mintWithIntent{ value: PRICE }(intent, signature, _noAuth());
    }

    function test_revert_mintWithIntent_notSignedByWallet() public {
        ISeaDropMinter.MintIntent memory intent =
            _intent(_params(address(token721), 0, alice, bob, 1), 1);
        bytes memory signature = _sign(bobKey, _intentDigest(intent));

        vm.prank(bob);
        vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
        minter.mintWithIntent{ value: PRICE }(intent, signature, _noAuth());
    }

    function test_revert_mintWithIntent_priceRaisedAfterSigning() public {
        ISeaDropMinter.MintIntent memory intent =
            _intent(_params(address(token721), 0, alice, carol, 1), 1);
        bytes memory signature = _sign(aliceKey, _intentDigest(intent));

        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.price = uint96(2 * PRICE);
        minter.setStage(address(token721), 0, 0, stage);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.TotalPriceExceedsMax.selector, 2 * PRICE, PRICE
            )
        );
        minter.mintWithIntent{ value: 2 * PRICE }(intent, signature, _noAuth());
    }

    // ---------------------------------------------------------------------
    // ERC-20 payments
    // ---------------------------------------------------------------------

    function _setERC20Stage(TestERC20 currency, uint96 price) internal {
        minter.setCurrency(
            address(currency),
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: uint16(FEE_BPS),
                feeRecipient: feeRecipient
            })
        );
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.currency = address(currency);
        stage.price = price;
        minter.setStage(address(token721), 0, 0, stage);
    }

    function _erc20Params(TestERC20 currency, uint256 quantity, uint256 price)
        internal
        view
        returns (ISeaDropMinter.MintParams memory params)
    {
        params = _params(address(token721), 0, alice, alice, quantity);
        params.currency = address(currency);
        params.maxTotalPrice = price * quantity;
    }

    function test_mintERC20() public {
        TestERC20 usdc = new TestERC20();
        _setERC20Stage(usdc, 10e6);
        usdc.mint(alice, 100e6);
        vm.prank(alice);
        usdc.approve(address(minter), 20e6);

        vm.prank(alice);
        minter.mint(_erc20Params(usdc, 2, 10e6), _noAuth());

        assertEq(token721.balanceOf(alice), 2);
        assertEq(usdc.balanceOf(alice), 80e6);
        assertEq(usdc.balanceOf(feeRecipient), 20e6 * FEE_BPS / 10_000);
        assertEq(usdc.balanceOf(creator), 20e6 * (10_000 - FEE_BPS) / 10_000);
        assertEq(usdc.balanceOf(address(minter)), 0);
    }

    function test_revert_mintERC20_withETH() public {
        TestERC20 usdc = new TestERC20();
        _setERC20Stage(usdc, 10e6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.IncorrectPayment.selector, 1, 0
            )
        );
        minter.mint{ value: 1 }(_erc20Params(usdc, 1, 10e6), _noAuth());
    }

    function test_revert_mintERC20_feeOnTransfer() public {
        TestERC20 usdc = new TestERC20();
        _setERC20Stage(usdc, 10e6);
        usdc.setTransferFeeBps(100);
        usdc.mint(alice, 100e6);
        vm.prank(alice);
        usdc.approve(address(minter), 10e6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.ERC20AmountNotReceived.selector, 9.9e6, 10e6
            )
        );
        minter.mint(_erc20Params(usdc, 1, 10e6), _noAuth());
    }

    function test_mintERC20_blockedRecipientCreditedThenWithdraws() public {
        TestERC20 usdc = new TestERC20();
        _setERC20Stage(usdc, 10e6);
        usdc.mint(alice, 100e6);
        usdc.setBlocked(creator, true);
        vm.prank(alice);
        usdc.approve(address(minter), 10e6);

        uint256 proceeds = 10e6 * (10_000 - FEE_BPS) / 10_000;
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.PaymentCredited(creator, address(usdc), proceeds);
        vm.prank(alice);
        minter.mint(_erc20Params(usdc, 1, 10e6), _noAuth());

        assertEq(token721.ownerOf(1), alice);
        assertEq(minter.credited(creator, address(usdc)), proceeds);
        assertEq(usdc.balanceOf(address(minter)), proceeds);

        vm.prank(creator);
        minter.withdraw(address(usdc), carol);
        assertEq(usdc.balanceOf(carol), proceeds);
        assertEq(minter.credited(creator, address(usdc)), 0);
    }

    function test_mintERC20_shortTransferReturnIsRolledBackAndCredited()
        public
    {
        _assertBadERC20AnswerCredited(1);
    }

    function test_mintERC20_transferReturningTwoIsRolledBackAndCredited()
        public
    {
        _assertBadERC20AnswerCredited(2);
    }

    function test_mintERC20_gasBurningTransferIsRolledBackAndCredited() public {
        _assertBadERC20AnswerCredited(3);
    }

    /// @dev The creator's transfer moves the tokens, then answers with
    ///      `mode`'s bad response. The minter rolls the transfer back and
    ///      credits the creator, and the mint goes through.
    function _assertBadERC20AnswerCredited(uint8 mode) internal {
        TestERC20 usdc = new TestERC20();
        _setERC20Stage(usdc, 10e6);
        usdc.mint(alice, 100e6);
        usdc.setTransferMode(creator, mode);
        vm.prank(alice);
        usdc.approve(address(minter), 10e6);

        uint256 proceeds = 10e6 * (10_000 - FEE_BPS) / 10_000;
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.PaymentCredited(creator, address(usdc), proceeds);
        vm.prank(alice);
        minter.mint{ gas: 1_000_000 }(_erc20Params(usdc, 1, 10e6), _noAuth());

        assertEq(token721.ownerOf(1), alice);
        assertEq(usdc.balanceOf(creator), 0);
        assertEq(minter.credited(creator, address(usdc)), proceeds);
        assertEq(usdc.balanceOf(address(minter)), proceeds);
    }

    function test_revert_pushERC20_onlyMinterItself() public {
        TestERC20 usdc = new TestERC20();
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyMinterItself.selector, alice
            )
        );
        vm.prank(alice);
        minter.pushERC20(address(usdc), alice, 1);
    }

    // ---------------------------------------------------------------------
    // Failed ETH pushes and withdrawals
    // ---------------------------------------------------------------------

    function test_revertingRecipientCreditedThenWithdraws() public {
        RevertingRecipient recipient = new RevertingRecipient();
        _setSinglePayout(address(token721), address(recipient));
        uint256 proceeds = PRICE * (10_000 - FEE_BPS) / 10_000;

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.PaymentCredited(
            address(recipient),
            address(0),
            proceeds
        );
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );

        assertEq(token721.ownerOf(1), alice);
        assertEq(feeRecipient.balance, PRICE - proceeds);
        assertEq(minter.credited(address(recipient), address(0)), proceeds);
        assertEq(address(minter).balance, proceeds);

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.Withdrawal(
            address(recipient),
            address(0),
            carol,
            proceeds
        );
        recipient.withdrawFrom(minter, address(0), carol);

        assertEq(carol.balance, proceeds);
        assertEq(minter.credited(address(recipient), address(0)), 0);
        assertEq(address(minter).balance, 0);
    }

    function test_gasBurningRecipientIsCredited() public {
        GasBurningRecipient recipient = new GasBurningRecipient();
        _setSinglePayout(address(token721), address(recipient));

        vm.prank(alice);
        minter.mint{ value: PRICE, gas: 1_000_000 }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );

        assertEq(token721.ownerOf(1), alice);
        assertEq(
            minter.credited(address(recipient), address(0)),
            PRICE * (10_000 - FEE_BPS) / 10_000
        );
    }

    function test_payoutListChangedMidPayoutPaysTheSnapshot() public {
        // The owner of the token is also its first payout recipient, and
        // replaces the list with carol alone when it's paid
        PayoutListChanger changer = new PayoutListChanger(minter);
        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](2);
        recipients[0] = ISeaDropMinter.PayoutRecipient(address(changer), 5000);
        recipients[1] = ISeaDropMinter.PayoutRecipient(bob, 5000);
        minter.setPayoutRecipients(address(token721), recipients);
        token721.transferOwnership(address(changer));
        changer.acceptOwnershipOf(token721);
        changer.arm(address(token721), carol);

        uint256 bobBefore = bob.balance;
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );

        uint256 proceeds = PRICE * (10_000 - FEE_BPS) / 10_000;
        assertEq(token721.ownerOf(1), alice);
        assertEq(address(changer).balance, proceeds / 2);
        assertEq(bob.balance - bobBefore, proceeds - proceeds / 2);
        ISeaDropMinter.PayoutRecipient[] memory changed =
            minter.getPayoutRecipients(address(token721));
        assertEq(changed.length, 1);
        assertEq(changed[0].recipient, carol);
    }

    function test_revert_withdraw_nothingCredited() public {
        vm.prank(alice);
        vm.expectRevert(ISeaDropMinter.NothingToWithdraw.selector);
        minter.withdraw(address(0), alice);
    }

    function test_revert_withdraw_toRejectingAddress() public {
        RevertingRecipient recipient = new RevertingRecipient();
        _setSinglePayout(address(token721), address(recipient));
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );

        vm.expectRevert(ISeaDropMinter.WithdrawalFailed.selector);
        recipient.withdrawFrom(minter, address(0), address(recipient));
    }

    // ---------------------------------------------------------------------
    // Payout splits
    // ---------------------------------------------------------------------

    function test_payoutSplitsGiveRemainderToLast() public {
        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](3);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 3333);
        recipients[1] = ISeaDropMinter.PayoutRecipient(bob, 3333);
        recipients[2] = ISeaDropMinter.PayoutRecipient(carol, 3334);
        minter.setPayoutRecipients(address(token721), recipients);

        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.price = 101;
        stage.feeBps = 0;
        minter.setCurrency(
            address(0),
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: 0,
                feeRecipient: address(0)
            })
        );
        minter.setStage(address(token721), 0, 0, stage);

        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 1);
        params.maxTotalPrice = 101;
        uint256 bobBefore = bob.balance;
        vm.prank(alice);
        minter.mint{ value: 101 }(params, _noAuth());

        assertEq(creator.balance, 33);
        assertEq(bob.balance - bobBefore, 33);
        assertEq(carol.balance, 35);
    }

    function testFuzz_payoutSplitsPayEverything(
        uint16 firstBps,
        uint96 price,
        uint16 feeBps
    ) public {
        firstBps = uint16(bound(firstBps, 1, 9999));
        price = uint96(bound(price, 0, 10 ether));
        feeBps = uint16(bound(feeBps, FEE_BPS, 10_000));

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](2);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, firstBps);
        recipients[1] = ISeaDropMinter.PayoutRecipient(carol, 10_000 - firstBps);
        minter.setPayoutRecipients(address(token721), recipients);

        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.price = price;
        stage.feeBps = feeBps;
        minter.setStage(address(token721), 0, 0, stage);

        ISeaDropMinter.MintParams memory params =
            _params(address(token721), 0, alice, alice, 3);
        params.maxTotalPrice = uint256(price) * 3;
        vm.prank(alice);
        minter.mint{ value: uint256(price) * 3 }(params, _noAuth());

        assertEq(
            feeRecipient.balance + creator.balance + carol.balance,
            uint256(price) * 3
        );
        assertEq(address(minter).balance, 0);
    }

    // ---------------------------------------------------------------------
    // Owner mints
    // ---------------------------------------------------------------------

    function test_ownerMint() public {
        uint256 ownerMintStage = minter.OWNER_MINT_STAGE();
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SeaDropMint(
            address(token1155),
            ID_1155,
            ownerMintStage,
            address(this),
            address(this),
            carol,
            10,
            0,
            address(0),
            address(0),
            0
        );
        minter.ownerMint(address(token1155), ID_1155, carol, 10);
        minter.ownerMint(address(token721), 0, carol, 3);

        assertEq(token1155.balanceOf(carol, ID_1155), 10);
        assertEq(token721.balanceOf(carol), 3);
    }

    function test_ownerMint_ignoresStagesAndWalletLimits() public {
        ISeaDropMinter.Stage memory cleared;
        minter.setStage(address(token721), 0, 0, cleared);

        minter.ownerMint(address(token721), 0, carol, MAX_PER_WALLET + 1);
        assertEq(token721.balanceOf(carol), MAX_PER_WALLET + 1);
    }

    function test_revert_ownerMint_maxSupply() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.MintQuantityExceedsMaxSupply.selector,
                MAX_SUPPLY + 1,
                MAX_SUPPLY
            )
        );
        minter.ownerMint(address(token1155), ID_1155, carol, MAX_SUPPLY + 1);
    }

    function test_revert_ownerMint_notOwner() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenOwner.selector, address(token721), alice
            )
        );
        minter.ownerMint(address(token721), 0, alice, 1);
    }

    // ---------------------------------------------------------------------
    // Token-owner configuration
    // ---------------------------------------------------------------------

    function test_setStage_emitsVersionedEvent() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.price = 1;

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.StageUpdated(1, address(token721), 0, 3, stage);
        minter.setStage(address(token721), 0, 3, stage);

        ISeaDropMinter.Stage memory stored =
            minter.getStage(address(token721), 0, 3);
        assertEq(stored.price, 1);
        assertEq(stored.feeRecipient, feeRecipient);
    }

    function test_revert_config_notTokenOwner() public {
        bytes memory onlyOwner = abi.encodeWithSelector(
            ISeaDropMinter.OnlyTokenOwner.selector, address(token721), alice
        );

        vm.startPrank(alice);
        vm.expectRevert(onlyOwner);
        minter.setStage(address(token721), 0, 0, _publicStage());

        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](1);
        recipients[0] = ISeaDropMinter.PayoutRecipient(alice, 10_000);
        vm.expectRevert(onlyOwner);
        minter.setPayoutRecipients(address(token721), recipients);

        vm.expectRevert(onlyOwner);
        minter.setAllowedPayer(address(token721), alice, true);
        vm.stopPrank();
    }

    function test_config_followsTokenOwnership() public {
        token721.transferOwnership(alice);
        vm.prank(alice);
        token721.acceptOwnership();

        vm.prank(alice);
        minter.setStage(address(token721), 0, 1, _publicStage());

        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.OnlyTokenOwner.selector,
                address(token721),
                address(this)
            )
        );
        minter.setStage(address(token721), 0, 1, _publicStage());
    }

    function test_revert_setPayoutRecipients_invalid() public {
        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](0);
        vm.expectRevert(ISeaDropMinter.NoPayoutRecipients.selector);
        minter.setPayoutRecipients(address(token721), recipients);

        recipients = new ISeaDropMinter.PayoutRecipient[](11);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.TooManyPayoutRecipients.selector, 11
            )
        );
        minter.setPayoutRecipients(address(token721), recipients);

        recipients = new ISeaDropMinter.PayoutRecipient[](2);
        recipients[0] = ISeaDropMinter.PayoutRecipient(creator, 5000);
        recipients[1] = ISeaDropMinter.PayoutRecipient(address(0), 5000);
        vm.expectRevert(ISeaDropMinter.PayoutRecipientIsZeroAddress.selector);
        minter.setPayoutRecipients(address(token721), recipients);

        recipients[1] = ISeaDropMinter.PayoutRecipient(bob, 0);
        vm.expectRevert(ISeaDropMinter.PayoutBpsIsZero.selector);
        minter.setPayoutRecipients(address(token721), recipients);

        recipients[1] = ISeaDropMinter.PayoutRecipient(bob, 4999);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.PayoutBpsTotalNot10000.selector, 9999
            )
        );
        minter.setPayoutRecipients(address(token721), recipients);
    }

    function test_setPayoutRecipients_replacesTheList() public {
        ISeaDropMinter.PayoutRecipient[] memory recipients =
            new ISeaDropMinter.PayoutRecipient[](2);
        recipients[0] = ISeaDropMinter.PayoutRecipient(bob, 4000);
        recipients[1] = ISeaDropMinter.PayoutRecipient(carol, 6000);
        minter.setPayoutRecipients(address(token721), recipients);

        ISeaDropMinter.PayoutRecipient[] memory stored =
            minter.getPayoutRecipients(address(token721));
        assertEq(stored.length, 2);
        assertEq(stored[0].recipient, bob);
        assertEq(stored[1].bps, 6000);
    }

    function test_revert_setStage_endsBeforeStart() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.endTime = stage.startTime - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.StageEndsBeforeStart.selector,
                stage.startTime,
                stage.endTime
            )
        );
        minter.setStage(address(token721), 0, 0, stage);
    }

    // ---------------------------------------------------------------------
    // Protocol fee and currencies, set by the minter's admin
    // ---------------------------------------------------------------------

    function test_revert_setStage_currencyNotAllowed() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.currency = address(new TestERC20());
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.CurrencyNotAllowed.selector, stage.currency
            )
        );
        minter.setStage(address(token721), 0, 0, stage);
    }

    function test_revert_setStage_feeBelowMinimum() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.feeBps = uint16(FEE_BPS - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.FeeBelowMinimum.selector, FEE_BPS - 1, FEE_BPS
            )
        );
        minter.setStage(address(token721), 0, 0, stage);
    }

    function test_revert_setStage_feeRecipientNotRequired() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.feeRecipient = bob;
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.FeeRecipientNotRequired.selector,
                bob,
                feeRecipient
            )
        );
        minter.setStage(address(token721), 0, 0, stage);
    }

    function test_revert_setStage_feeAboveBps() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.feeBps = 10_001;
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.FeeBpsTooHigh.selector, 10_001
            )
        );
        minter.setStage(address(token721), 0, 0, stage);
    }

    function test_setStage_higherFeeAllowed() public {
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.feeBps = 250;
        minter.setStage(address(token721), 0, 0, stage);
        assertEq(minter.getStage(address(token721), 0, 0).feeBps, 250);
    }

    function test_setStage_clearingSkipsFeeChecks() public {
        ISeaDropMinter.Stage memory cleared;
        minter.setStage(address(token721), 0, 0, cleared);
        assertEq(minter.getStage(address(token721), 0, 0).endTime, 0);
    }

    function test_revert_mint_currencyDisabledAfterSetStage() public {
        minter.setCurrency(
            address(0),
            ISeaDropMinter.CurrencyConfig({
                allowed: false,
                minFeeBps: uint16(FEE_BPS),
                feeRecipient: feeRecipient
            })
        );

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.CurrencyNotAllowed.selector, address(0)
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );

        // Owner mints take no payment, so they still work.
        minter.ownerMint(address(token721), 0, carol, 1);
        assertEq(token721.ownerOf(1), carol);
    }

    function test_revert_mintERC20_currencyDisabledAfterSetStage() public {
        TestERC20 usdc = new TestERC20();
        _setERC20Stage(usdc, 10e6);
        minter.setCurrency(
            address(usdc),
            ISeaDropMinter.CurrencyConfig({
                allowed: false,
                minFeeBps: 0,
                feeRecipient: address(0)
            })
        );
        usdc.mint(alice, 10e6);
        vm.prank(alice);
        usdc.approve(address(minter), 10e6);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.CurrencyNotAllowed.selector, address(usdc)
            )
        );
        minter.mint(_erc20Params(usdc, 1, 10e6), _noAuth());
    }

    function test_revert_mint_minFeeRaisedAfterSetStage() public {
        minter.setCurrency(
            address(0),
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: 200,
                feeRecipient: feeRecipient
            })
        );

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.FeeBelowMinimum.selector, FEE_BPS, 200
            )
        );
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );

        // Mints resume once the creator raises the stage's fee to match.
        ISeaDropMinter.Stage memory stage = _publicStage();
        stage.feeBps = 200;
        minter.setStage(address(token721), 0, 0, stage);
        vm.prank(alice);
        minter.mint{ value: PRICE }(
            _params(address(token721), 0, alice, alice, 1), _noAuth()
        );
        assertEq(feeRecipient.balance, PRICE * 200 / 10_000);
    }

    function test_revert_mintSigned_authorizationForOtherCurrency() public {
        TestERC20 usdc = new TestERC20();
        _setERC20Stage(usdc, 20e6);
        ISeaDropMinter.Stage memory stage =
            minter.getStage(address(token721), 0, 0);
        stage.signer = signer;
        minter.setStage(address(token721), 0, 0, stage);

        // The signer prices alice's allocation at 10 USDC.
        ISeaDropMinter.MintParams memory params = _erc20Params(usdc, 1, 10e6);
        ISeaDropMinter.Authorization memory auth =
            _authorize(params, signer, signerKey, 0, true, 10e6);
        assertEq(auth.currency, address(usdc));
        usdc.mint(alice, 10e6);
        vm.prank(alice);
        usdc.approve(address(minter), 10e6);
        vm.prank(alice);
        minter.mint(params, auth);

        // The owner switches the stage to ETH. Without the currency in the
        // authorization, its override would now charge 10,000,000 wei.
        stage.currency = address(0);
        stage.price = uint96(PRICE);
        minter.setStage(address(token721), 0, 0, stage);

        params.currency = address(0);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropMinter.AuthorizationCurrencyMismatch.selector,
                address(0),
                address(usdc)
            )
        );
        minter.mint{ value: 10e6 }(params, auth);

        // Claiming the authorization was for ETH breaks the signature.
        auth.currency = address(0);
        vm.prank(alice);
        vm.expectRevert(ISeaDropMinter.InvalidSignature.selector);
        minter.mint{ value: 10e6 }(params, auth);
    }

    function test_revert_adminConfig_notAdmin() public {
        vm.startPrank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        minter.setCurrency(
            address(0),
            ISeaDropMinter.CurrencyConfig({
                allowed: true,
                minFeeBps: 0,
                feeRecipient: address(0)
            })
        );
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        minter.setSignerSetMember(1, alice, true);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        minter.setTrustedPayer(alice, true);
        vm.stopPrank();
    }

    function test_revert_setSignerSetMember_zeroId() public {
        vm.expectRevert(ISeaDropMinter.SignerSetIdIsZero.selector);
        minter.setSignerSetMember(0, signer, true);
    }

    function test_adminConfig_emitsVersionedEvents() public {
        vm.expectEmit(address(minter));
        emit ISeaDropMinter.SignerSetUpdated(1, 2, signer, true);
        minter.setSignerSetMember(2, signer, true);

        vm.expectEmit(address(minter));
        emit ISeaDropMinter.TrustedPayerUpdated(1, bob, true);
        minter.setTrustedPayer(bob, true);

        assertTrue(minter.signerSets(2, signer));
        assertTrue(minter.trustedPayers(bob));
    }

    function test_renounceCancelsPendingAdmin() public {
        minter.transferOwnership(alice);
        minter.renounceOwnership();

        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.NotNextOwner.selector);
        minter.acceptOwnership();
        assertEq(minter.owner(), address(0));
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
