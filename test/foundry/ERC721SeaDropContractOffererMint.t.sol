// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721OffererFixture } from "./utils/SeaDrop721Test.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import { MaliciousRecipient } from "seadrop/test/MaliciousRecipient.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    OfferItem,
    Order,
    OrderParameters,
    Schema
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ReentrancyErrors
} from "seaport-types/src/interfaces/ReentrancyErrors.sol";

import { TestERC20 } from "../../lib/seaport/contracts/test/TestERC20.sol";

import { stdError } from "forge-std/StdError.sol";

/**
 * @dev Mints through Seaport with the token as the contract offerer. The
 *      deployment, configuration and admin cases are in
 *      ERC721SeaDropContractOfferer.t.sol.
 *
 *      Seaport wraps any `generateOrder` revert in
 *      `InvalidContractOrder(orderHash)`, so failures also check the SeaDrop
 *      error through `previewOrder`, which runs the same validation.
 */
contract ERC721SeaDropContractOffererMintTest is SeaDrop721OffererFixture {
    /// @dev Should not be able to mint until the creator payout is set.
    function testCannotMintUntilCreatorPayoutsSet() public {
        vm.prank(owner);
        ERC721SeaDrop token2 = _deployToken();
        IERC721SeaDrop seaDrop2 = IERC721SeaDrop(address(token2));

        vm.startPrank(owner);
        token2.setMaxSupply(5);
        seaDrop2.updatePublicDrop(publicDrop);
        seaDrop2.updateAllowedFeeRecipient(feeRecipient, true);

        assertEq(seaDrop2.getCreatorPayouts().length, 0);
        vm.expectRevert(CreatorPayoutsNotSet.selector);
        seaDrop2.updateCreatorPayouts(new CreatorPayout[](0));
        vm.stopPrank();

        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token2),
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter
        );

        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(CreatorPayoutsNotSet.selector)
        );

        vm.prank(owner);
        seaDrop2.updateCreatorPayouts(_payouts(creator, 1_000, owner, 9_000));

        (order, value) = _publicMintOrder(
            address(token2),
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter
        );

        vm.expectEmit(true, true, true, true, address(token2));
        emit SeaDropMint(minter, PUBLIC_DROP_STAGE_INDEX);
        _fulfill(order, minter, value);

        // The mint reverts if the offer item identifier is not 0.
        order.parameters.offer[0].identifierOrCriteria = 1;
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(
                MustSpecifyERC1155ConsiderationItemForSeaDropMint.selector
            )
        );
    }

    /// @dev Should handle desc and asc mint prices.
    function testDescAndAscMintPrices() public {
        PublicDrop memory descDrop = publicDrop;
        descDrop.startPrice = 1 ether;
        descDrop.endPrice = 0.1 ether;
        vm.prank(owner);
        _seaDrop().updatePublicDrop(descDrop);

        // Specifying null address for minter means the fulfiller should be
        // assigned as the minter.
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            1,
            feeRecipient,
            publicDrop.feeBps,
            descDrop.startPrice,
            address(0)
        );

        // Fix the next block timestamp so we can calculate the expected price.
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
        emit SeaDropMint(minter, PUBLIC_DROP_STAGE_INDEX);
        _fulfill(order, minter, value);

        // Should refund the difference between the expected price and the
        // provided amount. (Forge charges no gas to the pranked minter.)
        assertEq(minter.balance, balanceBefore - expected);

        // Test asc mint price
        PublicDrop memory ascDrop = publicDrop;
        ascDrop.startPrice = 0.1 ether;
        ascDrop.endPrice = 1 ether;
        vm.prank(owner);
        _seaDrop().updatePublicDrop(ascDrop);

        (order, value) = _publicMintOrder(
            address(token),
            1,
            feeRecipient,
            publicDrop.feeBps,
            ascDrop.endPrice,
            minter
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
        emit SeaDropMint(minter, PUBLIC_DROP_STAGE_INDEX);
        _fulfill(order, minter, value);

        // Should refund the difference between the expected price and the
        // provided amount.
        assertEq(minter.balance, balanceBefore - expected);

        // Should allow newly minted tokens to be transferred in Seaport
        // secondary sales.
        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        _sellTokensOneAndTwoToOwner();
        assertEq(token.ownerOf(1), owner);
        assertEq(token.ownerOf(2), owner);
    }

    /// @dev A secondary sale: the minter lists tokens 1 and 2 in a signed
    ///      FULL_OPEN order and the owner fulfills it with `fulfillOrder`.
    function _sellTokensOneAndTwoToOwner() internal {
        OfferItem[] memory offer = new OfferItem[](2);
        offer[0] = OfferItem(ItemType.ERC721, address(token), 1, 1, 1);
        offer[1] = OfferItem(ItemType.ERC721, address(token), 2, 1, 1);

        ConsiderationItem[] memory items = new ConsiderationItem[](2);
        items[0] = ConsiderationItem(
            ItemType.NATIVE, address(0), 0, 10 ether, 0.1 ether, payable(minter)
        );
        items[1] = ConsiderationItem(
            ItemType.NATIVE, address(0), 0, 1 ether, 0.01 ether, payable(owner)
        );

        OrderParameters memory parameters = OrderParameters({
            offerer: minter,
            zone: address(0),
            offer: offer,
            consideration: items,
            orderType: OrderType.FULL_OPEN,
            startTime: 0,
            endTime: 0xff00000000000000000000000000,
            zoneHash: bytes32(0),
            salt: uint256(keccak256("ERC721SeaDropContractOfferer")),
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: items.length
        });

        bytes32 orderHash = consideration.getOrderHash(
            toOrderComponents(parameters, consideration.getCounter(minter))
        );
        bytes memory signature = signOrder(consideration, minterPk, orderHash);

        vm.prank(minter);
        token.setApprovalForAll(address(consideration), true);

        // How much ether (at most) needs to be supplied.
        uint256 value = 10 ether + 1 ether;
        vm.prank(owner);
        consideration.fulfillOrder{ value: value }(
            Order(parameters, signature), bytes32(0)
        );
    }

    /// @dev Should only let allowed seaport or conduit call the ERC1155
    ///      safeTransferFrom.
    function testOnlyAllowedSeaportOrConduitCanCallSafeTransferFrom() public {
        vm.prank(owner);
        token.setMaxSupply(3);

        bytes4 safeTransferFrom1155Selector = 0xf242432a;

        bytes memory data = abi.encodePacked(
            safeTransferFrom1155Selector,
            abi.encode(address(token), address(0), 0, 1, bytes(""))
        );

        // Impersonate as Seaport
        _assertSafeTransferFromSucceeds(address(consideration), data);

        // Impersonate as conduit
        _assertSafeTransferFromSucceeds(OPENSEA_CONDUIT, data);

        // Impersonate as owner
        _assertSafeTransferFromReverts(owner, data);

        // Should always throw "InvalidCallerOnlyAllowedSeaport" when
        // from != token, to protect against others making fake listings.
        bytes memory dataFromNotTokenContract = abi.encodePacked(
            safeTransferFrom1155Selector,
            abi.encode(owner, address(0), 0, 1, bytes(""))
        );

        // Impersonate as Seaport
        _assertSafeTransferFromReverts(
            address(consideration), dataFromNotTokenContract
        );

        // Impersonate as conduit
        _assertSafeTransferFromReverts(
            OPENSEA_CONDUIT, dataFromNotTokenContract
        );

        // Impersonate as owner
        _assertSafeTransferFromReverts(owner, dataFromNotTokenContract);
    }

    function _assertSafeTransferFromSucceeds(address caller, bytes memory data)
        internal
    {
        vm.prank(caller);
        (bool success,) = address(token).call(data);
        assertTrue(success);
    }

    function _assertSafeTransferFromReverts(address caller, bytes memory data)
        internal
    {
        vm.prank(caller);
        (bool success, bytes memory returnData) = address(token).call(data);
        assertFalse(success);
        assertEq(
            returnData,
            abi.encodeWithSelector(
                InvalidCallerOnlyAllowedSeaport.selector, caller
            )
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
        vm.prank(owner);
        _seaDrop().updatePublicDrop(drop);

        vm.prank(owner);
        MaliciousRecipient maliciousRecipient = new MaliciousRecipient();

        // Set the creator address to MaliciousRecipient.
        vm.prank(owner);
        _seaDrop()
            .updateCreatorPayouts(_payouts(address(maliciousRecipient), 10_000));

        // Should not be able to mint with reentrancy.
        vm.prank(owner);
        maliciousRecipient.setStartAttack{ value: 10 ether }();
        vm.expectRevert(ReentrancyErrors.NoReentrantCalls.selector);
        vm.prank(owner);
        maliciousRecipient.attack(consideration, address(token));
        assertEq(token.totalSupply(), 0);
    }

    /// @dev Should handle ERC20 payment tokens without and with conduit.
    function testERC20PaymentTokenWithoutAndWithConduit() public {
        // Deploy the payment token.
        vm.prank(minter);
        TestERC20 paymentToken = new TestERC20();

        PublicDrop memory drop = publicDrop;
        drop.paymentToken = address(paymentToken);
        vm.prank(owner);
        _seaDrop().updatePublicDrop(drop);

        MintOrder memory m = _publicMint(
            address(token),
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter
        );
        m.paymentToken = address(paymentToken);
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(m);

        // Mint the needed amount of payment tokens to the minter.
        paymentToken.mint(minter, value);

        // Should fail if we have not approved the payment token.
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "NOT_AUTHORIZED")
        );
        _fulfill(order, minter, 0);

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(consideration), value);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, PUBLIC_DROP_STAGE_INDEX);
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
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "NOT_AUTHORIZED")
        );
        _fulfill(order, minter, 0, conduitKeyOne);

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(conduit), value);

        // It should still fail as we have one minus the needed balance.
        vm.expectRevert(stdError.arithmeticError);
        _fulfill(order, minter, 0, conduitKeyOne);

        // Mint one more payment token to the minter.
        paymentToken.mint(minter, 1);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, PUBLIC_DROP_STAGE_INDEX);
        _fulfill(order, minter, 0, conduitKeyOne);

        // Confirm the payment token was transferred and user has no balance
        // left.
        assertEq(paymentToken.balanceOf(minter), 0);
        // Multiply expected balance for feeRecipient and creator by 2 as we
        // minted twice.
        assertEq(paymentToken.balanceOf(feeRecipient), feeAmount * 2);
        assertEq(paymentToken.balanceOf(creator), creatorAmount * 2);
    }

    /// @dev Should be able to mint with 100% fee bps.
    function testMintWith100PercentFeeBps() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 10_000; // 100%
        vm.prank(owner);
        _seaDrop().updatePublicDrop(drop);

        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            1,
            feeRecipient,
            10_000,
            publicDrop.startPrice,
            minter
        );
        // All of the payment goes to the fee recipient.
        assertEq(order.parameters.consideration.length, 1);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfill(order, minter, value);

        assertEq(token.ownerOf(1), minter);
    }

    /// @dev Should return the expected values for getSeaportMetadata.
    function testGetSeaportMetadata() public view {
        bytes4 getSeaportMetadataSelector = 0x2e778efc;
        (bool success, bytes memory returnData) = address(token)
            .staticcall(abi.encodePacked(getSeaportMetadataSelector));
        assertTrue(success);

        (string memory name, Schema[] memory schemas) =
            abi.decode(returnData, (string, Schema[]));

        bytes memory metadata = abi.encode(_uints(0, 1, 2));

        assertEq(name, "ERC721SeaDrop");
        assertEq(schemas.length, 1);
        assertEq(schemas[0].id, 12);
        assertEq(schemas[0].metadata, metadata);
    }

    /// @dev Should return errors for invalid encodings.
    function testInvalidEncodings() public {
        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            address(token),
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter
        );
        bytes memory extraData = order.extraData;

        // Unsupported SIP-6 version byte.
        order.extraData = bytes.concat(
            bytes1(0x01), _slice(extraData, 1, extraData.length)
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 1)
        );

        // Unsupported substandard.
        order.extraData = bytes.concat(
            bytes1(0x00), bytes1(0x04), _slice(extraData, 2, extraData.length)
        );
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidSubstandard.selector, 4)
        );

        // Truncated extraData (9 bytes, below the 42 byte minimum).
        order.extraData = _slice(extraData, 0, 9);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );
    }

    /// @dev A valid public mint order of 1 for the decode tests.
    function _decodeTestOrder()
        internal
        view
        returns (AdvancedOrder memory order, uint256 value)
    {
        (order, value) = _publicMintOrder(
            address(token),
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            minter
        );
    }

    /// @dev Any non-zero SIP-6 version byte is unsupported.
    function testDecodeOrderRejectsUnsupportedVersion(uint8 version)
        public
        view
    {
        version = uint8(bound(version, 1, type(uint8).max));
        (AdvancedOrder memory order,) = _decodeTestOrder();
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
        (AdvancedOrder memory order, uint256 value) = _decodeTestOrder();
        order.extraData[1] = bytes1(substandard);
        _assertMintReverts(
            order,
            minter,
            value,
            abi.encodeWithSelector(InvalidSubstandard.selector, substandard)
        );
    }

    /// @dev A context shorter than 42 bytes is an invalid encoding, down to
    ///      an empty one, which must not panic on the missing version and
    ///      substandard bytes.
    function testDecodeOrderRejectsShortContext() public view {
        (AdvancedOrder memory order,) = _decodeTestOrder();
        bytes memory extraData = order.extraData;
        assertEq(extraData.length, 42);

        uint256[4] memory lengths = [uint256(0), 1, 2, 41];
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

        // 42 bytes is enough for a public mint.
        order.extraData = extraData;
        _previewOrder(order, minter);
    }

    /// @dev minimumReceived must be exactly one ERC-1155 item of this token
    ///      with identifier 0 and a non-zero amount.
    function testDecodeOrderRejectsInvalidMinimumReceived() public view {
        bytes memory mustSpecify = abi.encodeWithSelector(
            MustSpecifyERC1155ConsiderationItemForSeaDropMint.selector
        );

        // Empty, which must not panic.
        (AdvancedOrder memory order,) = _decodeTestOrder();
        order.parameters.offer = new OfferItem[](0);
        _expectPreviewRevert(order, minter, mustSpecify);

        // Two items.
        (order,) = _decodeTestOrder();
        OfferItem[] memory twoItems = new OfferItem[](2);
        twoItems[0] = order.parameters.offer[0];
        twoItems[1] = order.parameters.offer[0];
        order.parameters.offer = twoItems;
        _expectPreviewRevert(order, minter, mustSpecify);

        // Not an ERC-1155 item.
        (order,) = _decodeTestOrder();
        order.parameters.offer[0].itemType = ItemType.ERC721;
        _expectPreviewRevert(order, minter, mustSpecify);

        // Another token.
        (order,) = _decodeTestOrder();
        order.parameters.offer[0].token = address(0xbeef);
        _expectPreviewRevert(order, minter, mustSpecify);

        // A non-zero identifier.
        (order,) = _decodeTestOrder();
        order.parameters.offer[0].identifierOrCriteria = 1;
        _expectPreviewRevert(order, minter, mustSpecify);

        // A zero amount.
        (order,) = _decodeTestOrder();
        order.parameters.offer[0].endAmount = 0;
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

            (AdvancedOrder memory order,) = _decodeTestOrder();
            if (badVersion) order.extraData[0] = 0x01;
            if (badSubstandard) order.extraData[1] = 0x03;
            if (shortContext) order.extraData = _slice(order.extraData, 0, 41);
            if (badItem) order.parameters.offer[0].identifierOrCriteria = 1;

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
}
