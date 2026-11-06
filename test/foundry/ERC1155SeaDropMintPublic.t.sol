// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155MintHelpers } from "./utils/SeaDrop1155MintHelpers.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import {
    IDelegationRegistry
} from "seadrop/interfaces/IDelegationRegistry.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    TokenTransferrerErrors
} from "seaport-types/src/interfaces/TokenTransferrerErrors.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Port of test/ERC1155SeaDrop-mintPublic.spec.ts.
 *
 *      Where the spec only asserts Seaport's InvalidContractOrder and names
 *      the token's inner error in a comment, the port also asserts the inner
 *      error through previewOrder. Where the comment names the wrong inner
 *      error, the port asserts the actual one and says so.
 */
contract ERC1155SeaDropMintPublicTest is SeaDrop1155MintHelpers {
    IERC1155SeaDrop seadropToken;
    PublicDrop publicDrop;

    address owner;
    address creator;
    address payer;
    address minter;
    address feeRecipient;

    function setUp() public override {
        super.setUp();

        owner = address(this);
        creator = makeAddr("creator");
        payer = makeAddr("payer");
        minter = makeAddr("minter");
        feeRecipient = makeAddr("feeRecipient");
        vm.deal(owner, 100 ether);
        vm.deal(payer, 100 ether);
        vm.deal(minter, 100 ether);

        // Deploy and configure the token.
        token = _deployERC1155SeaDrop();
        seadropToken = IERC1155SeaDrop(address(token));
        token.setMaxSupply(0, 100);
        _setSingleCreatorPayout(address(token), creator);
        publicDrop = PublicDrop({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: uint40(block.timestamp - 1000),
            endTime: uint40(block.timestamp + 1000),
            paymentToken: address(0),
            fromTokenId: 0,
            toTokenId: 3,
            maxTotalMintableByWallet: 10,
            maxTotalMintableByWalletPerToken: 9,
            feeBps: 1000,
            restrictFeeRecipients: true
        });
        seadropToken.updatePublicDrop(publicDrop, 0);
        seadropToken.updateAllowedFeeRecipient(feeRecipient, true);
    }

    function _order(uint256 quantity)
        internal
        view
        returns (AdvancedOrder memory, uint256)
    {
        return _publicMintOrder(
            0,
            quantity,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );
    }

    function testMintPublicStage() public {
        // Mint public with payer as minter.
        uint256 quantity = 3;
        (AdvancedOrder memory order, uint256 value) = _order(quantity);

        _expectPreviewRevert(
            payer,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );
        _fulfillExpectingInvalidContractOrder(payer, order, value);
        address[] memory payers = seadropToken.getPayers();
        assertEq(payers.length, 0);

        // Allow the payer.
        seadropToken.updatePayer(payer, true);
        payers = seadropToken.getPayers();
        assertEq(payers.length, 1);
        assertEq(payers[0], payer);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, 0);
        _fulfill(payer, order, value);

        assertEq(token.balanceOf(minter, 0), quantity);
        assertEq(token.totalSupply(0), quantity);

        // Mint public with minter being payer.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(minter, order, value);

        assertEq(token.balanceOf(minter, 0), quantity * 2);
        assertEq(token.totalSupply(0), quantity * 2);
    }

    function testCannotMintPublicStageBeforeStart() public {
        // Set start time in the future.
        PublicDrop memory drop = publicDrop;
        drop.startTime = uint40(block.timestamp + 100);
        seadropToken.updatePublicDrop(drop, 0);

        // Mint public with payer for minter.
        (AdvancedOrder memory order, uint256 value) = _order(3);
        bytes memory notActive = abi.encodeWithSelector(
            NotActive.selector, block.timestamp, drop.startTime, drop.endTime
        );
        _expectPreviewRevert(payer, order, notActive);
        _fulfillExpectingInvalidContractOrder(payer, order, value);

        // Mint public with minter being payer.
        _expectPreviewRevert(minter, order, notActive);
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintPublicStageAfterEnd() public {
        // Should not allow startTime > endTime.
        PublicDrop memory drop = publicDrop;
        drop.endTime = 100;
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidStartAndEndTime.selector, publicDrop.startTime, 100
            )
        );
        seadropToken.updatePublicDrop(drop, 0);

        // Should not allow fromTokenId > toTokenId.
        drop = publicDrop;
        drop.fromTokenId = 10;
        drop.toTokenId = 9;
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.InvalidFromAndToTokenId.selector,
                10,
                9
            )
        );
        seadropToken.updatePublicDrop(drop, 0);

        // Set end time in the past.
        drop = publicDrop;
        drop.endTime = uint40(block.timestamp - 1000);
        seadropToken.updatePublicDrop(drop, 0);

        // Mint public with payer for minter.
        (AdvancedOrder memory order, uint256 value) = _order(3);
        bytes memory notActive = abi.encodeWithSelector(
            NotActive.selector, block.timestamp, drop.startTime, drop.endTime
        );
        _expectPreviewRevert(payer, order, notActive);
        _fulfillExpectingInvalidContractOrder(payer, order, value);

        // Mint public with minter being payer.
        _expectPreviewRevert(minter, order, notActive);
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testMaxMintsPerWalletAndMaxSupply() public {
        // Set max limit per wallet to 2 and per token to 1.
        PublicDrop memory drop = publicDrop;
        drop.maxTotalMintableByWallet = 2;
        drop.maxTotalMintableByWalletPerToken = 1;
        seadropToken.updatePublicDrop(drop, 0);

        // Update max supply to 1.
        token.setMaxSupply(0, 1);

        // Mint one.
        (AdvancedOrder memory order, uint256 value) = _order(1);
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(minter, order, value);

        // Minting the next should fail.
        // NOTE: the spec comment names MintQuantityExceedsMaxSupply, but the
        // per-token wallet limit (1) is checked first and fires instead.
        bytes memory perTokenLimit = abi.encodeWithSelector(
            ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                .selector,
            0,
            2,
            1
        );
        _expectPreviewRevert(minter, order, perTokenLimit);
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Update max supply to 3.
        token.setMaxSupply(0, 3);

        // Minting the next should throw
        // MintQuantityExceedsMaxMintedPerWalletForTokenId.
        _expectPreviewRevert(minter, order, perTokenLimit);
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // Update per token limit to 3.
        drop.maxTotalMintableByWalletPerToken = 3;
        seadropToken.updatePublicDrop(drop, 0);

        // Mint one.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(minter, order, value);

        // Minting the next should throw MintQuantityExceedsMaxMintedPerWallet.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 3, 2
            )
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotMintWithIncorrectPayment() public {
        // Pay for only 1 mint, but request quantity of 2.
        (AdvancedOrder memory order, uint256 value) = _order(2);
        value = value / 2;

        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientNativeTokensSupplied
            .selector
        );
        _fulfill(minter, order, value);

        // Pay for 3 mints but request quantity of 2.
        (order, value) = _order(2);
        value = (value * 2) / 3;

        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientNativeTokensSupplied
            .selector
        );
        _fulfill(minter, order, value);
    }

    function testCannotMintWithInvalidFeeRecipient() public {
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            0,
            1,
            address(0),
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );

        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(FeeRecipientCannotBeZeroAddress.selector)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);

        // The spec builds this order without a publicDropIndex, so the
        // context is 42 bytes.
        (order, value) = _createMintOrder(
            MintOrderArgs({
                token: address(token),
                tokenIds: _single(0),
                quantities: _single(1),
                feeRecipient: creator,
                feeBps: publicDrop.feeBps,
                price: publicDrop.startPrice,
                minter: minter,
                mintType: MINT_TYPE_PUBLIC,
                mintTypeData: ""
            })
        );

        // NOTE: the spec comment names FeeRecipientNotAllowed, but the
        // missing publicDropIndex byte makes the context too short, so the
        // token rejects it as InvalidExtraDataEncoding(0) first.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testCannotSetInvalidFeeBps() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 15_000;
        vm.expectRevert(abi.encodeWithSelector(InvalidFeeBps.selector, 15_000));
        seadropToken.updatePublicDrop(drop, 0);
    }

    function testMintWhenFeeBpsIsZero() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 0;
        seadropToken.updatePublicDrop(drop, 3);

        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            0, 1, feeRecipient, 0, publicDrop.startPrice, minter, 3
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 3);
        _fulfill(minter, order, value);
    }

    function testCannotMintZeroQuantityWithUnknownFeeRecipient() public {
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            0, 0, creator, publicDrop.feeBps, publicDrop.startPrice, minter, 0
        );

        // NOTE: the spec comment names MintQuantityCannotBeZero, which does
        // not exist in v2. A zero quantity passes the token's checks and the
        // order fails on the fee recipient (creator) not being allowed.
        _expectPreviewRevert(
            minter,
            order,
            abi.encodeWithSelector(FeeRecipientNotAllowed.selector, creator)
        );
        _fulfillExpectingInvalidContractOrder(minter, order, value);
    }

    function testDelegatedPayerCanMint() public {
        _setTwoCreatorPayouts(creator, owner);

        (AdvancedOrder memory order, uint256 value) = _order(1);

        _expectPreviewRevert(
            payer,
            order,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );
        _fulfillExpectingInvalidContractOrder(payer, order, value);

        // Delegate payer for minter.
        vm.prank(minter);
        IDelegationRegistry(DELEGATION_REGISTRY).delegateForAll(payer, true);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, 0);
        _fulfill(payer, order, value);
    }

    function testCannotMintZeroQuantity() public {
        (AdvancedOrder memory order, uint256 value) = _order(0);

        vm.expectRevert(TokenTransferrerErrors.MissingItemAmount.selector);
        _fulfill(minter, order, value);
    }

    function testPreviewOrderReturnsExpectedOfferAndConsideration() public {
        (AdvancedOrder memory order,) = _publicMintOrder(
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.endPrice,
            minter,
            0
        );

        _assertPreviewOrderMatches(minter, order);
    }
}
