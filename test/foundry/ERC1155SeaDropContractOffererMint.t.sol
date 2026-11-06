// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC1155SeaDropContractOffererTestBase
} from "./utils/ContractOfferer1155Helpers.sol";

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
 * @dev Port of the minting cases of
 *      test/ERC1155SeaDropContractOfferer.spec.ts: mints go through Seaport
 *      with the token as the contract offerer. The admin cases are in
 *      ERC1155SeaDropContractOfferer.t.sol.
 *
 *      Seaport wraps any `generateOrder` revert in
 *      `InvalidContractOrder(orderHash)`, which is all the spec asserts. Where
 *      the spec names the underlying reason in a comment, these tests also
 *      check it through `previewOrder`, which runs the same validation.
 */
contract ERC1155SeaDropContractOffererMintTest is
    ERC1155SeaDropContractOffererTestBase
{
    /// @dev "Should not be able to mint until the creator payout is set"
    function testCannotMintUntilCreatorPayoutsSet() public {
        ERC1155SeaDrop token2_ = new ERC1155SeaDrop(
            address(configurer), allowedSeaport, "Test1155", "T1155"
        );
        IERC1155SeaDrop sd2 = IERC1155SeaDrop(address(token2_));

        token2_.setMaxSupply(0, 5);
        sd2.updatePublicDrop(publicDrop, 0);
        sd2.updateAllowedFeeRecipient(feeRecipient, true);

        assertEq(sd2.getCreatorPayouts().length, 0);
        vm.expectRevert(CreatorPayoutsNotSet.selector);
        sd2.updateCreatorPayouts(new CreatorPayout[](0));

        MintOrderArgs memory args = _publicMintArgs(
            address(token2_),
            _uints(0),
            _uints(1),
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter
        );
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(args);

        bytes32 orderHash = _contractOrderHash(address(token2_));
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
        _fulfillAsMinter(order, value, bytes32(0));
        // CreatorPayoutsNotSet
        _expectPreviewOrderRevert(
            order, minter, abi.encodeWithSelector(CreatorPayoutsNotSet.selector)
        );

        sd2.updateCreatorPayouts(_payouts(creator, 1_000, owner, 9_000));

        (order, value) = _createMintOrder(args);

        // Should not be able to mint when minimumReceived.length is zero
        (AdvancedOrder memory emptyOfferOrder,) = _createMintOrder(args);
        emptyOfferOrder.parameters.offer = new OfferItem[](0);
        orderHash = _contractOrderHash(address(token2_));
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
        _fulfillAsMinter(emptyOfferOrder, value, bytes32(0));
        // CONTRACT BUG (asserting current behavior): the spec names
        // MustSpecifyERC1155ConsiderationItemForSeaDropMint, but
        // `_decodeOrder` tests its error buffer with `errorBuffer << 254`,
        // which keeps bit 0 (minimumReceived) as well as bit 1 (version), so
        // an empty minimumReceived reports UnsupportedExtraDataVersion(0) and
        // MustSpecifyERC1155ConsiderationItemForSeaDropMint is unreachable.
        _expectPreviewOrderRevert(
            emptyOfferOrder,
            minter,
            abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 0)
        );

        vm.expectEmit(true, true, true, true, address(token2_));
        emit SeaDropMint(minter, 0);
        _fulfillAsMinter(order, value, bytes32(0));
    }

    /// @dev "Should handle desc and asc mint prices"
    function testDescendingAndAscendingMintPrices() public {
        PublicDrop memory descDrop = publicDrop;
        descDrop.startPrice = 1 ether;
        descDrop.endPrice = 0.1 ether;
        sd.updatePublicDrop(descDrop, 0);

        // Specifying the null address for minter means the fulfiller should
        // be assigned as the minter.
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(0),
                _uints(1),
                publicDrop.feeBps,
                descDrop.startPrice,
                address(0)
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
        _fulfillAsMinter(order, value, bytes32(0));

        // Should refund the difference between the expected price and the
        // provided amount. Forge charges no gas to the pranked sender, so
        // the spec's txCost term is zero here.
        assertEq(minter.balance, balanceBefore - expected, "desc price");

        // Test asc mint price
        PublicDrop memory ascDrop = publicDrop;
        ascDrop.startPrice = 0.1 ether;
        ascDrop.endPrice = 1 ether;
        sd.updatePublicDrop(ascDrop, 0);
        (order, value) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(0),
                _uints(1),
                publicDrop.feeBps,
                ascDrop.endPrice,
                minter
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
        _fulfillAsMinter(order, value, bytes32(0));

        assertEq(minter.balance, balanceBefore - expected, "asc price");

        // Should allow newly minted tokens to be transferred in Seaport
        // secondary sales.
        assertEq(token.balanceOf(minter, 0), 2);
        _sellMintedTokensToOwner();
        assertEq(token.balanceOf(owner, 0), 2);
        assertEq(token.balanceOf(minter, 0), 0);
    }

    /// @dev The spec's secondary sale: `minter` lists 2 of token id 0 in a
    ///      signed FULL_OPEN order and `owner` fulfills it.
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

    /// @dev "Should not allow reentrancy during mint"
    function testNoReentrancyDuringMint() public {
        // Set a public drop with maxTotalMintableByWallet: 1
        // and restrictFeeRecipient: false
        PublicDrop memory drop = publicDrop;
        drop.startPrice = 1 ether;
        drop.endPrice = 1 ether;
        drop.maxTotalMintableByWallet = 1;
        drop.restrictFeeRecipients = false;
        sd.updatePublicDrop(drop, 0);

        MaliciousRecipient maliciousRecipient = new MaliciousRecipient();

        // Set the creator address to MaliciousRecipient.
        sd.updateCreatorPayouts(_payouts(address(maliciousRecipient), 10_000));

        // Should not be able to mint with reentrancy.
        maliciousRecipient.setStartAttack{ value: 10 ether }();
        vm.expectRevert(ReentrancyErrors.NoReentrantCalls.selector);
        maliciousRecipient.attack(consideration, address(token));
        assertEq(token.totalSupply(0), 0);
    }

    /// @dev "Should handle ERC20 payment tokens without and with conduit"
    function testERC20PaymentTokenWithoutAndWithConduit() public {
        // Deploy the payment token.
        TestERC20 paymentToken = new TestERC20();

        PublicDrop memory drop = publicDrop;
        drop.paymentToken = address(paymentToken);
        sd.updatePublicDrop(drop, 0);

        MintOrderArgs memory args = _publicMintArgs(
            address(token),
            _uints(0),
            _uints(1),
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter
        );
        args.paymentToken = address(paymentToken);
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(args);

        // Mint the needed amount of payment tokens to the minter.
        paymentToken.mint(minter, value);

        // Should fail if we have not approved the payment token.
        vm.expectRevert(bytes("NOT_AUTHORIZED"));
        _fulfillAsMinter(order, 0, bytes32(0));

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(consideration), value);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfillAsMinter(order, 0, bytes32(0));

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
        _fulfillAsMinter(order, 0, conduitKeyOne);

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(conduit), value);

        // It should still fail as we have one minus the needed balance.
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        _fulfillAsMinter(order, 0, conduitKeyOne);

        // Mint one more payment token to the minter.
        paymentToken.mint(minter, 1);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfillAsMinter(order, 0, conduitKeyOne);

        // Confirm the payment token was transferred and user has no balance
        // left. Multiply expected balance for feeRecipient and creator by 2
        // as we minted twice.
        assertEq(paymentToken.balanceOf(minter), 0);
        assertEq(paymentToken.balanceOf(feeRecipient), feeAmount * 2);
        assertEq(paymentToken.balanceOf(creator), creatorAmount * 2);
    }

    /// @dev "Should be able to handle minting multiple tokenIds in the same
    ///      order for the same stage"
    function testMintMultipleTokenIdsInSameOrder() public {
        token.setMaxSupply(1, 1);
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(0, 1),
                _uints(1, 1),
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter
            )
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfillAsMinter(order, value, bytes32(0));

        assertEq(token.balanceOf(minter, 0), 1);
        assertEq(token.balanceOf(minter, 1), 1);
        address[] memory owners = _addrs(minter, minter);
        uint256[] memory balances = token.balanceOfBatch(owners, _uints(0, 1));
        assertEq(balances.length, 2);
        assertEq(balances[0], 1);
        assertEq(balances[1], 1);

        bytes32 orderHash = _contractOrderHash(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
        _fulfillAsMinter(order, value, bytes32(0));
        // MintQuantityExceedsMaxSupply(2, 1)
        _expectPreviewOrderRevert(
            order,
            minter,
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );

        // Should revert if duplicate tokenIds are provided.
        (order, value) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(0, 1, 0),
                _uints(1, 1, 1),
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter
            )
        );
        orderHash = _contractOrderHash(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
        _fulfillAsMinter(order, value, bytes32(0));
        // SPEC GAP (asserting current behavior): the spec's comment names
        // OfferContainsDuplicateTokenId, but token id 1 is already at its max
        // supply, so validation stops at the second item with
        // MintQuantityExceedsMaxSupply(2, 1) before it sees the repeated 0.
        _expectPreviewOrderRevert(
            order,
            minter,
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );
        // Added (not in the spec): an order that reaches the duplicate check.
        (AdvancedOrder memory duplicateOrder,) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(0, 0),
                _uints(1, 1),
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter
            )
        );
        _expectPreviewOrderRevert(
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
        sd.updatePublicDrop(drop, 0);
        token.setMaxSupply(7, 1);
        token.setMaxSupply(8, 1);
        assertEq(token.balanceOf(minter, 7), 0);
        assertEq(token.balanceOf(minter, 8), 0);
        (order, value) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(7, 8),
                _uints(1, 1),
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter
            )
        );

        orderHash = _contractOrderHash(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
        _fulfillAsMinter(order, value, bytes32(0));
        // MintQuantityExceedsMaxMintedPerWallet(4, 3)
        _expectPreviewOrderRevert(
            order,
            minter,
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 4, 3
            )
        );

        // Update maxTotalMintableByWallet to 4, the order should now succeed.
        drop.maxTotalMintableByWallet = 4;
        sd.updatePublicDrop(drop, 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfillAsMinter(order, value, bytes32(0));

        assertEq(token.balanceOf(minter, 7), 1);
        assertEq(token.balanceOf(minter, 8), 1);
    }

    /// @dev "Should be able to mint with 100% fee bps"
    function testMintWithFullFeeBps() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 10_000; // 100%
        sd.updatePublicDrop(drop, 0);

        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(0),
                _uints(1),
                10_000,
                publicDrop.startPrice,
                minter
            )
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfillAsMinter(order, value, bytes32(0));

        assertEq(token.balanceOf(minter, 0), 1);
    }

    /// @dev "Should return errors for invalid encodings"
    function testInvalidExtraDataEncodings() public {
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            _publicMintArgs(
                address(token),
                _uints(0),
                _uints(1),
                publicDrop.feeBps,
                publicDrop.startPrice,
                minter
            )
        );
        bytes memory extraData = order.extraData;

        // SIP-6 version byte 0x01
        order.extraData = _copy(extraData, extraData.length);
        order.extraData[0] = 0x01;
        _expectInvalidContractOrder(order, value);
        // UnsupportedExtraDataVersion(1)
        _expectPreviewOrderRevert(
            order,
            minter,
            abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 1)
        );

        // Substandard 4
        order.extraData = _copy(extraData, extraData.length);
        order.extraData[1] = 0x04;
        _expectInvalidContractOrder(order, value);
        // CONTRACT BUG (asserting current behavior): the spec names
        // InvalidSubstandard(4), but `_decodeOrder` checks
        // `errorBuffer << 252` (bits 0-3) before `errorBuffer << 253`, so the
        // substandard bit reports InvalidExtraDataEncoding(0) and
        // InvalidSubstandard is unreachable.
        _expectPreviewOrderRevert(
            order,
            minter,
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );

        // Truncated to 9 bytes (`order.extraData.slice(0, 20)` in the spec)
        order.extraData = _copy(extraData, 9);
        _expectInvalidContractOrder(order, value);
        // InvalidExtraDataEncoding(0)
        _expectPreviewOrderRevert(
            order,
            minter,
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );
    }

    function _expectInvalidContractOrder(
        AdvancedOrder memory order,
        uint256 value
    ) internal {
        bytes32 orderHash = _contractOrderHash(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
        _fulfillAsMinter(order, value, bytes32(0));
    }

    function _copy(bytes memory data, uint256 length)
        internal
        pure
        returns (bytes memory copy)
    {
        copy = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            copy[i] = data[i];
        }
    }
}
