// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155OffererFixture } from "./utils/SeaDrop1155Test.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import { MaliciousRecipient } from "seadrop/test/MaliciousRecipient.sol";

import { TestERC20 } from "../../lib/seaport/contracts/test/TestERC20.sol";

import {
    ReentrancyErrors
} from "seaport-types/src/interfaces/ReentrancyErrors.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    OfferItem,
    Order,
    OrderComponents,
    OrderParameters
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

/**
 * @dev Mints through Seaport with the token as the contract offerer. The
 *      admin cases are in ERC1155SeaDropContractOfferer.t.sol.
 *
 *      Seaport wraps any `generateOrder` revert in
 *      `InvalidContractOrder(orderHash)`, so failures also check the SeaDrop
 *      error through `previewOrder`, which runs the same validation.
 */
contract ERC1155SeaDropContractOffererMintTest is SeaDrop1155OffererFixture {
    /// @dev Should not be able to mint until the creator payout is set.
    function testCannotMintUntilCreatorPayoutsSet() public {
        ERC1155SeaDrop token2_ = _deployToken();
        IERC1155SeaDrop sd2 = IERC1155SeaDrop(address(token2_));

        token2_.setMaxSupply(0, 5);
        sd2.updatePublicDrop(publicDrop, 0);
        sd2.updateAllowedFeeRecipient(feeRecipient, true);

        assertEq(sd2.getCreatorPayouts().length, 0);
        vm.expectRevert(CreatorPayoutsNotSet.selector);
        sd2.updateCreatorPayouts(new CreatorPayout[](0));

        MintOrder memory m = _publicMint(
            address(token2_),
            _uints(0),
            _uints(1),
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(m);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(CreatorPayoutsNotSet.selector)
        );

        sd2.updateCreatorPayouts(_payouts(creator, 1_000, owner, 9_000));

        (order, value) = _createMintOrder(m);

        // Should not be able to mint when minimumReceived.length is zero.
        (AdvancedOrder memory emptyOfferOrder,) = _createMintOrder(m);
        emptyOfferOrder.parameters.offer = new OfferItem[](0);
        _assertMintReverts(
            emptyOfferOrder,
            minter,
            value,
            abi.encodeWithSelector(
                MustSpecifyERC1155ConsiderationItemForSeaDropMint.selector
            )
        );

        vm.expectEmit(true, true, true, true, address(token2_));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);
    }

    /// @dev Should handle descending and ascending mint prices.
    function testDescendingAndAscendingMintPrices() public {
        PublicDrop memory descDrop = publicDrop;
        descDrop.startPrice = 1 ether;
        descDrop.endPrice = 0.1 ether;
        _seaDrop().updatePublicDrop(descDrop, 0);

        // Specifying the null address for minter means the fulfiller should
        // be assigned as the minter.
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(0),
                _uints(1),
                feeRecipient,
                publicDrop.feeBps,
                descDrop.startPrice,
                address(0),
                0
            )
        );

        // Fix the next block timestamp so we can calculate the expected
        // price.
        uint256 nextTimestamp = vm.getBlockTimestamp() + 20;
        vm.warp(nextTimestamp);
        uint256 expected = _expectedPrice(
            descDrop.startPrice,
            descDrop.endPrice,
            publicDrop.startTime,
            publicDrop.endTime,
            nextTimestamp
        );

        uint256 balanceBefore = minter.balance;

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        // Should refund the difference between the expected price and the
        // provided amount. Forge charges no gas to the pranked sender.
        assertEq(minter.balance, balanceBefore - expected, "desc price");

        // Test asc mint price
        PublicDrop memory ascDrop = publicDrop;
        ascDrop.startPrice = 0.1 ether;
        ascDrop.endPrice = 1 ether;
        _seaDrop().updatePublicDrop(ascDrop, 0);
        (order, value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(0),
                _uints(1),
                feeRecipient,
                publicDrop.feeBps,
                ascDrop.endPrice,
                minter,
                0
            )
        );

        balanceBefore = minter.balance;
        nextTimestamp += 250;
        vm.warp(nextTimestamp);
        expected = _expectedPrice(
            ascDrop.startPrice,
            ascDrop.endPrice,
            publicDrop.startTime,
            publicDrop.endTime,
            nextTimestamp
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        assertEq(minter.balance, balanceBefore - expected, "asc price");

        // Should allow newly minted tokens to be transferred in Seaport
        // secondary sales.
        assertEq(token.balanceOf(minter, 0), 2);
        _sellMintedTokensToOwner();
        assertEq(token.balanceOf(owner, 0), 2);
        assertEq(token.balanceOf(minter, 0), 0);
    }

    /// @dev A secondary sale: `minter` lists 2 of token id 0 in a signed
    ///      FULL_OPEN order and `owner` fulfills it.
    function _sellMintedTokensToOwner() internal {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC1155,
            token: address(token),
            identifierOrCriteria: 0,
            startAmount: 2,
            endAmount: 2
        });
        ConsiderationItem[] memory items = new ConsiderationItem[](2);
        items[0] = ConsiderationItem({
            itemType: ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: 10 ether,
            endAmount: 0.1 ether,
            recipient: payable(minter)
        });
        items[1] = ConsiderationItem({
            itemType: ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: 1 ether,
            endAmount: 0.01 ether,
            recipient: payable(owner)
        });

        OrderParameters memory parameters = OrderParameters({
            offerer: minter,
            zone: address(0),
            offer: offer,
            consideration: items,
            orderType: OrderType.FULL_OPEN,
            startTime: 0,
            endTime: 0xff00000000000000000000000000,
            zoneHash: bytes32(0),
            salt: uint256(keccak256("secondary sale")),
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: 2
        });
        OrderComponents memory components = OrderComponents({
            offerer: parameters.offerer,
            zone: parameters.zone,
            offer: parameters.offer,
            consideration: parameters.consideration,
            orderType: parameters.orderType,
            startTime: parameters.startTime,
            endTime: parameters.endTime,
            zoneHash: parameters.zoneHash,
            salt: parameters.salt,
            conduitKey: parameters.conduitKey,
            counter: consideration.getCounter(minter)
        });
        bytes memory signature = signOrder(
            consideration, minterPk, consideration.getOrderHash(components)
        );

        // How much ether (at most) needs to be supplied when fulfilling.
        uint256 value = 10 ether + 1 ether;

        vm.prank(minter);
        token.setApprovalForAll(address(consideration), true);

        consideration.fulfillOrder{ value: value }(
            Order({ parameters: parameters, signature: signature }), bytes32(0)
        );
    }

    /// @dev Should not allow reentrancy during mint.
    function testNoReentrancyDuringMint() public {
        // Set a public drop with maxTotalMintableByWallet: 1
        // and restrictFeeRecipient: false
        PublicDrop memory drop = publicDrop;
        drop.startPrice = 1 ether;
        drop.endPrice = 1 ether;
        drop.maxTotalMintableByWallet = 1;
        drop.restrictFeeRecipients = false;
        _seaDrop().updatePublicDrop(drop, 0);

        MaliciousRecipient maliciousRecipient = new MaliciousRecipient();

        // Set the creator address to MaliciousRecipient.
        _seaDrop()
            .updateCreatorPayouts(_payouts(address(maliciousRecipient), 10_000));

        // Should not be able to mint with reentrancy.
        maliciousRecipient.setStartAttack{ value: 10 ether }();
        vm.expectRevert(ReentrancyErrors.NoReentrantCalls.selector);
        maliciousRecipient.attack(consideration, address(token));
        assertEq(token.totalSupply(0), 0);
    }

    /// @dev Should handle ERC20 payment tokens without and with a conduit.
    function testERC20PaymentTokenWithoutAndWithConduit() public {
        // Deploy the payment token.
        TestERC20 paymentToken = new TestERC20();

        PublicDrop memory drop = publicDrop;
        drop.paymentToken = address(paymentToken);
        _seaDrop().updatePublicDrop(drop, 0);

        MintOrder memory m = _publicMint(
            address(token),
            _uints(0),
            _uints(1),
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter,
            0
        );
        m.paymentToken = address(paymentToken);
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(m);

        // Mint the needed amount of payment tokens to the minter.
        paymentToken.mint(minter, value);

        // Should fail if we have not approved the payment token.
        vm.expectRevert(bytes("NOT_AUTHORIZED"));
        _fulfill(order, minter, 0);

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(consideration), value);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, 0);

        // Confirm the payment token was transferred and user has no balance
        // left.
        assertEq(paymentToken.balanceOf(minter), 0);
        uint256 feeAmount = (value * publicDrop.feeBps) / 10_000;
        uint256 creatorAmount = value - feeAmount;
        assertEq(paymentToken.balanceOf(feeRecipient), feeAmount);
        assertEq(paymentToken.balanceOf(creator), creatorAmount);

        // Now try with conduit
        _setConduit(address(token), address(conduit));
        // Mint one minus the needed amount of payment tokens to the minter.
        paymentToken.mint(minter, value - 1);

        // Should fail if we have not approved the payment token.
        vm.expectRevert(bytes("NOT_AUTHORIZED"));
        _fulfill(order, minter, 0, conduitKeyOne);

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(conduit), value);

        // It should still fail as we have one minus the needed balance.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        _fulfill(order, minter, 0, conduitKeyOne);

        // Mint one more payment token to the minter.
        paymentToken.mint(minter, 1);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, 0, conduitKeyOne);

        // Confirm the payment token was transferred and user has no balance
        // left. Multiply expected balance for feeRecipient and creator by 2
        // as we minted twice.
        assertEq(paymentToken.balanceOf(minter), 0);
        assertEq(paymentToken.balanceOf(feeRecipient), feeAmount * 2);
        assertEq(paymentToken.balanceOf(creator), creatorAmount * 2);
    }

    /// @dev Should mint multiple token ids in the same order for the same
    ///      stage.
    function testMintMultipleTokenIdsInSameOrder() public {
        token.setMaxSupply(1, 1);
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(0, 1),
                _uints(1, 1),
                feeRecipient,
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter,
                0
            )
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 0), 1);
        assertEq(token.balanceOf(minter, 1), 1);
        address[] memory owners = _addrs(minter, minter);
        uint256[] memory balances = token.balanceOfBatch(owners, _uints(0, 1));
        assertEq(balances.length, 2);
        assertEq(balances[0], 1);
        assertEq(balances[1], 1);

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );

        // Token ids 0, 1, 0: token id 1 is already at its max supply, so
        // validation stops at the second item before it sees the repeated 0.
        (order, value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(0, 1, 0),
                _uints(1, 1, 1),
                feeRecipient,
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter,
                0
            )
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );

        // Should revert if duplicate token ids are provided.
        (AdvancedOrder memory duplicateOrder,) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(0, 0),
                _uints(1, 1),
                feeRecipient,
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter,
                0
            )
        );
        _expectPreviewRevert(
            duplicateOrder,
            minter,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.OfferContainsDuplicateTokenId
                .selector,
                0
            )
        );

        // Ensure we cannot exceed maxTotalMintableByWallet with the total
        // mint quantity. We have already minted 2 tokens.
        PublicDrop memory drop = publicDrop;
        drop.maxTotalMintableByWallet = 3;
        _seaDrop().updatePublicDrop(drop, 0);
        token.setMaxSupply(7, 1);
        token.setMaxSupply(8, 1);
        assertEq(token.balanceOf(minter, 7), 0);
        assertEq(token.balanceOf(minter, 8), 0);
        (order, value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(7, 8),
                _uints(1, 1),
                feeRecipient,
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter,
                0
            )
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 4, 3
            )
        );

        // Update maxTotalMintableByWallet to 4, the order should now succeed.
        drop.maxTotalMintableByWallet = 4;
        _seaDrop().updatePublicDrop(drop, 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 7), 1);
        assertEq(token.balanceOf(minter, 8), 1);
    }

    /// @dev Should be able to mint with 100% fee bps.
    function testMintWithFullFeeBps() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 10_000; // 100%
        _seaDrop().updatePublicDrop(drop, 0);

        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(0),
                _uints(1),
                feeRecipient,
                10_000,
                publicDrop.startPrice,
                minter,
                0
            )
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        assertEq(token.balanceOf(minter, 0), 1);
    }

    /// @dev Should return errors for invalid encodings.
    function testInvalidExtraDataEncodings() public {
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMint(
                address(token),
                _uints(0),
                _uints(1),
                feeRecipient,
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter,
                0
            )
        );
        bytes memory extraData = order.extraData;

        // SIP-6 version byte 0x01.
        order.extraData = _slice(extraData, 0, extraData.length);
        order.extraData[0] = 0x01;
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 1)
        );

        // Substandard 4.
        order.extraData = _slice(extraData, 0, extraData.length);
        order.extraData[1] = 0x04;
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidSubstandard.selector, 4)
        );

        // Truncated to 9 bytes.
        order.extraData = _slice(extraData, 0, 9);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );
    }

    /// @dev A public mint order of `quantities` of `tokenIds` from the
    ///      fixture's fee recipient at the public drop's fee and price.
    function _mintOrder(uint256[] memory tokenIds, uint256[] memory quantities)
        internal
        view
        returns (AdvancedOrder memory, uint256)
    {
        return _createMintOrder(
            _publicMint(
                address(token),
                tokenIds,
                quantities,
                feeRecipient,
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter,
                0
            )
        );
    }

    /// @dev Any non-zero SIP-6 version byte is unsupported.
    function testDecodeOrderRejectsUnsupportedVersion(uint8 version)
        public
        view
    {
        version = uint8(bound(version, 1, type(uint8).max));
        (AdvancedOrder memory order,) = _mintOrder(_uints(0), _uints(1));
        order.extraData[0] = bytes1(version);
        _expectPreviewRevert(
            order,
            minter,
            abi.encodeWithSelector(
                UnsupportedExtraDataVersion.selector, version
            )
        );
    }

    /// @dev Substandards 3 and up are unsupported.
    function testDecodeOrderRejectsInvalidSubstandard(uint8 substandard)
        public
    {
        substandard = uint8(bound(substandard, 3, type(uint8).max));
        (AdvancedOrder memory order, uint256 value) =
            _mintOrder(_uints(0), _uints(1));
        order.extraData[1] = bytes1(substandard);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidSubstandard.selector, substandard)
        );
    }

    /// @dev A context shorter than 43 bytes is an invalid encoding, down to
    ///      an empty one, which must not panic on the missing version and
    ///      substandard bytes.
    function testDecodeOrderRejectsShortContext() public view {
        (AdvancedOrder memory order,) = _mintOrder(_uints(0), _uints(1));
        bytes memory extraData = order.extraData;
        assertEq(extraData.length, 43);

        uint256[4] memory lengths = [uint256(0), 1, 2, 42];
        for (uint256 i = 0; i < lengths.length; i++) {
            order.extraData = _slice(extraData, 0, lengths[i]);
            _expectPreviewRevert(
                order,
                minter,
                abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
            );
        }

        // A lone non-zero version byte reports the version first.
        order.extraData = hex"07";
        _expectPreviewRevert(
            order,
            minter,
            abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 7)
        );

        // 43 bytes is enough for a public mint.
        order.extraData = extraData;
        _previewOrder(order, minter);
    }

    /// @dev minimumReceived must hold at least one item, and every item must
    ///      be an ERC-1155 item of this token.
    function testDecodeOrderRejectsInvalidMinimumReceived() public view {
        bytes memory mustSpecify = abi.encodeWithSelector(
            MustSpecifyERC1155ConsiderationItemForSeaDropMint.selector
        );

        (AdvancedOrder memory order,) = _mintOrder(_uints(0), _uints(1));
        order.parameters.offer = new OfferItem[](0);
        _expectPreviewRevert(order, minter, mustSpecify);

        // The second item is not an ERC-1155 item.
        (order,) = _mintOrder(_uints(0, 1), _uints(1, 1));
        order.parameters.offer[1].itemType = ItemType.ERC721;
        _expectPreviewRevert(order, minter, mustSpecify);

        // The second item is another token.
        (order,) = _mintOrder(_uints(0, 1), _uints(1, 1));
        order.parameters.offer[1].token = address(0xbeef);
        _expectPreviewRevert(order, minter, mustSpecify);
    }

    /// @dev With several decoding errors at once, the error follows the
    ///      precedence version, encoding, substandard, minimumReceived.
    ///      Covers every combination of the four.
    function testDecodeOrderErrorPrecedence() public view {
        for (uint256 flags = 0; flags < 16; flags++) {
            bool badVersion = flags & 1 != 0;
            bool shortContext = flags & 2 != 0;
            bool badSubstandard = flags & 4 != 0;
            bool badItem = flags & 8 != 0;

            (AdvancedOrder memory order,) = _mintOrder(_uints(0), _uints(1));
            if (badVersion) order.extraData[0] = 0x01;
            if (badSubstandard) order.extraData[1] = 0x03;
            if (shortContext) order.extraData = _slice(order.extraData, 0, 42);
            if (badItem) order.parameters.offer[0].token = address(0xbeef);

            bytes memory expected;
            if (badVersion) {
                expected = abi.encodeWithSelector(
                    UnsupportedExtraDataVersion.selector, 1
                );
            } else if (shortContext) {
                expected = abi.encodeWithSelector(
                    InvalidExtraDataEncoding.selector, 0
                );
            } else if (badSubstandard) {
                expected =
                    abi.encodeWithSelector(InvalidSubstandard.selector, 3);
            } else if (badItem) {
                expected = abi.encodeWithSelector(
                    MustSpecifyERC1155ConsiderationItemForSeaDropMint.selector
                );
            }

            if (expected.length == 0) {
                _previewOrder(order, minter);
            } else {
                _expectPreviewRevert(order, minter, expected);
            }
        }
    }

    /// @dev MintQuantityExceedsMaxMintedPerWalletForTokenId reports the
    ///      wallet's mints of that token id plus the quantity, not its mints
    ///      across all token ids.
    function testMaxMintedPerWalletForTokenIdReportsPerTokenTotal() public {
        token.setMaxSupply(1, 10);
        PublicDrop memory drop = publicDrop;
        drop.maxTotalMintableByWalletPerToken = 3;
        _seaDrop().updatePublicDrop(drop, 0);

        // Mint 3 of token id 0.
        (AdvancedOrder memory order, uint256 value) =
            _mintOrder(_uints(0), _uints(3));
        _fulfill(order, minter, value);

        // 4 of token id 1, of which the wallet holds none.
        (order, value) = _mintOrder(_uints(1), _uints(4));
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                1,
                4,
                3
            )
        );

        // 1 more of token id 0.
        (order, value) = _mintOrder(_uints(0), _uints(1));
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.MintQuantityExceedsMaxMintedPerWalletForTokenId
                    .selector,
                0,
                4,
                3
            )
        );
    }

    /// @dev The wallet limit is checked against the running total of the
    ///      order's items, so the middle item of 1, 4, 1 with a limit of 3
    ///      reports 1 + 4 = 5, not its own 4.
    function testMaxMintedPerWalletReportsRunningTotal() public {
        token.setMaxSupply(1, 10);
        token.setMaxSupply(2, 10);
        PublicDrop memory drop = publicDrop;
        drop.maxTotalMintableByWallet = 3;
        _seaDrop().updatePublicDrop(drop, 0);

        (AdvancedOrder memory order, uint256 value) =
            _mintOrder(_uints(0, 1, 2), _uints(1, 4, 1));
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 5, 3
            )
        );
    }

    /// @dev For any quantities, prior mints and wallet limit, the order
    ///      fails at the first item whose running total (with prior mints)
    ///      exceeds the limit and reports that total, or succeeds.
    function testFuzzMaxMintedPerWalletRunningTotal(
        uint256 q0,
        uint256 q1,
        uint256 q2,
        uint256 minted,
        uint256 maxWallet
    ) public {
        uint256[] memory quantities = _uints(
            bound(q0, 1, 20), bound(q1, 1, 20), bound(q2, 1, 20)
        );
        minted = bound(minted, 0, 5);
        maxWallet = bound(maxWallet, 1, 70);

        for (uint256 tokenId = 0; tokenId < 4; tokenId++) {
            token.setMaxSupply(tokenId, 1000);
        }
        if (minted != 0) {
            _mintTokens(minter, 3, minted);
        }

        PublicDrop memory drop = publicDrop;
        drop.maxTotalMintableByWallet = uint16(maxWallet);
        drop.maxTotalMintableByWalletPerToken = 1000;
        _seaDrop().updatePublicDrop(drop, 0);

        (AdvancedOrder memory order, uint256 value) =
            _mintOrder(_uints(0, 1, 2), quantities);

        uint256 runningTotal = minted;
        for (uint256 i = 0; i < quantities.length; i++) {
            runningTotal += quantities[i];
            if (runningTotal > maxWallet) {
                _assertMintReverts(
                    order,
                    minter,
                    value,
                    abi.encodeWithSelector(
                        MintQuantityExceedsMaxMintedPerWallet.selector,
                        runningTotal,
                        maxWallet
                    )
                );
                return;
            }
        }
        _fulfill(order, minter, value);
        assertEq(token.balanceOf(minter, 2), quantities[2]);
    }
}
