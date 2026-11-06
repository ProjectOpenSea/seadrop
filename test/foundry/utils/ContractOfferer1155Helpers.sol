// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./SeaDrop1155Test.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType, OrderType } from "seaport-types/src/lib/ConsiderationEnums.sol";

/**
 * @dev Helpers for driving ERC1155SeaDrop as a Seaport contract offerer,
 *      ported from the Hardhat helpers in test/utils (order.ts, helpers.ts).
 */
abstract contract ERC1155SeaDropContractOffererHelpers is SeaDrop1155Test {
    /// @dev The OpenSea conduit address hardcoded in the token bytecode
    ///      (ERC1155ConduitPreapproved._CONDUIT).
    address internal constant _OPENSEA_CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /// @dev Arguments for `_createMintOrder`, mirroring `createMintOrder`
    ///      in test/utils/order.ts for MintType.PUBLIC.
    struct MintOrderArgs {
        address token;
        uint256[] tokenIds;
        uint256[] quantities;
        uint8 publicDropIndex;
        address feeRecipient;
        uint256 feeBps;
        uint256 price;
        address paymentToken;
        address minter;
    }

    /**
     * @dev Port of `createMintOrder` (public mint). Builds a CONTRACT order
     *      whose offer is the ERC1155 items to mint and whose consideration
     *      is the fee recipient item plus one item per creator payout.
     *      Returns the order and `value` (price * total quantity).
     */
    function _createMintOrder(
        MintOrderArgs memory args
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        uint256 numTokenIds = args.tokenIds.length;
        OfferItem[] memory offer = new OfferItem[](numTokenIds);
        uint256 totalQuantity;
        for (uint256 i = 0; i < numTokenIds; i++) {
            offer[i] = OfferItem({
                itemType: ItemType.ERC1155,
                token: args.token,
                identifierOrCriteria: args.tokenIds[i],
                startAmount: args.quantities[i],
                endAmount: args.quantities[i]
            });
            totalQuantity += args.quantities[i];
        }

        value = args.price * totalQuantity;
        ConsiderationItem[] memory items = _mintConsideration(args, value);

        order.parameters = OrderParameters({
            offerer: args.token,
            zone: address(0),
            offer: offer,
            consideration: items,
            orderType: OrderType.CONTRACT,
            startTime: block.timestamp - 1000,
            endTime: block.timestamp + 1000,
            zoneHash: bytes32(0),
            salt: 0,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: items.length
        });
        order.numerator = 1;
        order.denominator = 1;
        order.signature = "";
        order.extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version byte: public mint
            bytes20(args.feeRecipient),
            bytes20(args.minter),
            bytes1(args.publicDropIndex)
        );
    }

    /**
     * @dev The fee recipient item (if the fee is nonzero) followed by one
     *      item per creator payout (if the creator amount is nonzero).
     */
    function _mintConsideration(
        MintOrderArgs memory args,
        uint256 value
    ) internal view returns (ConsiderationItem[] memory items) {
        uint256 feeAmount = (value * args.feeBps) / 10_000;
        uint256 creatorAmount = value - feeAmount;

        ItemType itemType = args.paymentToken == address(0)
            ? ItemType.NATIVE
            : ItemType.ERC20;

        CreatorPayout[] memory creatorPayouts = IERC1155SeaDrop(args.token)
            .getCreatorPayouts();

        items = new ConsiderationItem[](
            (feeAmount > 0 ? 1 : 0) +
                (creatorAmount > 0 ? creatorPayouts.length : 0)
        );
        uint256 index;
        if (feeAmount > 0) {
            items[index++] = ConsiderationItem({
                itemType: itemType,
                token: args.paymentToken,
                identifierOrCriteria: 0,
                startAmount: feeAmount,
                endAmount: feeAmount,
                recipient: payable(args.feeRecipient)
            });
        }
        if (creatorAmount > 0) {
            for (uint256 i = 0; i < creatorPayouts.length; i++) {
                uint256 amount = (creatorAmount *
                    creatorPayouts[i].basisPoints) / 10_000;
                items[index++] = ConsiderationItem({
                    itemType: itemType,
                    token: args.paymentToken,
                    identifierOrCriteria: 0,
                    startAmount: amount,
                    endAmount: amount,
                    recipient: payable(creatorPayouts[i].payoutAddress)
                });
            }
        }
    }

    /**
     * @dev The order hash Seaport derives for the next contract order from
     *      `offerer`, used as the argument of `InvalidContractOrder`.
     *      Read it before any `vm.prank` / `vm.expectRevert`.
     */
    function _contractOrderHash(
        address offerer
    ) internal view returns (bytes32) {
        return
            bytes32(
                (uint256(uint160(offerer)) << 96) +
                    consideration.getContractOffererNonce(offerer)
            );
    }

    /**
     * @dev Calls `previewOrder` on the offerer with the same minimumReceived,
     *      maximumSpent and context Seaport would pass to `generateOrder`.
     */
    function _previewOrder(
        AdvancedOrder memory order,
        address fulfiller
    ) internal view {
        OrderParameters memory parameters = order.parameters;
        SpentItem[] memory minimumReceived = new SpentItem[](
            parameters.offer.length
        );
        for (uint256 i = 0; i < parameters.offer.length; i++) {
            minimumReceived[i] = SpentItem({
                itemType: parameters.offer[i].itemType,
                token: parameters.offer[i].token,
                identifier: parameters.offer[i].identifierOrCriteria,
                amount: parameters.offer[i].startAmount
            });
        }
        SpentItem[] memory maximumSpent = new SpentItem[](
            parameters.consideration.length
        );
        for (uint256 i = 0; i < parameters.consideration.length; i++) {
            maximumSpent[i] = SpentItem({
                itemType: parameters.consideration[i].itemType,
                token: parameters.consideration[i].token,
                identifier: parameters.consideration[i].identifierOrCriteria,
                amount: parameters.consideration[i].startAmount
            });
        }
        ContractOffererInterface(parameters.offerer).previewOrder(
            address(consideration),
            fulfiller,
            minimumReceived,
            maximumSpent,
            order.extraData
        );
    }

    /**
     * @dev Asserts that `previewOrder` for `order` reverts with
     *      `revertData`, which is the reason Seaport hides behind
     *      `InvalidContractOrder` when the same order is fulfilled.
     */
    function _expectPreviewOrderRevert(
        AdvancedOrder memory order,
        address fulfiller,
        bytes memory revertData
    ) internal {
        vm.expectRevert(revertData);
        this.externalPreviewOrder(order, fulfiller);
    }

    /// @dev External wrapper so `vm.expectRevert` targets a single call.
    function externalPreviewOrder(
        AdvancedOrder memory order,
        address fulfiller
    ) external view {
        _previewOrder(order, fulfiller);
    }

    /**
     * @dev Port of `expectedPrice` in test/utils/order.ts (rounds down).
     */
    function _expectedPrice(
        uint256 startPrice,
        uint256 endPrice,
        uint256 startTime,
        uint256 endTime,
        uint256 blockTimestamp
    ) internal pure returns (uint256) {
        uint256 duration = endTime - startTime;
        uint256 elapsed = blockTimestamp - startTime;
        uint256 remaining = duration - elapsed;
        return ((startPrice * remaining) + (endPrice * elapsed)) / duration;
    }

    /**
     * @dev Port of `setConduit` in test/utils/helpers.ts: rewrites every
     *      occurrence of the OpenSea conduit address in `target`'s runtime
     *      code with `newConduit`.
     */
    function _setConduit(address target, address newConduit) internal {
        bytes memory code = target.code;
        bytes32 mask = bytes32(type(uint256).max << 96);
        bytes32 oldConduit = bytes32(bytes20(_OPENSEA_CONDUIT));
        bytes20 replacement = bytes20(newConduit);
        uint256 replaced;
        for (uint256 i = 0; i + 20 <= code.length; i++) {
            bytes32 word;
            assembly {
                word := mload(add(add(code, 0x20), i))
            }
            if (word & mask == oldConduit) {
                for (uint256 j = 0; j < 20; j++) {
                    code[i + j] = replacement[j];
                }
                replaced++;
                i += 19;
            }
        }
        require(replaced != 0, "conduit address not found in bytecode");
        vm.etch(target, code);
    }

    /**
     * Array literal helpers
     */
    function _uints(uint256 a) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = a;
    }

    function _uints(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _uints(
        uint256 a,
        uint256 b,
        uint256 c
    ) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    function _addrs(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }

    function _addrs(
        address a,
        address b
    ) internal pure returns (address[] memory arr) {
        arr = new address[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _addrs(
        address a,
        address b,
        address c,
        address d
    ) internal pure returns (address[] memory arr) {
        arr = new address[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
    }

    function _assertEq(
        address[] memory a,
        address[] memory b,
        string memory err
    ) internal {
        assertEq(a.length, b.length, err);
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], err);
        }
    }

    function _assertEq(
        CreatorPayout[] memory a,
        CreatorPayout[] memory b
    ) internal {
        assertEq(a.length, b.length, "creator payouts length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i].payoutAddress, b[i].payoutAddress, "payoutAddress");
            assertEq(a[i].basisPoints, b[i].basisPoints, "basisPoints");
        }
    }
}

/**
 * @dev Shared fixture for the ERC1155SeaDropContractOfferer Forge tests,
 *      mirroring the `before` / `beforeEach` hooks of
 *      test/ERC1155SeaDropContractOfferer.spec.ts. The test contract is the
 *      token owner (the spec's `owner` wallet).
 */
abstract contract ERC1155SeaDropContractOffererTestBase is
    ERC1155SeaDropContractOffererHelpers
{
    /// @dev The token cast to its SeaDrop interface (`tokenSeaDropInterface`).
    IERC1155SeaDrop internal sd;

    address internal owner;
    address internal creator;
    address internal minter;
    uint256 internal minterPk;
    address internal feeRecipient;

    PublicDrop internal publicDrop;

    bytes32 internal constant _ALLOW_LIST_MERKLE_ROOT =
        0x3333333333333333333333333333333333333333333333333333333333333333;

    function setUp() public virtual override {
        super.setUp();

        // Use a realistic timestamp so `now - 1000` does not underflow.
        vm.warp(1_700_000_000);

        owner = address(this);
        creator = makeAddr("creator");
        (minter, minterPk) = makeAddrAndKey("minter");
        feeRecipient = makeAddr("feeRecipient");

        // faucet
        vm.deal(minter, 100 ether);

        token = new ERC1155SeaDrop(
            address(configurer),
            allowedSeaport,
            "Test1155",
            "T1155"
        );
        sd = IERC1155SeaDrop(address(token));

        publicDrop = PublicDrop({
            startPrice: 0.1 ether,
            endPrice: 0.1 ether,
            startTime: uint40(block.timestamp - 1000),
            endTime: uint40(block.timestamp + 1000),
            fromTokenId: 0,
            toTokenId: 10,
            paymentToken: address(0),
            maxTotalMintableByWallet: 10,
            maxTotalMintableByWalletPerToken: 9,
            feeBps: 1000,
            restrictFeeRecipients: true
        });

        token.setMaxSupply(0, 5);
        sd.updatePublicDrop(publicDrop, 0);
        sd.updateAllowedFeeRecipient(feeRecipient, true);
        setSingleCreatorPayout(creator);
    }

    /// @dev The spec's `allowListData`.
    function _allowListData() internal pure returns (AllowListData memory) {
        return
            AllowListData({
                merkleRoot: _ALLOW_LIST_MERKLE_ROOT,
                publicKeyURIs: new string[](0),
                allowListURI: ""
            });
    }

    /// @dev `createMintOrder` arguments for a public mint of `token_` at
    ///      public drop index 0, paid in the native token to `feeRecipient`.
    function _publicMintArgs(
        address token_,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        uint256 feeBps,
        uint256 price,
        address minter_
    ) internal view returns (MintOrderArgs memory) {
        return
            MintOrderArgs({
                token: token_,
                tokenIds: tokenIds,
                quantities: quantities,
                publicDropIndex: 0,
                feeRecipient: feeRecipient,
                feeBps: feeBps,
                price: price,
                paymentToken: address(0),
                minter: minter_
            });
    }

    /// @dev `marketplaceContract.connect(minter).fulfillAdvancedOrder(...)`.
    function _fulfillAsMinter(
        AdvancedOrder memory order,
        uint256 value,
        bytes32 fulfillerConduitKey
    ) internal {
        vm.prank(minter);
        consideration.fulfillAdvancedOrder{ value: value }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: fulfillerConduitKey,
            recipient: address(0)
        });
    }

    function _payouts(
        address a,
        uint16 aBps
    ) internal pure returns (CreatorPayout[] memory payouts) {
        payouts = new CreatorPayout[](1);
        payouts[0] = CreatorPayout({ payoutAddress: a, basisPoints: aBps });
    }

    function _payouts(
        address a,
        uint16 aBps,
        address b,
        uint16 bBps
    ) internal pure returns (CreatorPayout[] memory payouts) {
        payouts = new CreatorPayout[](2);
        payouts[0] = CreatorPayout({ payoutAddress: a, basisPoints: aBps });
        payouts[1] = CreatorPayout({ payoutAddress: b, basisPoints: bBps });
    }

    function _payouts(
        address a,
        uint16 aBps,
        address b,
        uint16 bBps,
        address c,
        uint16 cBps
    ) internal pure returns (CreatorPayout[] memory payouts) {
        payouts = new CreatorPayout[](3);
        payouts[0] = CreatorPayout({ payoutAddress: a, basisPoints: aBps });
        payouts[1] = CreatorPayout({ payoutAddress: b, basisPoints: bBps });
        payouts[2] = CreatorPayout({ payoutAddress: c, basisPoints: cBps });
    }
}
