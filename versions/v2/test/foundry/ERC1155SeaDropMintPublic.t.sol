// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

import {
    TokenTransferrerErrors
} from "seaport-types/src/interfaces/TokenTransferrerErrors.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

/**
 * @dev Public drop (SIP-12 substandard 0) mints. Failed mints assert the
 *      SeaDrop error from both previewOrder and the Seaport fulfillment.
 */
contract ERC1155SeaDropMintPublicTest is SeaDrop1155Test {
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
        token = _deployToken();
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
        _seaDrop().updatePublicDrop(publicDrop, 0);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
    }

    function _order(uint256 quantity)
        internal
        view
        returns (AdvancedOrder memory, uint256)
    {
        return _publicMintOrder(
            address(token),
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

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );
        address[] memory payers = _seaDrop().getPayers();
        assertEq(payers.length, 0);

        // Allow the payer.
        _seaDrop().updatePayer(payer, true);
        payers = _seaDrop().getPayers();
        assertEq(payers.length, 1);
        assertEq(payers[0], payer);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, 0);
        _fulfill(order, payer, value);

        assertEq(token.balanceOf(minter, 0), quantity);
        assertEq(token.totalSupply(0), quantity);

        // Mint public with minter being payer.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 0), quantity * 2);
        assertEq(token.totalSupply(0), quantity * 2);
    }

    function testCannotMintPublicStageBeforeStart() public {
        // Set start time in the future.
        PublicDrop memory drop = publicDrop;
        drop.startTime = uint40(block.timestamp + 100);
        _seaDrop().updatePublicDrop(drop, 0);

        // Mint public with payer for minter.
        (AdvancedOrder memory order, uint256 value) = _order(3);
        bytes memory notActive = abi.encodeWithSelector(
            NotActive.selector, block.timestamp, drop.startTime, drop.endTime
        );
        _assertMintReverts(order, payer, value, notActive);

        // Mint public with minter being payer.
        _assertMintReverts(order, minter, value, notActive);
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
        _seaDrop().updatePublicDrop(drop, 0);

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
        _seaDrop().updatePublicDrop(drop, 0);

        // Set end time in the past.
        drop = publicDrop;
        drop.endTime = uint40(block.timestamp - 1000);
        _seaDrop().updatePublicDrop(drop, 0);

        // Mint public with payer for minter.
        (AdvancedOrder memory order, uint256 value) = _order(3);
        bytes memory notActive = abi.encodeWithSelector(
            NotActive.selector, block.timestamp, drop.startTime, drop.endTime
        );
        _assertMintReverts(order, payer, value, notActive);

        // Mint public with minter being payer.
        _assertMintReverts(order, minter, value, notActive);
    }

    function testMaxMintsPerWalletAndMaxSupply() public {
        // Set max limit per wallet to 2 and per token to 1.
        PublicDrop memory drop = publicDrop;
        drop.maxTotalMintableByWallet = 2;
        drop.maxTotalMintableByWalletPerToken = 1;
        _seaDrop().updatePublicDrop(drop, 0);

        // Update max supply to 1.
        token.setMaxSupply(0, 1);

        // Mint one.
        (AdvancedOrder memory order, uint256 value) = _order(1);
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        // Minting the next should fail: the per-token wallet limit (1) is
        // checked before the max supply.
        bytes memory perTokenLimit = abi.encodeWithSelector(
            ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                .selector,
            0,
            2,
            1
        );
        _assertMintReverts(order, minter, value, perTokenLimit);

        // Update max supply to 3.
        token.setMaxSupply(0, 3);

        // Minting the next should throw
        // MintQuantityExceedsMaxMintedPerWalletForTokenId.
        _assertMintReverts(order, minter, value, perTokenLimit);

        // Update per token limit to 3.
        drop.maxTotalMintableByWalletPerToken = 3;
        _seaDrop().updatePublicDrop(drop, 0);

        // Mint one.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        // Minting the next should throw MintQuantityExceedsMaxMintedPerWallet.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 3, 2
            )
        );
    }

    function testCannotMintWithIncorrectPayment() public {
        // Pay for only 1 mint, but request quantity of 2.
        (AdvancedOrder memory order, uint256 value) = _order(2);
        value = value / 2;

        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientNativeTokensSupplied
            .selector
        );
        _fulfill(order, minter, value);

        // Pay for 3 mints but request quantity of 2.
        (order, value) = _order(2);
        value = (value * 2) / 3;

        vm.expectRevert(
            ConsiderationEventsAndErrors.InsufficientNativeTokensSupplied
            .selector
        );
        _fulfill(order, minter, value);
    }

    function testCannotMintWithInvalidFeeRecipient() public {
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            0,
            1,
            address(0),
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(FeeRecipientCannotBeZeroAddress.selector)
        );

        // A fee recipient that isn't allowed while fee recipients are
        // restricted.
        (order, value) = _publicMintOrder(
            address(token),
            0,
            1,
            creator,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(FeeRecipientNotAllowed.selector, creator)
        );

        // Without the public drop index byte the context is 42 bytes, one
        // short of the 1155 minimum.
        MintOrder memory m = _publicMint(
            address(token),
            _uints(0),
            _uints(1),
            creator,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );
        m.mintTypeData = "";
        (order, value) = _createMintOrder(m);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );
    }

    function testCannotSetInvalidFeeBps() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 15_000;
        vm.expectRevert(abi.encodeWithSelector(InvalidFeeBps.selector, 15_000));
        _seaDrop().updatePublicDrop(drop, 0);
    }

    function testMintWhenFeeBpsIsZero() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 0;
        _seaDrop().updatePublicDrop(drop, 3);

        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            0,
            1,
            feeRecipient,
            0,
            publicDrop.startPrice,
            minter,
            3
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 3);
        _fulfill(order, minter, value);
    }

    function testCannotMintZeroQuantityWithUnknownFeeRecipient() public {
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            0,
            0,
            creator,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );

        // A zero quantity passes the 1155 token's checks, so the order fails
        // on the fee recipient (creator) not being allowed.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(FeeRecipientNotAllowed.selector, creator)
        );
    }

    function testDelegatedPayerCanMint() public {
        _seaDrop().updateCreatorPayouts(_payouts(creator, 5_000, owner, 5_000));

        (AdvancedOrder memory order, uint256 value) = _order(1);

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );

        // Delegate payer for minter.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, true);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(payer, 0);
        _fulfill(order, payer, value);
    }

    function testCannotMintZeroQuantity() public {
        (AdvancedOrder memory order, uint256 value) = _order(0);

        vm.expectRevert(TokenTransferrerErrors.MissingItemAmount.selector);
        _fulfill(order, minter, value);
    }

    function testPreviewOrderReturnsExpectedOfferAndConsideration() public {
        (AdvancedOrder memory order,) = _publicMintOrder(
            address(token),
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.endPrice,
            minter,
            0
        );

        _assertPreviewOrderMatches(order, minter);
    }
}
