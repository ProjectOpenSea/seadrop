// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import { ISeaDropToken } from "seadrop/interfaces/ISeaDropToken.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    CriteriaResolver,
    Fulfillment,
    FulfillmentComponent,
    OfferItem,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

/**
 * @dev A creator payout contract that makes one call when it is paid, which
 *      runs while Seaport transfers a mint order's payment.
 */
contract PayoutHook {
    address internal _target;
    bytes internal _call;
    uint256 internal _value;
    bool internal _catchRevert;

    /// @dev Whether the armed call ran.
    bool public fired;

    /// @dev The revert data of the armed call, when it was caught.
    bytes public lastError;

    function arm(
        address target,
        bytes calldata data,
        uint256 value,
        bool catchRevert
    ) external {
        _target = target;
        _call = data;
        _value = value;
        _catchRevert = catchRevert;
    }

    receive() external payable {
        address target = _target;
        if (target == address(0)) return;
        _target = address(0);
        fired = true;
        (bool ok, bytes memory ret) = target.call{ value: _value }(_call);
        if (!ok) {
            if (_catchRevert) {
                lastError = ret;
            } else {
                assembly {
                    revert(add(ret, 32), mload(ret))
                }
            }
        }
    }
}

/**
 * @dev A contract the owner adds as an allowed Seaport, which calls the
 *      token's contract offerer functions directly.
 */
contract MockSeaport721 {
    function generate(address token, address fulfiller, address feeRecipient)
        external
    {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC1155,
            token: token,
            identifier: 0,
            amount: 1
        });
        ContractOffererInterface(token)
            .generateOrder(
                fulfiller,
                minimumReceived,
                new SpentItem[](0),
                bytes.concat(
                    bytes1(0x00), // SIP-6 version byte
                    bytes1(0x00), // substandard version byte: public mint
                    bytes20(feeRecipient),
                    bytes20(address(0)) // minter: the fulfiller
                )
            );
    }

    function ratify(address token) external {
        ContractOffererInterface(token)
            .ratifyOrder(
                new SpentItem[](0),
                new ReceivedItem[](0),
                "",
                new bytes32[](0),
                0
            );
    }
}

/**
 * @dev The ERC721 contract offerer mints in generateOrder, and its mint
 *      order offers an ERC-1155 item of the token with identifier 0, so the
 *      transfer Seaport makes for it afterwards is a no-op. Seaport's
 *      recipient for it must be the fulfiller, or the minter when the call
 *      has only one. These tests cover that rule, the per-call mint record
 *      behind it, and each mint substandard through fulfillAdvancedOrder and
 *      matchAdvancedOrders.
 */
contract ERC721SeaDropMintRecordTest is SeaDrop721Test {
    uint80 internal constant _PRICE = 0.1 ether;

    address feeRecipient = makeAddr("feeRecipient");
    address creator = makeAddr("creator");
    address payer = makeAddr("payer");
    address minter = makeAddr("minter");
    address otherMinter = makeAddr("otherMinter");
    address thirdParty = makeAddr("thirdParty");
    address signer = makeAddr("signer");

    function setUp() public override {
        super.setUp();
        token = _deployToken();

        vm.deal(minter, 10 ether);
        vm.deal(payer, 10 ether);

        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(100);
        _setSingleCreatorPayout(address(token), creator);

        // A free public mint, so a mint order needs no consideration.
        _seaDrop().updatePublicDrop(_publicDrop(0));
    }

    function testMintDeliveredToMinter() public {
        AdvancedOrder memory order = _mintOrder(minter, 1);

        vm.prank(minter);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.balanceOf(minter), 1);
    }

    function testMintDeliveredToThirdPartyReverts() public {
        AdvancedOrder memory order = _mintOrder(minter, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientOnlyMinterOrFulfiller.selector, thirdParty
            )
        );
        vm.prank(minter);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: thirdParty
        });
    }

    function testPayerMintDeliveredToPayer() public {
        _seaDrop().updatePayer(payer, true);
        AdvancedOrder memory order = _mintOrder(minter, 1);

        // A zero recipient makes Seaport deliver to the fulfiller (the payer).
        vm.prank(payer);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.balanceOf(minter), 1);
        assertEq(token.balanceOf(payer), 0);
    }

    function testPayerMintDeliveredToMinter() public {
        _seaDrop().updatePayer(payer, true);
        AdvancedOrder memory order = _mintOrder(minter, 1);

        vm.prank(payer);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: minter
        });

        assertEq(token.balanceOf(minter), 1);
    }

    function testPayerMintDeliveredToThirdPartyReverts() public {
        _seaDrop().updatePayer(payer, true);
        AdvancedOrder memory order = _mintOrder(minter, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientOnlyMinterOrFulfiller.selector, thirdParty
            )
        );
        vm.prank(payer);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: thirdParty
        });
    }

    function testDelegatedPayerMintDeliveredToMinter() public {
        // The minter delegates to the payer in the delegation registry, so
        // the payer can pay for a mint to the minter and send it there.
        vm.prank(minter);
        DELEGATION_REGISTRY.delegateForAll(payer, true);
        _seaDrop().updatePublicDrop(_publicDrop(_PRICE));
        (AdvancedOrder memory order, uint256 value) = _paidMintOrder(minter, 2);

        vm.prank(payer);
        consideration.fulfillAdvancedOrder{ value: value }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: minter
        });

        assertEq(token.balanceOf(minter), 2);
        assertEq(token.balanceOf(payer), 0);
        assertEq(creator.balance, value);
    }

    function testPayerBatchForOneMinterDeliveredToMinter() public {
        _seaDrop().updatePayer(payer, true);

        // Several mint orders for the same minter in one call can still
        // deliver to the minter.
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(minter, 1);
        orders[1] = _mintOrder(minter, 2);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter), 3);
    }

    function testPayerBatchForTwoMintersDeliveredToPayer() public {
        _seaDrop().updatePayer(payer, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(minter, 1);
        orders[1] = _mintOrder(otherMinter, 1);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), address(0));

        assertEq(token.balanceOf(minter), 1);
        assertEq(token.balanceOf(otherMinter), 1);
    }

    function testPayerBatchForTwoMintersDeliveredToMinterReverts() public {
        _assertTwoMinterBatchToMinterReverts(true);
    }

    function testPayerBatchForTwoMintersOtherFirstDeliveredToMinterReverts()
        public
    {
        _assertTwoMinterBatchToMinterReverts(false);
    }

    function testMinterFulfillerBatchForTwoMintersDeliveredToFulfiller()
        public
    {
        // The fulfiller is also the first minter, so the record stores no
        // separate fulfiller. Delivery to it is still allowed once a second
        // minter joins the call.
        _seaDrop().updatePayer(minter, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(minter, 1);
        orders[1] = _mintOrder(otherMinter, 1);

        vm.prank(minter);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter), 1);
        assertEq(token.balanceOf(otherMinter), 1);
    }

    function testSkippedMintOrderDoesNotJoinRecord() public {
        _seaDrop().updatePayer(payer, true);

        // The first order is over the per-wallet limit, so its generateOrder
        // reverts and fulfillAvailable skips it. The call has one minter.
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(otherMinter, 6);
        orders[1] = _mintOrder(minter, 1);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter), 1);
        assertEq(token.balanceOf(otherMinter), 0);
    }

    function testSkippedMintOrderBetweenSameMinter() public {
        _seaDrop().updatePayer(payer, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](3);
        orders[0] = _mintOrder(minter, 1);
        orders[1] = _mintOrder(otherMinter, 6);
        orders[2] = _mintOrder(minter, 2);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter), 3);
        assertEq(token.balanceOf(otherMinter), 0);
    }

    function testConduitRoutedMintDeliveredToMinter() public {
        _setConduit(address(token), address(conduit));
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(address(0), 1);
        orders[1] = _mintOrder(address(0), 2);
        orders[0].parameters.conduitKey = conduitKeyOne;
        orders[1].parameters.conduitKey = conduitKeyOne;

        vm.prank(minter);
        _fulfillAvailable(orders, conduitKeyOne, minter);

        assertEq(token.balanceOf(minter), 3);
    }

    function testConduitRoutedMintDeliveredToThirdPartyReverts() public {
        _setConduit(address(token), address(conduit));
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = _mintOrder(minter, 1);
        orders[0].parameters.conduitKey = conduitKeyOne;

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientOnlyMinterOrFulfiller.selector, thirdParty
            )
        );
        vm.prank(minter);
        _fulfillAvailable(orders, conduitKeyOne, thirdParty);
    }

    function testRecordClearedAfterRatify() public {
        AdvancedOrder memory order = _mintOrder(minter, 1);
        vm.prank(minter);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        // ratifyOrder cleared the call's record, so a later transfer from the
        // token without a new mint has no valid recipient.
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientOnlyMinterOrFulfiller.selector, minter
            )
        );
        vm.prank(address(consideration));
        IERC1155(address(token))
            .safeTransferFrom(address(token), minter, 0, 1, "");
    }

    function testRatifyOrderOnlyAllowedSeaport() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidCallerOnlyAllowedSeaport.selector, bob
            )
        );
        vm.prank(bob);
        ContractOffererInterface(address(token))
            .ratifyOrder(
                new SpentItem[](0),
                new ReceivedItem[](0),
                "",
                new bytes32[](0),
                0
            );
    }

    function testNestedFillOnAnotherSeaportReverts() public {
        PayoutHook hook = _payCreatorThroughHook();
        address secondSeaport = deployCode(
            "optimized-out/Consideration.sol/Consideration.json",
            abi.encode(address(conduitController))
        );
        _allowSeaports(address(consideration), secondSeaport);

        // While the minter's mint has the record open, the creator payout
        // fills a mint order on the second allowed Seaport with the payment
        // it receives. That generateOrder reverts with NestedSeaportCall,
        // and Seaport 1.6 bubbles the revert up through the outer payment.
        (AdvancedOrder memory nestedOrder, uint256 nestedValue) =
            _paidMintOrder(address(0), 1);
        hook.arm(
            secondSeaport,
            abi.encodeCall(
                ConsiderationInterface.fulfillAdvancedOrder,
                (nestedOrder, new CriteriaResolver[](0), bytes32(0), address(0))
            ),
            nestedValue,
            false
        );
        (AdvancedOrder memory order, uint256 value) = _paidMintOrder(minter, 1);

        vm.expectRevert(
            abi.encodeWithSelector(NestedSeaportCall.selector, secondSeaport)
        );
        vm.prank(minter);
        consideration.fulfillAdvancedOrder{ value: value }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testGenerateFromAnotherSeaportRevertsWhileRecordOpen() public {
        PayoutHook hook = _payCreatorThroughHook();
        MockSeaport721 mock = new MockSeaport721();
        _allowSeaports(address(consideration), address(mock));

        // During the minter's mint, the other allowed Seaport generates an
        // order for another fulfiller. Catch the revert so the outer mint can
        // finish and the error can be checked.
        hook.arm(
            address(mock),
            abi.encodeCall(
                MockSeaport721.generate,
                (address(token), otherMinter, feeRecipient)
            ),
            0,
            true
        );
        (AdvancedOrder memory order, uint256 value) = _paidMintOrder(minter, 1);
        vm.prank(minter);
        consideration.fulfillAdvancedOrder{ value: value }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertTrue(hook.fired());
        assertEq(
            hook.lastError(),
            abi.encodeWithSelector(NestedSeaportCall.selector, address(mock))
        );
        assertEq(token.balanceOf(minter), 1);
        assertEq(token.balanceOf(otherMinter), 0);
    }

    function testRatifyFromAnotherSeaportKeepsRecord() public {
        PayoutHook hook = _payCreatorThroughHook();
        MockSeaport721 mock = new MockSeaport721();
        _allowSeaports(address(consideration), address(mock));

        // matchAdvancedOrders pays the creator before it transfers the
        // unspent minted item, so the other allowed Seaport's ratifyOrder
        // runs while the record is open. It leaves the record alone, so the
        // item can still go to the minter.
        hook.arm(
            address(mock),
            abi.encodeCall(MockSeaport721.ratify, (address(token))),
            0,
            false
        );
        (AdvancedOrder memory order, uint256 value) = _paidMintOrder(minter, 1);
        _matchAsMinter(order, value, address(0));

        assertTrue(hook.fired());
        assertEq(token.balanceOf(minter), 1);
    }

    function testPublicMintThroughMatch() public {
        _seaDrop().updatePublicDrop(_publicDrop(_PRICE));
        (AdvancedOrder memory order, uint256 value) = _paidMintOrder(minter, 2);

        _matchAsMinter(order, value, address(0));

        assertEq(token.balanceOf(minter), 2);
        assertEq(creator.balance, value);
    }

    function testFreePublicMintThroughMatch() public {
        _matchAsMinter(_mintOrder(minter, 1), 0, minter);

        assertEq(token.balanceOf(minter), 1);
    }

    function testMatchDeliveredToThirdPartyReverts() public {
        AdvancedOrder memory order = _mintOrder(minter, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientOnlyMinterOrFulfiller.selector, thirdParty
            )
        );
        _matchAsMinter(order, 0, thirdParty);
    }

    function testAllowListMintThroughFulfill() public {
        (AdvancedOrder memory order, uint256 value) = _allowListOrder();

        _fulfill(order, minter, value);

        _assertPaidStageMint(value);
    }

    function testAllowListMintThroughMatch() public {
        (AdvancedOrder memory order, uint256 value) = _allowListOrder();

        _matchAsMinter(order, value, address(0));

        _assertPaidStageMint(value);
    }

    function testSignedMintThroughFulfill() public {
        (AdvancedOrder memory order, uint256 value) = _signedOrder();

        _fulfill(order, minter, value);

        _assertPaidStageMint(value);
    }

    function testSignedMintThroughMatch() public {
        (AdvancedOrder memory order, uint256 value) = _signedOrder();

        _matchAsMinter(order, value, address(0));

        _assertPaidStageMint(value);
    }

    /// @dev An allowed payer batch-mints for two minters in either order and
    ///      names one of them as the recipient, which is neither the
    ///      fulfiller nor the call's only minter.
    function _assertTwoMinterBatchToMinterReverts(bool minterFirst) internal {
        _seaDrop().updatePayer(payer, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[minterFirst ? 0 : 1] = _mintOrder(minter, 1);
        orders[minterFirst ? 1 : 0] = _mintOrder(otherMinter, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidRecipientOnlyMinterOrFulfiller.selector, minter
            )
        );
        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);
    }

    /// @dev A public drop open for the next 500 seconds at price per token,
    ///      with no fee.
    function _publicDrop(uint80 price)
        internal
        view
        returns (PublicDrop memory)
    {
        return PublicDrop({
            startPrice: price,
            endPrice: price,
            startTime: uint40(vm.getBlockTimestamp()),
            endTime: uint40(vm.getBlockTimestamp() + 500),
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            feeBps: 0,
            restrictFeeRecipients: true
        });
    }

    /// @dev A paid public drop whose creator payout is a new PayoutHook.
    function _payCreatorThroughHook() internal returns (PayoutHook hook) {
        hook = new PayoutHook();
        _setSingleCreatorPayout(address(token), address(hook));
        _seaDrop().updatePublicDrop(_publicDrop(_PRICE));
    }

    /// @dev A free public mint order for quantity to minter_.
    function _mintOrder(address minter_, uint256 quantity)
        internal
        view
        returns (AdvancedOrder memory order)
    {
        (order,) = _publicMintOrder(
            address(token), quantity, feeRecipient, 0, 0, minter_
        );
    }

    /// @dev A public mint order for quantity to minter_ at _PRICE each.
    function _paidMintOrder(address minter_, uint256 quantity)
        internal
        view
        returns (AdvancedOrder memory order, uint256 value)
    {
        return _publicMintOrder(
            address(token), quantity, feeRecipient, 0, _PRICE, minter_
        );
    }

    /// @dev Stage params for a paid allow list or signed mint with a fee.
    function _mintParams() internal view returns (MintParams memory) {
        return MintParams({
            startPrice: _PRICE,
            endPrice: _PRICE,
            startTime: vm.getBlockTimestamp(),
            endTime: vm.getBlockTimestamp() + 500,
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            maxTokenSupplyForStage: 100,
            dropStageIndex: 1,
            feeBps: 500,
            restrictFeeRecipients: true
        });
    }

    /// @dev An allow list mint order of one token for the minter.
    function _allowListOrder()
        internal
        returns (AdvancedOrder memory order, uint256 value)
    {
        MintParams memory params = _mintParams();
        (bytes32 root, bytes32[] memory proof) =
            _allowListRootAndProof(minter, params);
        _updateAllowList(address(token), root);
        return _allowListMintOrder(
            address(token),
            1,
            feeRecipient,
            params.feeBps,
            params.startPrice,
            minter,
            params,
            proof
        );
    }

    /// @dev A signed mint order of one token for the minter.
    function _signedOrder()
        internal
        returns (AdvancedOrder memory order, uint256 value)
    {
        MintParams memory params = _mintParams();
        _seaDrop().updateSigner(signer, true);
        (bytes memory signature,) = _signMint(
            "signer", address(token), minter, feeRecipient, params, 1
        );
        return _signedMintOrder(
            address(token),
            1,
            feeRecipient,
            params.feeBps,
            params.startPrice,
            minter,
            params,
            1,
            signature
        );
    }

    /// @dev The minter holds the one token of a paid stage mint, and the
    ///      fee recipient and creator split its price.
    function _assertPaidStageMint(uint256 value) internal view {
        assertEq(token.balanceOf(minter), 1);
        assertEq(token.ownerOf(1), minter);
        uint256 fee = (value * 500) / 10_000;
        assertEq(feeRecipient.balance, fee);
        assertEq(creator.balance, value - fee);
    }

    /// @dev Fills mintOrder with matchAdvancedOrders as the minter. A paid
    ///      mint adds the minter's own order offering native tokens, one
    ///      offer item per consideration item of the mint order. The minted
    ///      item is unspent, so Seaport delivers it to recipient (the minter
    ///      when zero).
    function _matchAsMinter(
        AdvancedOrder memory mintOrder,
        uint256 value,
        address recipient
    ) internal {
        ConsiderationItem[] memory items = mintOrder.parameters.consideration;
        uint256 n = items.length;
        AdvancedOrder[] memory orders = new AdvancedOrder[](n == 0 ? 1 : 2);
        orders[0] = mintOrder;
        Fulfillment[] memory fulfillments = new Fulfillment[](n);
        if (n != 0) {
            OfferItem[] memory offer = new OfferItem[](n);
            for (uint256 i = 0; i < n; i++) {
                offer[i] = OfferItem({
                    itemType: ItemType.NATIVE,
                    token: address(0),
                    identifierOrCriteria: 0,
                    startAmount: items[i].startAmount,
                    endAmount: items[i].endAmount
                });
                fulfillments[i].offerComponents = new FulfillmentComponent[](1);
                fulfillments[i].offerComponents[0] =
                    FulfillmentComponent({ orderIndex: 1, itemIndex: i });
                fulfillments[i].considerationComponents =
                    new FulfillmentComponent[](1);
                fulfillments[i].considerationComponents[0] =
                    FulfillmentComponent({ orderIndex: 0, itemIndex: i });
            }
            orders[1] = AdvancedOrder({
                parameters: OrderParameters({
                    offerer: minter,
                    zone: address(0),
                    offer: offer,
                    consideration: new ConsiderationItem[](0),
                    orderType: OrderType.FULL_OPEN,
                    startTime: vm.getBlockTimestamp(),
                    endTime: vm.getBlockTimestamp() + 500,
                    zoneHash: bytes32(0),
                    salt: 0,
                    conduitKey: bytes32(0),
                    totalOriginalConsiderationItems: 0
                }),
                numerator: 1,
                denominator: 1,
                signature: "",
                extraData: ""
            });
        }

        vm.prank(minter);
        consideration.matchAdvancedOrders{ value: value }({
            orders: orders,
            criteriaResolvers: criteriaResolvers,
            fulfillments: fulfillments,
            recipient: recipient
        });
    }

    /// @dev Fills every order, each offer item in its own fulfillment.
    function _fulfillAvailable(
        AdvancedOrder[] memory orders,
        bytes32 fulfillerConduitKey,
        address recipient
    ) internal {
        consideration.fulfillAvailableAdvancedOrders({
                advancedOrders: orders,
                criteriaResolvers: criteriaResolvers,
                offerFulfillments: _offerFulfillments(orders.length),
                considerationFulfillments: new FulfillmentComponent[][](0),
                fulfillerConduitKey: fulfillerConduitKey,
                recipient: recipient,
                maximumFulfilled: orders.length
            });
    }

    function _offerFulfillments(uint256 n)
        internal
        pure
        returns (FulfillmentComponent[][] memory fulfillments)
    {
        fulfillments = new FulfillmentComponent[][](n);
        for (uint256 i = 0; i < n; i++) {
            fulfillments[i] = new FulfillmentComponent[](1);
            fulfillments[i][0] =
                FulfillmentComponent({ orderIndex: i, itemIndex: 0 });
        }
    }

    function _allowSeaports(address seaportA, address seaportB) internal {
        address[] memory seaports = new address[](2);
        seaports[0] = seaportA;
        seaports[1] = seaportB;
        ISeaDropToken(address(token)).updateAllowedSeaport(seaports);
    }
}
