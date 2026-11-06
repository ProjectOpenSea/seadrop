// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { DelegationRegistry } from "seadrop/test/DelegationRegistry.sol";

import {
    IDelegationRegistry
} from "seadrop/interfaces/IDelegationRegistry.sol";

import { ISeaDropToken } from "seadrop/interfaces/ISeaDropToken.sol";

import { AllowListData, CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import {
    ConduitControllerInterface
} from "seaport-types/src/interfaces/ConduitControllerInterface.sol";

import {
    ConduitInterface
} from "seaport-types/src/interfaces/ConduitInterface.sol";

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
    OfferItem,
    OrderComponents,
    OrderParameters,
    ReceivedItem,
    SpentItem
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import {
    ItemType,
    OrderType
} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ZoneInteractionErrors
} from "../../../lib/seaport/contracts/interfaces/ZoneInteractionErrors.sol";

import { Test } from "forge-std/Test.sol";

import { Vm } from "forge-std/Vm.sol";

import { Merkle } from "murky/Merkle.sol";

/**
 * @dev Token-agnostic base for the SeaDrop Forge tests: Seaport deployment,
 *      the delegation registry, contract order plumbing (consideration
 *      items, fulfillment, previewOrder, the InvalidContractOrder wrapper),
 *      signing, merkle proofs and small array helpers. SeaDrop721Test and
 *      SeaDrop1155Test add the token-specific order building on top.
 *
 *      Seaport is deployed from the artifacts `scripts/build_seaport.sh`
 *      builds, so the tests never compile Seaport's sources (which don't
 *      compile without the optimizer, as `forge coverage` needs).
 */
abstract contract SeaDropTest is
    Test,
    SeaDropErrorsAndEvents,
    ZoneInteractionErrors
{
    /// @dev SIP-12 substandards.
    uint8 internal constant MINT_TYPE_PUBLIC = 0;
    uint8 internal constant MINT_TYPE_ALLOW_LIST = 1;
    uint8 internal constant MINT_TYPE_SIGNED = 2;

    /// @dev The drop stage index emitted for 721 public mints.
    uint256 internal constant PUBLIC_DROP_STAGE_INDEX = 0;

    /// @dev The canonical DelegationRegistry, etched in setUp.
    IDelegationRegistry internal constant DELEGATION_REGISTRY =
        IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);

    /// @dev The OpenSea conduit the tokens preapprove and accept as a caller.
    address internal constant OPENSEA_CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /// @dev Start at a realistic timestamp so stages can start in the past.
    uint256 internal constant START_TIMESTAMP = 1_700_000_000;

    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,"
        "address verifyingContract)"
    );
    bytes32 internal constant _VERSION_HASH = keccak256("2.0");

    /// @dev Seaport, its conduit controller, and a conduit owned by this
    ///      contract under `conduitKeyOne`, open to Seaport.
    ConsiderationInterface internal consideration;
    ConduitControllerInterface internal conduitController;
    ConduitInterface internal conduit;
    bytes32 internal conduitKeyOne;

    /// @dev An account with no role on the tokens.
    address internal bob = makeAddr("bob");

    /// @dev The Seaport the tokens allow.
    address internal allowedSeaport;

    /// @dev SeaDrop doesn't use criteria resolvers.
    CriteriaResolver[] internal criteriaResolvers;

    function setUp() public virtual {
        conduitController = ConduitControllerInterface(
            deployCode(
                "optimized-out/ConduitController.sol/ConduitController.json"
            )
        );
        consideration = ConsiderationInterface(
            deployCode(
                "optimized-out/Consideration.sol/Consideration.json",
                abi.encode(address(conduitController))
            )
        );
        conduitKeyOne = bytes32(uint256(uint160(address(this))) << 96);
        address conduitAddress =
            conduitController.createConduit(conduitKeyOne, address(this));
        conduit = ConduitInterface(conduitAddress);
        conduitController.updateChannel(
            conduitAddress, address(consideration), true
        );
        vm.label(address(consideration), "consideration");
        vm.label(conduitAddress, "conduit");

        allowedSeaport = address(consideration);

        // Deploy the DelegationRegistry to its canonical address.
        vm.etch(
            address(DELEGATION_REGISTRY), address(new DelegationRegistry()).code
        );

        vm.warp(START_TIMESTAMP);
    }

    /**
     * Creator payouts and allow lists
     */
    function _payouts(address a, uint256 aBps)
        internal
        pure
        returns (CreatorPayout[] memory payouts)
    {
        payouts = new CreatorPayout[](1);
        payouts[0] = CreatorPayout(a, uint16(aBps));
    }

    function _payouts(address a, uint256 aBps, address b, uint256 bBps)
        internal
        pure
        returns (CreatorPayout[] memory payouts)
    {
        payouts = new CreatorPayout[](2);
        payouts[0] = CreatorPayout(a, uint16(aBps));
        payouts[1] = CreatorPayout(b, uint16(bBps));
    }

    function _payouts(
        address a,
        uint256 aBps,
        address b,
        uint256 bBps,
        address c,
        uint256 cBps
    ) internal pure returns (CreatorPayout[] memory payouts) {
        payouts = new CreatorPayout[](3);
        payouts[0] = CreatorPayout(a, uint16(aBps));
        payouts[1] = CreatorPayout(b, uint16(bBps));
        payouts[2] = CreatorPayout(c, uint16(cBps));
    }

    function _setSingleCreatorPayout(address tokenAddress, address creator)
        internal
    {
        ISeaDropToken(tokenAddress)
            .updateCreatorPayouts(_payouts(creator, 10_000));
    }

    function _allowListData(bytes32 root)
        internal
        pure
        returns (AllowListData memory)
    {
        return AllowListData({
            merkleRoot: root,
            publicKeyURIs: new string[](0),
            allowListURI: ""
        });
    }

    function _updateAllowList(address tokenAddress, bytes32 root) internal {
        ISeaDropToken(tokenAddress).updateAllowList(_allowListData(root));
    }

    /// @dev The merkle root of `leaves` and the proof for `leaves[index]`.
    ///      Murky does not build single-leaf trees, so a lone leaf is its own
    ///      root with an empty proof.
    function _merkleRootAndProof(bytes32[] memory leaves, uint256 index)
        internal
        returns (bytes32 root, bytes32[] memory proof)
    {
        require(index < leaves.length, "proof index out of range");
        if (leaves.length == 1) {
            return (leaves[0], new bytes32[](0));
        }
        Merkle m = new Merkle();
        root = m.getRoot(leaves);
        proof = m.getProof(leaves, index);
        assertTrue(m.verifyProof(root, proof, leaves[index]));
    }

    /**
     * Contract orders
     */

    /// @dev A CONTRACT order from `tokenAddress`, valid from now - 1000 to
    ///      now + 1000.
    function _contractOrder(
        address tokenAddress,
        OfferItem[] memory offer,
        ConsiderationItem[] memory items,
        bytes memory extraData
    ) internal view returns (AdvancedOrder memory) {
        return AdvancedOrder({
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
            extraData: extraData
        });
    }

    /// @dev The fee recipient's cut (only when non-zero), then each creator
    ///      payout (only when the creator amount is non-zero).
    function _mintConsideration(
        address tokenAddress,
        address feeRecipient,
        uint256 feeBps,
        uint256 value,
        address paymentToken
    ) internal view returns (ConsiderationItem[] memory items) {
        uint256 feeAmount = (value * feeBps) / 10_000;
        uint256 creatorAmount = value - feeAmount;
        ItemType itemType =
            paymentToken == address(0) ? ItemType.NATIVE : ItemType.ERC20;

        CreatorPayout[] memory creatorPayouts =
            ISeaDropToken(tokenAddress).getCreatorPayouts();

        items = new ConsiderationItem[](
            (feeAmount != 0 ? 1 : 0)
                + (creatorAmount != 0 ? creatorPayouts.length : 0)
        );

        uint256 index;
        if (feeAmount != 0) {
            items[index++] = ConsiderationItem({
                itemType: itemType,
                token: paymentToken,
                identifierOrCriteria: 0,
                startAmount: feeAmount,
                endAmount: feeAmount,
                recipient: payable(feeRecipient)
            });
        }
        if (creatorAmount != 0) {
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

    /// @dev The current price of a stage, rounded down.
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
     * Fulfillment and assertions
     */

    /// @dev Fulfill `order` through Seaport as `fulfiller`. Makes no external
    ///      call before the fulfillment, so it can follow `vm.expectRevert`
    ///      or `vm.expectEmit`.
    function _fulfill(
        AdvancedOrder memory order,
        address fulfiller,
        uint256 value
    ) internal {
        _fulfill(order, fulfiller, value, bytes32(0));
    }

    function _fulfill(
        AdvancedOrder memory order,
        address fulfiller,
        uint256 value,
        bytes32 fulfillerConduitKey
    ) internal {
        vm.prank(fulfiller);
        consideration.fulfillAdvancedOrder{ value: value }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: fulfillerConduitKey,
            recipient: address(0)
        });
    }

    /// @dev Fulfill and expect SeaDropMint(payer, dropStageIndex).
    function _fulfillAndExpectMint(
        AdvancedOrder memory order,
        address fulfiller,
        uint256 value,
        uint256 dropStageIndex
    ) internal {
        vm.expectEmit(true, true, true, true, order.parameters.offerer);
        emit SeaDropMint(fulfiller, dropStageIndex);
        _fulfill(order, fulfiller, value);
    }

    /// @dev The order hash Seaport derives for the next contract order of
    ///      `offerer`, as used in InvalidContractOrder(bytes32).
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
    ///      with InvalidContractOrder(orderHash).
    function _expectInvalidContractOrder(address offerer) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector, _contractOrderHash(offerer)
            )
        );
    }

    /// @dev The minimumReceived and maximumSpent Seaport derives from the
    ///      order and passes to the contract offerer.
    function _previewItems(AdvancedOrder memory order)
        internal
        pure
        returns (
            SpentItem[] memory minimumReceived,
            SpentItem[] memory maximumSpent
        )
    {
        OfferItem[] memory offer = order.parameters.offer;
        minimumReceived = new SpentItem[](offer.length);
        for (uint256 i = 0; i < offer.length; i++) {
            minimumReceived[i] = SpentItem({
                itemType: offer[i].itemType,
                token: offer[i].token,
                identifier: offer[i].identifierOrCriteria,
                amount: offer[i].endAmount
            });
        }

        ConsiderationItem[] memory items = order.parameters.consideration;
        maximumSpent = new SpentItem[](items.length);
        for (uint256 i = 0; i < items.length; i++) {
            maximumSpent[i] = SpentItem({
                itemType: items[i].itemType,
                token: items[i].token,
                identifier: items[i].identifierOrCriteria,
                amount: items[i].endAmount
            });
        }
    }

    /// @dev Call previewOrder on the order's offerer with the arguments
    ///      Seaport would pass to generateOrder.
    function _previewOrder(AdvancedOrder memory order, address fulfiller)
        internal
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory received)
    {
        (SpentItem[] memory minimumReceived, SpentItem[] memory maximumSpent) =
            _previewItems(order);
        return ContractOffererInterface(order.parameters.offerer)
            .previewOrder(
                address(consideration),
                fulfiller,
                minimumReceived,
                maximumSpent,
                order.extraData
            );
    }

    /// @dev Assert that previewOrder for `order` reverts with `reason`.
    ///      Seaport wraps the same generateOrder revert in
    ///      InvalidContractOrder, so this is how the tests see the SeaDrop
    ///      error behind a failed fulfillment.
    function _expectPreviewRevert(
        AdvancedOrder memory order,
        address fulfiller,
        bytes memory reason
    ) internal view {
        (SpentItem[] memory minimumReceived, SpentItem[] memory maximumSpent) =
            _previewItems(order);
        (bool success, bytes memory returnData) = order.parameters.offerer
            .staticcall(
                abi.encodeCall(
                    ContractOffererInterface.previewOrder,
                    (
                        address(consideration),
                        fulfiller,
                        minimumReceived,
                        maximumSpent,
                        order.extraData
                    )
                )
            );
        assertFalse(success, "previewOrder should revert");
        assertEq(returnData, reason, "unexpected previewOrder revert reason");
    }

    /// @dev Assert that previewOrder reverts with `reason` and that
    ///      fulfilling the order through Seaport reverts with
    ///      InvalidContractOrder.
    function _assertMintReverts(
        AdvancedOrder memory order,
        address fulfiller,
        uint256 value,
        bytes memory reason
    ) internal {
        _expectPreviewRevert(order, fulfiller, reason);
        _expectInvalidContractOrder(order.parameters.offerer);
        _fulfill(order, fulfiller, value);
    }

    /// @dev Assert that previewOrder, called by the fulfiller with a zero
    ///      caller, returns the order's own offer and consideration
    ///      (recipients included).
    function _assertPreviewOrderMatches(
        AdvancedOrder memory order,
        address fulfiller
    ) internal {
        (SpentItem[] memory minimumReceived, SpentItem[] memory maximumSpent) =
            _previewItems(order);

        vm.prank(fulfiller);
        (SpentItem[] memory offer, ReceivedItem[] memory received) = ContractOffererInterface(
                order.parameters.offerer
            )
            .previewOrder(
                address(0),
                fulfiller,
                minimumReceived,
                maximumSpent,
                order.extraData
            );

        assertEq(offer.length, minimumReceived.length);
        for (uint256 i = 0; i < offer.length; i++) {
            assertEq(
                uint256(offer[i].itemType), uint256(minimumReceived[i].itemType)
            );
            assertEq(offer[i].token, minimumReceived[i].token);
            assertEq(offer[i].identifier, minimumReceived[i].identifier);
            assertEq(offer[i].amount, minimumReceived[i].amount);
        }

        ConsiderationItem[] memory items = order.parameters.consideration;
        assertEq(received.length, maximumSpent.length);
        for (uint256 i = 0; i < received.length; i++) {
            assertEq(
                uint256(received[i].itemType), uint256(maximumSpent[i].itemType)
            );
            assertEq(received[i].token, maximumSpent[i].token);
            assertEq(received[i].identifier, maximumSpent[i].identifier);
            assertEq(received[i].amount, maximumSpent[i].amount);
            assertEq(received[i].recipient, items[i].recipient);
        }
    }

    /**
     * Signing
     */
    function _domainSeparator(bytes32 nameHash, address tokenAddress)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                nameHash,
                _VERSION_HASH,
                block.chainid,
                tokenAddress
            )
        );
    }

    /// @dev Sign `digest` with `signerName`'s key, check it recovers, and
    ///      return the EIP-2098 compact signature the tokens expect.
    function _signDigest(string memory signerName, bytes32 digest)
        internal
        returns (bytes memory signature)
    {
        (address signer, uint256 pk) = makeAddrAndKey(signerName);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        assertEq(ecrecover(digest, v, r, s), signer);
        uint256 yParityAndS = (uint256(v == 27 ? 0 : 1) << 255) | uint256(s);
        signature = abi.encodePacked(r, yParityAndS);
    }

    /// @dev Sign a Seaport order hash with `pk` (65-byte signature).
    function signOrder(
        ConsiderationInterface seaport,
        uint256 pk,
        bytes32 orderHash
    ) internal view returns (bytes memory) {
        (, bytes32 domainSeparator,) = seaport.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            pk,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, orderHash)
            )
        );
        return abi.encodePacked(r, s, v);
    }

    function toOrderComponents(
        OrderParameters memory parameters,
        uint256 counter
    ) internal pure returns (OrderComponents memory) {
        return OrderComponents({
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
            counter: counter
        });
    }

    /**
     * Receivers, so tests can pay, mint and transfer to this contract.
     */
    receive() external payable { }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /**
     * Misc
     */

    /// @dev Rewrite every occurrence of the OpenSea conduit address in
    ///      `target`'s runtime code with `newConduit`.
    function _setConduit(address target, address newConduit) internal {
        bytes memory code = target.code;
        bytes20 replacement = bytes20(newConduit);
        uint256 replaced;
        for (uint256 i = 0; i + 20 <= code.length; i++) {
            address word;
            assembly {
                word := shr(96, mload(add(add(code, 0x20), i)))
            }
            if (word == OPENSEA_CONDUIT) {
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

    /// @dev Count recorded logs from `emitter` whose leading topics match.
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

    /// @dev `data[start:end]` for memory bytes.
    function _slice(bytes memory data, uint256 start, uint256 end)
        internal
        pure
        returns (bytes memory result)
    {
        result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = data[i];
        }
    }

    function _uints(uint256 a) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = a;
    }

    function _uints(uint256 a, uint256 b)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _uints(uint256 a, uint256 b, uint256 c)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    function _uints(uint256 a, uint256 b, uint256 c, uint256 d)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
    }

    function _addrs(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }

    function _addrs(address a, address b)
        internal
        pure
        returns (address[] memory arr)
    {
        arr = new address[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _addrs(address a, address b, address c, address d)
        internal
        pure
        returns (address[] memory arr)
    {
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
    ) internal pure {
        assertEq(a.length, b.length, err);
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i], b[i], err);
        }
    }

    function _assertEq(CreatorPayout[] memory a, CreatorPayout[] memory b)
        internal
        pure
    {
        assertEq(a.length, b.length, "creator payouts length");
        for (uint256 i = 0; i < a.length; i++) {
            assertEq(a[i].payoutAddress, b[i].payoutAddress, "payoutAddress");
            assertEq(a[i].basisPoints, b[i].basisPoints, "basisPoints");
        }
    }
}
