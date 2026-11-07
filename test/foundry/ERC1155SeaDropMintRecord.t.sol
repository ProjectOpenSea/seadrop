// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import {
    ERC1155SeaDropCloneFactory
} from "seadrop/clones/ERC1155SeaDropCloneFactory.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import { ISeaDropToken } from "seadrop/interfaces/ISeaDropToken.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "seadrop/lib/ERC1155SeaDropErrorsAndEvents.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    FulfillmentComponent,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

/**
 * @dev A minter contract that makes one call from its ERC1155 receive hook,
 *      which runs while the token mints to it inside generateOrder.
 */
contract HookCaller {
    address internal _target;
    bytes internal _call;
    bool internal _catchRevert;

    /// @dev The revert data of the hook's call, when it was caught.
    bytes public lastError;

    function arm(address target, bytes calldata data, bool catchRevert)
        external
    {
        _target = target;
        _call = data;
        _catchRevert = catchRevert;
    }

    function run(address seaport, bytes calldata data) external {
        (bool ok, bytes memory ret) = seaport.call(data);
        if (!ok) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        _fire();
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external returns (bytes4) {
        _fire();
        return this.onERC1155BatchReceived.selector;
    }

    function _fire() internal {
        address target = _target;
        if (target == address(0)) return;
        _target = address(0);
        (bool ok, bytes memory ret) = target.call(_call);
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
contract MockSeaport {
    function generate(
        address token,
        address fulfiller,
        uint256 tokenId,
        address feeRecipient
    ) external {
        SpentItem[] memory minimumReceived = new SpentItem[](1);
        minimumReceived[0] = SpentItem({
            itemType: ItemType.ERC1155,
            token: token,
            identifier: tokenId,
            amount: 0
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
                    bytes20(address(0)), // minter: the fulfiller
                    bytes1(0x00) // public drop index 0
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
 * @dev The ERC1155 contract offerer mints in generateOrder, so the transfer
 *      Seaport makes for each offer item afterwards is a no-op. Seaport's
 *      recipient for it must be the fulfiller, or the minter when the call
 *      has only one. These tests cover that rule and the per-call mint
 *      record behind it.
 */
contract ERC1155SeaDropMintRecordTest is SeaDrop1155Test {
    address feeRecipient = makeAddr("feeRecipient");
    address creator = makeAddr("creator");
    address payer = makeAddr("payer");
    address minter = makeAddr("minter");
    address otherMinter = makeAddr("otherMinter");

    function setUp() public override {
        super.setUp();
        token = _deployTokenUnderTest();

        IERC1155SeaDrop(address(token))
            .updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(1, 10);
        token.setMaxSupply(2, 10);
        _setSingleCreatorPayout(address(token), creator);

        // A free public mint, so a mint order needs no consideration.
        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 0,
            endPrice: 0,
            startTime: uint40(vm.getBlockTimestamp()),
            endTime: uint40(vm.getBlockTimestamp() + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 2,
            maxTotalMintableByWallet: 5,
            maxTotalMintableByWalletPerToken: 5,
            feeBps: 0,
            restrictFeeRecipients: true
        });
        IERC1155SeaDrop(address(token)).updatePublicDrop(publicDrop, 0);
    }

    function testMintDeliveredToMinter() public {
        AdvancedOrder memory order = _mintOrder(minter, 1, 1);

        vm.prank(minter);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.balanceOf(minter, 1), 1);
    }

    function testMintDeliveredToThirdPartyReverts() public {
        address thirdParty = makeAddr("thirdParty");
        AdvancedOrder memory order = _mintOrder(minter, 1, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.InvalidRecipientOnlyMinterOrFulfiller
                    .selector,
                thirdParty
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
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);
        AdvancedOrder memory order = _mintOrder(minter, 1, 1);

        // A zero recipient makes Seaport deliver to the fulfiller (the payer).
        vm.prank(payer);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.balanceOf(minter, 1), 1);
        assertEq(token.balanceOf(payer, 1), 0);
    }

    function testPayerMintDeliveredToMinter() public {
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);
        AdvancedOrder memory order = _mintOrder(minter, 1, 1);

        vm.prank(payer);
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: minter
        });

        assertEq(token.balanceOf(minter, 1), 1);
    }

    function testPayerMintDeliveredToThirdPartyReverts() public {
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);
        address thirdParty = makeAddr("thirdParty");
        AdvancedOrder memory order = _mintOrder(minter, 1, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.InvalidRecipientOnlyMinterOrFulfiller
                    .selector,
                thirdParty
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

    function testPayerBatchForOneMinterDeliveredToMinter() public {
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);

        // Several mint orders for the same minter in one call, as when a mint
        // spans more than one drop stage, can still deliver to the minter.
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(minter, 1, 1);
        orders[1] = _mintOrder(minter, 2, 1);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter, 1), 1);
        assertEq(token.balanceOf(minter, 2), 1);
    }

    function testPayerBatchForTwoMintersDeliveredToPayer() public {
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(minter, 1, 1);
        orders[1] = _mintOrder(otherMinter, 2, 1);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), address(0));

        assertEq(token.balanceOf(minter, 1), 1);
        assertEq(token.balanceOf(otherMinter, 2), 1);
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
        IERC1155SeaDrop(address(token)).updatePayer(minter, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(minter, 1, 1);
        orders[1] = _mintOrder(otherMinter, 2, 1);

        vm.prank(minter);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter, 1), 1);
        assertEq(token.balanceOf(otherMinter, 2), 1);
    }

    function testSkippedMintOrderDoesNotJoinRecord() public {
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);

        // The first order is over the per-wallet limit, so its generateOrder
        // reverts and fulfillAvailable skips it. The call has one minter.
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(otherMinter, 1, 6);
        orders[1] = _mintOrder(minter, 1, 1);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter, 1), 1);
        assertEq(token.balanceOf(otherMinter, 1), 0);
    }

    function testSkippedMintOrderBetweenSameMinter() public {
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](3);
        orders[0] = _mintOrder(minter, 1, 1);
        orders[1] = _mintOrder(otherMinter, 1, 6);
        orders[2] = _mintOrder(minter, 2, 1);

        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);

        assertEq(token.balanceOf(minter, 1), 1);
        assertEq(token.balanceOf(minter, 2), 1);
    }

    function testConduitRoutedMintDeliveredToMinter() public {
        _setConduit(_conduitCodeTarget(), address(conduit));
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(address(0), 1, 1);
        orders[1] = _mintOrder(address(0), 2, 2);
        orders[0].parameters.conduitKey = conduitKeyOne;
        orders[1].parameters.conduitKey = conduitKeyOne;

        vm.prank(minter);
        _fulfillAvailable(orders, conduitKeyOne, minter);

        assertEq(token.balanceOf(minter, 1), 1);
        assertEq(token.balanceOf(minter, 2), 2);
    }

    function testConduitRoutedMintDeliveredToThirdPartyReverts() public {
        _setConduit(_conduitCodeTarget(), address(conduit));
        address thirdParty = makeAddr("thirdParty");
        AdvancedOrder[] memory orders = new AdvancedOrder[](1);
        orders[0] = _mintOrder(minter, 1, 1);
        orders[0].parameters.conduitKey = conduitKeyOne;

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.InvalidRecipientOnlyMinterOrFulfiller
                    .selector,
                thirdParty
            )
        );
        vm.prank(minter);
        _fulfillAvailable(orders, conduitKeyOne, thirdParty);
    }

    function testRecordClearedAfterRatify() public {
        AdvancedOrder memory order = _mintOrder(minter, 1, 1);
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
                ERC1155SeaDropErrorsAndEvents.InvalidRecipientOnlyMinterOrFulfiller
                    .selector,
                minter
            )
        );
        vm.prank(address(consideration));
        token.safeTransferFrom(address(token), minter, 1, 1, "");
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
        HookCaller caller = new HookCaller();
        address secondSeaport = deployCode(
            "optimized-out/Consideration.sol/Consideration.json",
            abi.encode(address(conduitController))
        );
        _allowSeaports(address(consideration), secondSeaport);

        // While the caller's mint has the record open, its receive hook fills
        // a mint order on the second allowed Seaport. That generateOrder
        // reverts with NestedSeaportCall, and Seaport 1.6 bubbles the token's
        // revert up through the outer fill.
        caller.arm(
            secondSeaport,
            abi.encodeCall(
                ConsiderationInterface.fulfillAdvancedOrder,
                (
                    _mintOrder(address(caller), 2, 1),
                    new CriteriaResolver[](0),
                    bytes32(0),
                    address(0)
                )
            ),
            false
        );
        bytes memory outerFill = abi.encodeCall(
            ConsiderationInterface.fulfillAdvancedOrder,
            (
                _mintOrder(address(caller), 1, 1),
                new CriteriaResolver[](0),
                bytes32(0),
                address(0)
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.NestedSeaportCall.selector,
                secondSeaport
            )
        );
        caller.run(address(consideration), outerFill);
    }

    function testGenerateFromAnotherSeaportRevertsWhileRecordOpen() public {
        HookCaller caller = new HookCaller();
        MockSeaport mock = new MockSeaport();
        _allowSeaports(address(consideration), address(mock));

        // During the caller's own mint, the other allowed Seaport generates an
        // order for another fulfiller. Catch the revert so the outer mint can
        // finish and the error can be checked.
        caller.arm(
            address(mock),
            abi.encodeCall(
                MockSeaport.generate,
                (address(token), otherMinter, 2, feeRecipient)
            ),
            true
        );
        caller.run(
            address(consideration),
            abi.encodeCall(
                ConsiderationInterface.fulfillAdvancedOrder,
                (
                    _mintOrder(address(0), 1, 1),
                    new CriteriaResolver[](0),
                    bytes32(0),
                    address(0)
                )
            )
        );

        assertEq(
            caller.lastError(),
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.NestedSeaportCall.selector,
                address(mock)
            )
        );
        assertEq(token.balanceOf(address(caller), 1), 1);
    }

    function testRatifyFromAnotherSeaportKeepsRecord() public {
        HookCaller caller = new HookCaller();
        MockSeaport mock = new MockSeaport();
        _allowSeaports(address(consideration), address(mock));
        IERC1155SeaDrop(address(token)).updatePayer(address(caller), true);

        // The caller mints for itself and for otherMinter, so the call has
        // two minters. A ratifyOrder from the other allowed Seaport mid-call
        // leaves the record alone, so delivery to otherMinter still reverts.
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[0] = _mintOrder(address(caller), 1, 1);
        orders[1] = _mintOrder(otherMinter, 2, 1);
        caller.arm(
            address(mock),
            abi.encodeCall(MockSeaport.ratify, (address(token))),
            false
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.InvalidRecipientOnlyMinterOrFulfiller
                    .selector,
                otherMinter
            )
        );
        caller.run(
            address(consideration),
            abi.encodeCall(
                ConsiderationInterface.fulfillAvailableAdvancedOrders,
                (
                    orders,
                    new CriteriaResolver[](0),
                    _offerFulfillments(2),
                    new FulfillmentComponent[][](0),
                    bytes32(0),
                    otherMinter,
                    2
                )
            )
        );
    }

    /// @dev An allowed payer batch-mints for two minters in either order and
    ///      names one of them as the recipient, which is neither the
    ///      fulfiller nor the call's only minter.
    function _assertTwoMinterBatchToMinterReverts(bool minterFirst) internal {
        IERC1155SeaDrop(address(token)).updatePayer(payer, true);
        AdvancedOrder[] memory orders = new AdvancedOrder[](2);
        orders[minterFirst ? 0 : 1] = _mintOrder(minter, 1, 1);
        orders[minterFirst ? 1 : 0] = _mintOrder(otherMinter, 2, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropErrorsAndEvents.InvalidRecipientOnlyMinterOrFulfiller
                    .selector,
                minter
            )
        );
        vm.prank(payer);
        _fulfillAvailable(orders, bytes32(0), minter);
    }

    /// @dev Deploys the token the tests run against.
    function _deployTokenUnderTest() internal virtual returns (ERC1155SeaDrop) {
        return _deployToken();
    }

    /// @dev Where the conduit address the token accepts is compiled in.
    function _conduitCodeTarget() internal virtual returns (address) {
        return address(token);
    }

    /// @dev A free public mint order for quantity of tokenId to minter_.
    function _mintOrder(address minter_, uint256 tokenId, uint256 quantity)
        internal
        view
        returns (AdvancedOrder memory order)
    {
        (order,) = _publicMintOrder(
            address(token), tokenId, quantity, feeRecipient, 0, 0, minter_, 0
        );
    }

    /// @dev Fulfills every order, each offer item in its own fulfillment.
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

/**
 * @dev Runs the same tests against a clone, which uses
 *      ERC1155SeaDropContractOffererCloneable.
 */
contract ERC1155SeaDropCloneableMintRecordTest is ERC1155SeaDropMintRecordTest {
    ERC1155SeaDropCloneFactory internal factory;

    function _deployTokenUnderTest()
        internal
        override
        returns (ERC1155SeaDrop)
    {
        factory = new ERC1155SeaDropCloneFactory(address(consideration));
        return ERC1155SeaDrop(factory.createClone("", "", bytes32("1")));
    }

    function _conduitCodeTarget() internal view override returns (address) {
        return factory.cloneableImplementation();
    }
}
