// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721MintHelpers } from "./utils/SeaDrop721MintHelpers.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ConsiderationEventsAndErrors
} from "seaport-types/src/interfaces/ConsiderationEventsAndErrors.sol";

/**
 * @dev Port of test/ERC721SeaDrop-mintPublic.spec.ts.
 *      The test contract deploys the token, so it plays the spec's `owner`.
 *      Where the spec can only see Seaport's InvalidContractOrder, the inner
 *      SeaDrop error is also asserted through previewOrder (see
 *      _assertMintReverts). Where it differs from the error named in the
 *      spec's comment, the test says why.
 */
contract ERC721SeaDropMintPublicTest is SeaDrop721MintHelpers {
    uint256 constant _PUBLIC_DROP_STAGE_INDEX = 0;

    address creator = makeAddr("creator");
    address payer = makeAddr("payer");
    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");

    PublicDrop publicDrop;

    function setUp() public override {
        super.setUp();

        token = new ERC721SeaDrop(
            address(configurer),
            allowedSeaport,
            "Test721",
            "T721"
        );

        vm.deal(payer, 100 ether);
        vm.deal(minter, 100 ether);

        // Configure the token.
        token.setMaxSupply(100);
        setSingleCreatorPayout(creator);
        publicDrop = PublicDrop({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: uint40(block.timestamp - 1000),
            endTime: uint40(block.timestamp + 1000),
            paymentToken: address(0),
            maxTotalMintableByWallet: 10,
            feeBps: 1000,
            restrictFeeRecipients: true
        });
        IERC721SeaDrop(address(token)).updatePublicDrop(publicDrop);
        IERC721SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
    }

    function _order(
        uint256 quantity,
        address orderFeeRecipient
    ) internal view returns (AdvancedOrder memory, uint256) {
        return
            _publicOrder(
                address(token),
                quantity,
                orderFeeRecipient,
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter
            );
    }

    /// @dev "Should mint a public stage"
    function testMintPublicStage() public {
        // Mint public with payer as minter.
        uint256 quantity = 3;
        (AdvancedOrder memory order, uint256 value) = _order(
            quantity,
            feeRecipient
        );

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );
        address[] memory payers = IERC721SeaDrop(address(token)).getPayers();
        assertEq(payers.length, 0);

        // Allow the payer.
        IERC721SeaDrop(address(token)).updatePayer(payer, true);
        payers = IERC721SeaDrop(address(token)).getPayers();
        assertEq(payers.length, 1);
        assertEq(payers[0], payer);

        _fulfillAndExpectMint(order, payer, value, _PUBLIC_DROP_STAGE_INDEX);

        assertEq(token.balanceOf(minter), quantity);
        assertEq(token.totalSupply(), quantity);

        // Mint public with minter being payer.
        _fulfillAndExpectMint(order, minter, value, _PUBLIC_DROP_STAGE_INDEX);

        assertEq(token.balanceOf(minter), quantity * 2);
        assertEq(token.totalSupply(), quantity * 2);
    }

    /// @dev "Should not mint a public stage that hasn't started"
    function testCannotMintPublicStageNotStarted() public {
        // Set start time in the future.
        PublicDrop memory drop = publicDrop;
        drop.startTime = uint40(block.timestamp + 100);
        IERC721SeaDrop(address(token)).updatePublicDrop(drop);

        // Mint public with payer for minter.
        (AdvancedOrder memory order, uint256 value) = _order(3, feeRecipient);
        bytes memory notActive = abi.encodeWithSelector(
            NotActive.selector,
            block.timestamp,
            drop.startTime,
            drop.endTime
        );
        _assertMintReverts(order, payer, value, notActive);

        // Mint public with minter being payer.
        _assertMintReverts(order, minter, value, notActive);
    }

    /// @dev "Should not mint a public stage that has ended"
    function testCannotMintPublicStageEnded() public {
        // Should not allow startTime > endTime.
        PublicDrop memory drop = publicDrop;
        drop.endTime = 100;
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidStartAndEndTime.selector,
                publicDrop.startTime,
                100
            )
        );
        IERC721SeaDrop(address(token)).updatePublicDrop(drop);

        // Set end time in the past.
        drop.endTime = uint40(block.timestamp - 1000);
        IERC721SeaDrop(address(token)).updatePublicDrop(drop);

        // Mint public with payer for minter.
        (AdvancedOrder memory order, uint256 value) = _order(3, feeRecipient);
        bytes memory notActive = abi.encodeWithSelector(
            NotActive.selector,
            block.timestamp,
            drop.startTime,
            drop.endTime
        );
        _assertMintReverts(order, payer, value, notActive);

        // Mint public with minter being payer.
        _assertMintReverts(order, minter, value, notActive);
    }

    /// @dev "Should respect limit for max mints per wallet and max supply"
    function testMaxMintsPerWalletAndMaxSupply() public {
        // Set max limit per wallet to 2.
        PublicDrop memory drop = publicDrop;
        drop.maxTotalMintableByWallet = 2;
        IERC721SeaDrop(address(token)).updatePublicDrop(drop);

        // Update max supply to 1.
        token.setMaxSupply(1);

        // Mint one.
        (AdvancedOrder memory order, uint256 value) = _order(1, feeRecipient);
        _fulfillAndExpectMint(order, minter, value, _PUBLIC_DROP_STAGE_INDEX);

        // Minting the next should throw MintQuantityExceedsMaxSupply.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );

        // Update max supply to 3.
        token.setMaxSupply(3);

        // Mint one.
        _fulfillAndExpectMint(order, minter, value, _PUBLIC_DROP_STAGE_INDEX);

        // Minting the next should throw MintQuantityExceedsMaxMintedPerWallet.
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector,
                3,
                2
            )
        );
    }

    /// @dev "Should not mint with incorrect payment"
    function testCannotMintWithIncorrectPayment() public {
        // Pay for only 1 mint, but request quantity of 2.
        (AdvancedOrder memory order, uint256 value) = _order(2, feeRecipient);
        value = value / 2;

        vm.expectRevert(
            ConsiderationEventsAndErrors
                .InsufficientNativeTokensSupplied
                .selector
        );
        _fulfill(order, minter, value);

        // Pay for 2/3 of 2 mints (the spec's comment says "Pay for 3 mints
        // but request quantity of 2", but its value is value * 2 / 3).
        (order, value) = _order(2, feeRecipient);
        value = (value * 2) / 3;

        vm.expectRevert(
            ConsiderationEventsAndErrors
                .InsufficientNativeTokensSupplied
                .selector
        );
        _fulfill(order, minter, value);
    }

    /// @dev "Should not mint with invalid fee recipient"
    function testCannotMintWithInvalidFeeRecipient() public {
        (AdvancedOrder memory order, uint256 value) = _order(1, address(0));
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(FeeRecipientCannotBeZeroAddress.selector)
        );

        (order, value) = _order(1, creator);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(FeeRecipientNotAllowed.selector, creator)
        );
    }

    /// @dev "Should not be able to set an invalid fee bps"
    function testCannotSetInvalidFeeBps() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 15_000;
        vm.expectRevert(
            abi.encodeWithSelector(InvalidFeeBps.selector, 15_000)
        );
        IERC721SeaDrop(address(token)).updatePublicDrop(drop);
    }

    /// @dev "Should mint when feeBps is zero"
    function testMintWhenFeeBpsIsZero() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 0;
        IERC721SeaDrop(address(token)).updatePublicDrop(drop);

        (AdvancedOrder memory order, uint256 value) = _publicOrder(
            address(token),
            1,
            feeRecipient,
            0,
            publicDrop.startPrice,
            minter
        );

        _fulfillAndExpectMint(order, minter, value, _PUBLIC_DROP_STAGE_INDEX);
    }

    /**
     * @dev The inner error for a zero quantity mint.
     *
     *      CONTRACT BUG (asserting current behavior): _decodeOrder flags a
     *      bad minimumReceived (here amount == 0) in bit 0 of its error
     *      buffer, but `errorBuffer << 254 != 0` tests bits 0 and 1, so it
     *      reverts with UnsupportedExtraDataVersion(0) instead of
     *      MustSpecifyERC1155ConsiderationItemForSeaDropMint, which is
     *      unreachable (as is InvalidSubstandard, shadowed by the `<< 252`
     *      branch). The spec only sees InvalidContractOrder.
     */
    function _zeroQuantityError() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 0);
    }

    /// @dev "Should not be able to mint zero quantity"
    function testCannotMintZeroQuantity() public {
        (AdvancedOrder memory order, uint256 value) = _order(0, creator);

        _assertMintReverts(
            order,
            minter,
            value,
            _zeroQuantityError()
        );
    }

    /// @dev "Should allow delegated payers to mint via the DelegationRegistry"
    function testDelegatedPayerCanMint() public {
        _setCreatorPayouts(address(token), creator, 5_000, address(this), 5_000);

        (AdvancedOrder memory order, uint256 value) = _order(1, feeRecipient);

        _assertMintReverts(
            order,
            payer,
            value,
            abi.encodeWithSelector(PayerNotAllowed.selector, payer)
        );

        // Delegate payer for minter.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, true);

        _fulfillAndExpectMint(order, payer, value, _PUBLIC_DROP_STAGE_INDEX);
    }

    /// @dev "Should not allow a mint quantity of zero"
    function testCannotMintQuantityOfZero() public {
        (AdvancedOrder memory order, uint256 value) = _order(0, feeRecipient);

        _assertMintReverts(
            order,
            minter,
            value,
            _zeroQuantityError()
        );
    }

    /// @dev "Should return the expected offer and consideration in
    ///      previewOrder"
    function testPreviewOrder() public {
        (AdvancedOrder memory order, ) = _publicOrder(
            address(token),
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.endPrice,
            minter
        );

        _assertPreviewOrderEchoesOrder(order, minter);
    }
}
