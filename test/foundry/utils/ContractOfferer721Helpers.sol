// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./SeaDrop721Test.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

import {
    AdvancedOrder,
    ConsiderationItem,
    OfferItem,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import { Vm } from "forge-std/Vm.sol";

/**
 * @dev Shared setup and helpers for the ERC721SeaDropContractOfferer Forge
 *      tests, ported from test/ERC721SeaDropContractOfferer.spec.ts and its
 *      helpers in test/utils (order.ts, helpers.ts).
 */
abstract contract ERC721SeaDropContractOffererHelpers is SeaDrop721Test {
    /// @dev The OpenSea conduit address hardcoded in the token
    ///      (`openseaConduitAddress` in test/utils/helpers.ts).
    address internal constant _OPENSEA_CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /// @dev The drop stage index emitted for public mints.
    uint256 internal constant _PUBLIC_DROP_STAGE_INDEX = 0;

    /// @dev SIP-12 substandard for a public mint (`MintType.PUBLIC`).
    uint8 internal constant _MINT_TYPE_PUBLIC = 0;

    /// @dev The allow list merkle root used by the spec's `allowListData`.
    bytes32 internal constant _ALLOW_LIST_MERKLE_ROOT =
        0x3333333333333333333333333333333333333333333333333333333333333333;

    // Wallets
    address internal owner;
    address internal creator;
    address internal minter;
    uint256 internal minterPk;
    address internal feeRecipient;

    /// @dev The default public drop configured in setUp (`publicDrop`).
    PublicDrop internal publicDrop;

    /// @dev The beforeEach of the spec: deploy the token from `owner`, then
    ///      set max supply 5, the public drop, an allowed fee recipient and a
    ///      single creator payout.
    function setUp() public virtual override {
        super.setUp();

        // The spec's drop times are relative to wall clock time.
        vm.warp(1_700_000_000);

        owner = makeAddr("owner");
        creator = makeAddr("creator");
        (minter, minterPk) = makeAddrAndKey("minter");
        feeRecipient = makeAddr("feeRecipient");

        // Add eth to wallets.
        vm.deal(owner, 100 ether);
        vm.deal(minter, 100 ether);
        vm.deal(creator, 100 ether);
        vm.deal(feeRecipient, 100 ether);

        token = _deployToken(address(configurer));

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

        vm.startPrank(owner);
        token.setMaxSupply(5);
        _seaDrop().updatePublicDrop(publicDrop);
        _seaDrop().updateAllowedFeeRecipient(feeRecipient, true);
        _seaDrop().updateCreatorPayouts(_singlePayout(creator, 10_000));
        vm.stopPrank();
    }

    /**
     * Deployment and configuration
     */
    function _deployToken(address configurer_)
        internal
        returns (ERC721SeaDrop deployed)
    {
        vm.prank(owner);
        deployed =
            new ERC721SeaDrop(configurer_, allowedSeaport, "Test721", "T721");
    }

    function _seaDrop() internal view returns (IERC721SeaDrop) {
        return IERC721SeaDrop(address(token));
    }

    function _allowListData() internal pure returns (AllowListData memory) {
        return AllowListData({
            merkleRoot: _ALLOW_LIST_MERKLE_ROOT,
            publicKeyURIs: new string[](0),
            allowListURI: ""
        });
    }

    function _singlePayout(address payoutAddress, uint16 basisPoints)
        internal
        pure
        returns (CreatorPayout[] memory payouts)
    {
        payouts = new CreatorPayout[](1);
        payouts[0] = CreatorPayout(payoutAddress, basisPoints);
    }

    function _addrs(address a) internal pure returns (address[] memory r) {
        r = new address[](1);
        r[0] = a;
    }

    function _addrs(address a, address b)
        internal
        pure
        returns (address[] memory r)
    {
        r = new address[](2);
        r[0] = a;
        r[1] = b;
    }

    function _addrs(address a, address b, address c, address d)
        internal
        pure
        returns (address[] memory r)
    {
        r = new address[](4);
        r[0] = a;
        r[1] = b;
        r[2] = c;
        r[3] = d;
    }

    /**
     * Mint orders (createMintOrder in test/utils/order.ts)
     */

    /**
     * @dev Build a SeaDrop public mint order with the token as a contract
     *      offerer, mirroring `createMintOrder` for `MintType.PUBLIC`.
     *      The minimum received is an ERC1155 offer item for the token with
     *      the quantity as amount. The consideration is the fee recipient's
     *      cut (if non-zero) and each creator payout (if non-zero).
     */
    function _createMintOrder(
        address tokenAddress,
        uint256 tokenId,
        uint256 quantity,
        address feeRecipient_,
        uint256 feeBps,
        uint256 price,
        address paymentToken,
        address minter_
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC1155,
            token: tokenAddress,
            identifierOrCriteria: tokenId,
            startAmount: quantity,
            endAmount: quantity
        });

        value = price * quantity;

        ConsiderationItem[] memory items = _mintConsideration(
            tokenAddress, feeRecipient_, feeBps, value, paymentToken
        );

        order = AdvancedOrder({
            parameters: OrderParameters({
                offerer: tokenAddress,
                zone: address(0),
                offer: offer,
                consideration: items,
                orderType: OrderType.CONTRACT,
                startTime: vm.getBlockTimestamp() - 1000,
                endTime: vm.getBlockTimestamp() + 1000,
                zoneHash: bytes32(0),
                salt: 0,
                conduitKey: bytes32(0),
                totalOriginalConsiderationItems: items.length
            }),
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: abi.encodePacked(
                bytes1(0x00), // SIP-6 version byte
                bytes1(_MINT_TYPE_PUBLIC), // substandard version byte
                bytes20(feeRecipient_),
                bytes20(minter_)
            )
        });
    }

    function _mintConsideration(
        address tokenAddress,
        address feeRecipient_,
        uint256 feeBps,
        uint256 value,
        address paymentToken
    ) internal view returns (ConsiderationItem[] memory items) {
        uint256 feeAmount = (value * feeBps) / 10_000;
        uint256 creatorAmount = value - feeAmount;
        ItemType itemType =
            paymentToken == address(0) ? ItemType.NATIVE : ItemType.ERC20;

        CreatorPayout[] memory creatorPayouts =
            IERC721SeaDrop(tokenAddress).getCreatorPayouts();

        items = new ConsiderationItem[](
            (feeAmount > 0 ? 1 : 0)
                + (creatorAmount > 0 ? creatorPayouts.length : 0)
        );

        uint256 index;
        if (feeAmount > 0) {
            items[index++] = ConsiderationItem({
                itemType: itemType,
                token: paymentToken,
                identifierOrCriteria: 0,
                startAmount: feeAmount,
                endAmount: feeAmount,
                recipient: payable(feeRecipient_)
            });
        }

        if (creatorAmount > 0) {
            for (uint256 i = 0; i < creatorPayouts.length; i++) {
                uint256 amount =
                    (creatorAmount * creatorPayouts[i].basisPoints) / 10_000;
                items[index++] = ConsiderationItem({
                    itemType: itemType,
                    token: paymentToken,
                    identifierOrCriteria: 0,
                    startAmount: amount,
                    endAmount: amount,
                    recipient: payable(creatorPayouts[i].payoutAddress)
                });
            }
        }
    }

    /// @dev `expectedPrice` in test/utils/order.ts (rounds down).
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

    /// @dev Fulfill a mint order as `minter` through Seaport.
    ///      Makes no external call before the fulfillment, so it can follow
    ///      `vm.expectRevert` / `vm.expectEmit`.
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

    /// @dev The order hash Seaport derives for the next contract order of
    ///      `offerer`, as used in `InvalidContractOrder(bytes32)`.
    function _contractOrderHash(address offerer)
        internal
        view
        returns (bytes32)
    {
        return bytes32(
            (uint256(uint160(offerer)) << 96)
                ^ consideration.getContractOffererNonce(offerer)
        );
    }

    /// @dev Expect Seaport to revert the next contract order of `offerer`
    ///      with `InvalidContractOrder(orderHash)`.
    function _expectInvalidContractOrder(address offerer) internal {
        bytes32 orderHash = _contractOrderHash(offerer);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
    }

    /// @dev Call `previewOrder` on the order's offerer with the arguments
    ///      Seaport derives from the order, so the underlying SeaDrop error
    ///      that Seaport wraps in `InvalidContractOrder` can be asserted.
    function _previewOrder(AdvancedOrder memory order, address fulfiller)
        internal
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration_)
    {
        return ContractOffererInterface(order.parameters.offerer)
            .previewOrder(
                address(consideration),
                fulfiller,
                _offerToSpentItems(order.parameters.offer),
                _considerationToSpentItems(order.parameters.consideration),
                order.extraData
            );
    }

    function _offerToSpentItems(OfferItem[] memory offer)
        internal
        pure
        returns (SpentItem[] memory spentItems)
    {
        spentItems = new SpentItem[](offer.length);
        for (uint256 i = 0; i < offer.length; i++) {
            spentItems[i] = SpentItem({
                itemType: offer[i].itemType,
                token: offer[i].token,
                identifier: offer[i].identifierOrCriteria,
                amount: offer[i].startAmount
            });
        }
    }

    function _considerationToSpentItems(ConsiderationItem[] memory items)
        internal
        pure
        returns (SpentItem[] memory spentItems)
    {
        spentItems = new SpentItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            spentItems[i] = SpentItem({
                itemType: items[i].itemType,
                token: items[i].token,
                identifier: items[i].identifierOrCriteria,
                amount: items[i].startAmount
            });
        }
    }

    /**
     * Misc
     */

    /// @dev `setConduit` in test/utils/helpers.ts: rewrite the token's
    ///      runtime code so the hardcoded OpenSea conduit address points at
    ///      `newConduit`. The TS helper uses String.replace, which only
    ///      swaps the first occurrence; this swaps every occurrence.
    function _setConduit(address target, address newConduit) internal {
        bytes memory code = target.code;
        bytes20 replacement = bytes20(newConduit);
        uint256 replaced;
        for (uint256 i = 0; i + 20 <= code.length; i++) {
            address word;
            assembly {
                word := shr(96, mload(add(add(code, 0x20), i)))
            }
            if (word == _OPENSEA_CONDUIT) {
                for (uint256 j = 0; j < 20; j++) {
                    code[i + j] = replacement[j];
                }
                replaced++;
                i += 19;
            }
        }
        assertGt(replaced, 0, "conduit address not found in code");
        vm.etch(target, code);
    }

    /// @dev Count recorded logs from `emitter` with the given topics.
    function _countLogs(
        Vm.Log[] memory logs,
        address emitter,
        bytes32[] memory topics
    ) internal pure returns (uint256 count) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].emitter != emitter
                    || logs[i].topics.length < topics.length
            ) {
                continue;
            }
            bool matches = true;
            for (uint256 j = 0; j < topics.length; j++) {
                if (logs[i].topics[j] != topics[j]) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                count++;
            }
        }
    }
}
