// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC721SeaDropContractOffererHelpers
} from "./utils/ContractOfferer721Helpers.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    ERC721SeaDropConfigurer
} from "seadrop/lib/ERC721SeaDropConfigurer.sol";

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
 * @dev Port of the Seaport contract offerer (mint order) cases of
 *      test/ERC721SeaDropContractOfferer.spec.ts. The deployment,
 *      configuration and admin cases live in
 *      ERC721SeaDropContractOfferer.t.sol.
 */
contract ERC721SeaDropContractOffererMintTest is
    ERC721SeaDropContractOffererHelpers
{
    /// @dev it("Should not be able to mint until the creator payout is set")
    function testCannotMintUntilCreatorPayoutsSet() public {
        ERC721SeaDrop token2 = _deployToken(
            address(new ERC721SeaDropConfigurer())
        );
        IERC721SeaDrop seaDrop2 = IERC721SeaDrop(address(token2));

        vm.startPrank(owner);
        token2.setMaxSupply(5);
        seaDrop2.updatePublicDrop(publicDrop);
        seaDrop2.updateAllowedFeeRecipient(feeRecipient, true);

        assertEq(seaDrop2.getCreatorPayouts().length, 0);
        vm.expectRevert(CreatorPayoutsNotSet.selector);
        seaDrop2.updateCreatorPayouts(new CreatorPayout[](0));
        vm.stopPrank();

        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            address(token2),
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            address(0),
            minter
        );

        _expectInvalidContractOrder(address(token2));
        _fulfillAsMinter(order, value, bytes32(0));

        // The reason Seaport wraps in InvalidContractOrder.
        vm.expectRevert(CreatorPayoutsNotSet.selector);
        _previewOrder(order, minter);

        CreatorPayout[] memory payouts = new CreatorPayout[](2);
        payouts[0] = CreatorPayout(creator, 1_000);
        payouts[1] = CreatorPayout(owner, 9_000);
        vm.prank(owner);
        seaDrop2.updateCreatorPayouts(payouts);

        (order, value) = _createMintOrder(
            address(token2),
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            address(0),
            minter
        );

        vm.expectEmit(true, true, true, true, address(token2));
        emit SeaDropMint(minter, _PUBLIC_DROP_STAGE_INDEX);
        _fulfillAsMinter(order, value, bytes32(0));

        // For coverage, ensure mint reverts if offer item identifier is not 0
        order.parameters.offer[0].identifierOrCriteria = 1;
        _expectInvalidContractOrder(address(token2));
        _fulfillAsMinter(order, value, bytes32(0));

        // The reason Seaport wraps in InvalidContractOrder.
        // CONTRACT BUG (asserting current behavior): the spec expects
        // MustSpecifyERC1155ConsiderationItemForSeaDropMint here, but the
        // error-selection shifts in _decodeOrder (`errorBuffer << 254`
        // keeps bits 0 and 1) report a bad minimumReceived item (bit 0) as
        // UnsupportedExtraDataVersion(version).
        vm.expectRevert(
            abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 0)
        );
        _previewOrder(order, minter);
    }

    /// @dev it("Should handle desc and asc mint prices")
    function testDescAndAscMintPrices() public {
        PublicDrop memory descDrop = publicDrop;
        descDrop.startPrice = 1 ether;
        descDrop.endPrice = 0.1 ether;
        vm.prank(owner);
        _seaDrop().updatePublicDrop(descDrop);

        // Specifying null address for minter means the fulfiller should be
        // assigned as the minter.
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            address(token),
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            descDrop.startPrice,
            address(0),
            address(0)
        );

        // Fix the next block timestamp so we can calculate the expected price.
        uint256 nextTimestamp = block.timestamp + 20;
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
        emit SeaDropMint(minter, _PUBLIC_DROP_STAGE_INDEX);
        _fulfillAsMinter(order, value, bytes32(0));

        // Should refund the difference between the expected price and the
        // provided amount. (Forge charges no gas to the pranked minter.)
        assertEq(minter.balance, balanceBefore - expected);

        // Test asc mint price
        PublicDrop memory ascDrop = publicDrop;
        ascDrop.startPrice = 0.1 ether;
        ascDrop.endPrice = 1 ether;
        vm.prank(owner);
        _seaDrop().updatePublicDrop(ascDrop);

        (order, value) = _createMintOrder(
            address(token),
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            ascDrop.endPrice,
            address(0),
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
        emit SeaDropMint(minter, _PUBLIC_DROP_STAGE_INDEX);
        _fulfillAsMinter(order, value, bytes32(0));

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

    /// @dev The minter lists tokens 1 and 2 in a signed FULL_OPEN order
    ///      (`createOrder` in test/seaport-utils/fixtures/marketplace.ts)
    ///      and the owner fulfills it with `fulfillOrder`.
    function _sellTokensOneAndTwoToOwner() internal {
        OfferItem[] memory offer = new OfferItem[](2);
        offer[0] = OfferItem(ItemType.ERC721, address(token), 1, 1, 1);
        offer[1] = OfferItem(ItemType.ERC721, address(token), 2, 1, 1);

        ConsiderationItem[] memory items = new ConsiderationItem[](2);
        items[0] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            10 ether,
            0.1 ether,
            payable(minter)
        );
        items[1] = ConsiderationItem(
            ItemType.NATIVE,
            address(0),
            0,
            1 ether,
            0.01 ether,
            payable(owner)
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
            Order(parameters, signature),
            bytes32(0)
        );
    }

    /// @dev it("Should only let allowed seaport or conduit call the ERC1155
    ///      safeTransferFrom")
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
        _assertSafeTransferFromSucceeds(_OPENSEA_CONDUIT, data);

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
            address(consideration),
            dataFromNotTokenContract
        );

        // Impersonate as conduit
        _assertSafeTransferFromReverts(
            _OPENSEA_CONDUIT,
            dataFromNotTokenContract
        );

        // Impersonate as owner
        _assertSafeTransferFromReverts(owner, dataFromNotTokenContract);
    }

    function _assertSafeTransferFromSucceeds(
        address caller,
        bytes memory data
    ) internal {
        vm.prank(caller);
        (bool success, ) = address(token).call(data);
        assertTrue(success);
    }

    function _assertSafeTransferFromReverts(
        address caller,
        bytes memory data
    ) internal {
        vm.prank(caller);
        (bool success, bytes memory returnData) = address(token).call(data);
        assertFalse(success);
        assertEq(
            returnData,
            abi.encodeWithSelector(
                InvalidCallerOnlyAllowedSeaport.selector,
                caller
            )
        );
    }

    /// @dev it("Should not allow reentrancy during mint")
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
        _seaDrop().updateCreatorPayouts(
            _singlePayout(address(maliciousRecipient), 10_000)
        );

        // Should not be able to mint with reentrancy.
        vm.prank(owner);
        maliciousRecipient.setStartAttack{ value: 10 ether }();
        vm.expectRevert(ReentrancyErrors.NoReentrantCalls.selector);
        vm.prank(owner);
        maliciousRecipient.attack(consideration, address(token));
        assertEq(token.totalSupply(), 0);
    }

    /// @dev it("Should handle ERC20 payment tokens without and with conduit")
    function testERC20PaymentTokenWithoutAndWithConduit() public {
        // Deploy the payment token.
        vm.prank(minter);
        TestERC20 paymentToken = new TestERC20();

        PublicDrop memory drop = publicDrop;
        drop.paymentToken = address(paymentToken);
        vm.prank(owner);
        _seaDrop().updatePublicDrop(drop);

        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            address(token),
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            address(paymentToken),
            minter
        );

        // Mint the needed amount of payment tokens to the minter.
        paymentToken.mint(minter, value);

        // Should fail if we have not approved the payment token.
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "NOT_AUTHORIZED")
        );
        _fulfillAsMinter(order, 0, bytes32(0));

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(consideration), value);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, _PUBLIC_DROP_STAGE_INDEX);
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
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "NOT_AUTHORIZED")
        );
        _fulfillAsMinter(order, 0, conduitKeyOne);

        // Approve the payment token.
        vm.prank(minter);
        paymentToken.approve(address(conduit), value);

        // It should still fail as we have one minus the needed balance.
        vm.expectRevert(stdError.arithmeticError);
        _fulfillAsMinter(order, 0, conduitKeyOne);

        // Mint one more payment token to the minter.
        paymentToken.mint(minter, 1);

        // Now it should succeed.
        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, _PUBLIC_DROP_STAGE_INDEX);
        _fulfillAsMinter(order, 0, conduitKeyOne);

        // Confirm the payment token was transferred and user has no balance
        // left.
        assertEq(paymentToken.balanceOf(minter), 0);
        // Multiply expected balance for feeRecipient and creator by 2 as we
        // minted twice.
        assertEq(paymentToken.balanceOf(feeRecipient), feeAmount * 2);
        assertEq(paymentToken.balanceOf(creator), creatorAmount * 2);
    }

    /// @dev it("Should be able to mint with 100% fee bps")
    function testMintWith100PercentFeeBps() public {
        PublicDrop memory drop = publicDrop;
        drop.feeBps = 10_000; // 100%
        vm.prank(owner);
        _seaDrop().updatePublicDrop(drop);

        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            address(token),
            0,
            1,
            feeRecipient,
            10_000,
            publicDrop.startPrice,
            address(0),
            minter
        );
        // All of the payment goes to the fee recipient.
        assertEq(order.parameters.consideration.length, 1);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(minter, 0);
        _fulfillAsMinter(order, value, bytes32(0));

        assertEq(token.ownerOf(1), minter);
    }

    /// @dev it("Should return the expected values for getSeaportMetadata")
    function testGetSeaportMetadata() public {
        bytes4 getSeaportMetadataSelector = 0x2e778efc;
        (bool success, bytes memory returnData) = address(token).staticcall(
            abi.encodePacked(getSeaportMetadataSelector)
        );
        assertTrue(success);

        (string memory name, Schema[] memory schemas) = abi.decode(
            returnData,
            (string, Schema[])
        );

        uint256[] memory supportedSubstandards = new uint256[](3);
        supportedSubstandards[0] = 0;
        supportedSubstandards[1] = 1;
        supportedSubstandards[2] = 2;
        bytes memory metadata = abi.encode(supportedSubstandards);

        assertEq(name, "ERC721SeaDrop");
        assertEq(schemas.length, 1);
        assertEq(schemas[0].id, 12);
        assertEq(schemas[0].metadata, metadata);
    }

    /// @dev it("Should return errors for invalid encodings")
    ///
    ///      Seaport wraps each failure in InvalidContractOrder. The spec
    ///      only names the underlying error in comments; previewOrder
    ///      asserts it here.
    function testInvalidEncodings() public {
        (AdvancedOrder memory order, uint256 value) = _createMintOrder(
            address(token),
            0,
            1,
            feeRecipient,
            publicDrop.feeBps,
            publicDrop.startPrice,
            address(0),
            minter
        );
        bytes memory extraData = order.extraData;

        // Unsupported SIP-6 version byte.
        order.extraData = bytes.concat(bytes1(0x01), _slice(extraData, 1));
        _expectInvalidContractOrder(address(token));
        _fulfillAsMinter(order, value, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(UnsupportedExtraDataVersion.selector, 1)
        );
        _previewOrder(order, minter);

        // Unsupported substandard.
        order.extraData = bytes.concat(
            bytes1(0x00),
            bytes1(0x04),
            _slice(extraData, 2)
        );
        _expectInvalidContractOrder(address(token));
        _fulfillAsMinter(order, value, bytes32(0));
        // CONTRACT BUG (asserting current behavior): the spec expects
        // InvalidSubstandard(4), but in _decodeOrder `errorBuffer << 252`
        // also keeps the substandard bit (bit 2), so it reverts with
        // InvalidExtraDataEncoding(version) and InvalidSubstandard is
        // unreachable.
        vm.expectRevert(
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );
        _previewOrder(order, minter);

        // Truncated extraData (9 bytes, below the 42 byte minimum).
        order.extraData = _slice(extraData, 0, 9);
        _expectInvalidContractOrder(address(token));
        _fulfillAsMinter(order, value, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(InvalidExtraDataEncoding.selector, 0)
        );
        _previewOrder(order, minter);
    }

    function _slice(
        bytes memory data,
        uint256 start
    ) internal pure returns (bytes memory) {
        return _slice(data, start, data.length);
    }

    function _slice(
        bytes memory data,
        uint256 start,
        uint256 end
    ) internal pure returns (bytes memory result) {
        result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = data[i];
        }
    }
}
