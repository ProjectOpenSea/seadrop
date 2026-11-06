// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./SeaDrop1155Test.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

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

import { ECDSA } from "solady/src/utils/ECDSA.sol";

/**
 * @dev Helpers shared by the Forge ports of the ERC1155 Hardhat specs.
 *      They mirror test/utils/order.ts (createMintOrder),
 *      test/utils/helpers.ts (deployERC1155SeaDrop, mintTokens) and
 *      test/utils/allow-list.ts (createAllowListAndGetProof).
 */
contract SeaDrop1155MintHelpers is SeaDrop1155Test {
    /// @dev Mirrors MintType in test/utils/order.ts.
    uint8 internal constant MINT_TYPE_PUBLIC = 0;
    uint8 internal constant MINT_TYPE_ALLOW_LIST = 1;
    uint8 internal constant MINT_TYPE_SIGNED = 2;

    /// @dev Mirrors openseaConduitAddress in test/utils/helpers.ts.
    address internal constant OPENSEA_CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /// @dev The canonical DelegationRegistry, etched in SeaDrop1155Test.
    address internal constant DELEGATION_REGISTRY =
        0x00000000000076A84feF008CDAbe6409d2FE638B;

    /// @dev The Hardhat specs use times relative to Date.now(), e.g.
    ///      `now - 1000`. Start from a realistic timestamp so that does
    ///      not underflow.
    uint256 internal constant START_TIMESTAMP = 1_700_000_000;

    /// @dev Arguments for _createMintOrder, mirroring createMintOrder.
    struct MintOrderArgs {
        address token;
        uint256[] tokenIds;
        uint256[] quantities;
        address feeRecipient;
        uint256 feeBps;
        uint256 price;
        address minter;
        uint8 mintType;
        // Substandard-specific bytes appended after feeRecipient and minter.
        bytes mintTypeData;
    }

    function setUp() public virtual override {
        super.setUp();
        vm.warp(START_TIMESTAMP);
    }

    /**
     * Deployment
     */

    /// @dev Mirrors deployERC1155SeaDrop. The test contract is the owner.
    function _deployERC1155SeaDrop() internal returns (ERC1155SeaDrop) {
        return new ERC1155SeaDrop(
            address(configurer), allowedSeaport, "Test1155", "T1155"
        );
    }

    function _setSingleCreatorPayout(address tokenAddress, address creator)
        internal
    {
        CreatorPayout[] memory creatorPayouts = new CreatorPayout[](1);
        creatorPayouts[0] =
            CreatorPayout({ payoutAddress: creator, basisPoints: 10_000 });
        IERC1155SeaDrop(tokenAddress).updateCreatorPayouts(creatorPayouts);
    }

    function _setTwoCreatorPayouts(address first, address second) internal {
        CreatorPayout[] memory creatorPayouts = new CreatorPayout[](2);
        creatorPayouts[0] =
            CreatorPayout({ payoutAddress: first, basisPoints: 5_000 });
        creatorPayouts[1] =
            CreatorPayout({ payoutAddress: second, basisPoints: 5_000 });
        IERC1155SeaDrop(address(token)).updateCreatorPayouts(creatorPayouts);
    }

    /**
     * Order building
     */

    /// @dev Mirrors createMintOrder in test/utils/order.ts: the fee item is
    ///      only added when the fee is nonzero, creator items only when the
    ///      creator amount is nonzero, and the order is valid from
    ///      now - 1000 to now + 1000.
    function _createMintOrder(MintOrderArgs memory args)
        internal
        view
        returns (AdvancedOrder memory order, uint256 value)
    {
        uint256 numItems = args.tokenIds.length;
        OfferItem[] memory offer = new OfferItem[](numItems);
        uint256 totalQuantity;
        for (uint256 i = 0; i < numItems; i++) {
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
        uint256 feeAmount = (value * args.feeBps) / 10_000;
        uint256 creatorAmount = value - feeAmount;

        CreatorPayout[] memory creatorPayouts =
            IERC1155SeaDrop(args.token).getCreatorPayouts();
        uint256 numConsideration = (feeAmount > 0 ? 1 : 0)
            + (creatorAmount > 0 ? creatorPayouts.length : 0);
        ConsiderationItem[] memory considerationItems =
            new ConsiderationItem[](numConsideration);
        uint256 index;
        if (feeAmount > 0) {
            considerationItems[index++] = ConsiderationItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: feeAmount,
                endAmount: feeAmount,
                recipient: payable(args.feeRecipient)
            });
        }
        if (creatorAmount > 0) {
            for (uint256 i = 0; i < creatorPayouts.length; i++) {
                uint256 amount =
                    (creatorAmount * creatorPayouts[i].basisPoints) / 10_000;
                considerationItems[index++] = ConsiderationItem({
                    itemType: ItemType.NATIVE,
                    token: address(0),
                    identifierOrCriteria: 0,
                    startAmount: amount,
                    endAmount: amount,
                    recipient: payable(creatorPayouts[i].payoutAddress)
                });
            }
        }

        order.parameters = OrderParameters({
            offerer: args.token,
            zone: address(0),
            offer: offer,
            consideration: considerationItems,
            orderType: OrderType.CONTRACT,
            startTime: block.timestamp - 1000,
            endTime: block.timestamp + 1000,
            zoneHash: bytes32(0),
            salt: 0,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: numConsideration
        });
        order.numerator = 1;
        order.denominator = 1;
        order.signature = "";
        order.extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(args.mintType), // substandard version byte
            bytes20(args.feeRecipient),
            bytes20(args.minter),
            args.mintTypeData
        );
    }

    /// @dev Public mint order for a single token id with a publicDropIndex.
    function _publicMintOrder(
        uint256 tokenId,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        uint8 publicDropIndex
    ) internal view returns (AdvancedOrder memory, uint256) {
        return _createMintOrder(
            MintOrderArgs({
                token: address(token),
                tokenIds: _single(tokenId),
                quantities: _single(quantity),
                feeRecipient: feeRecipient,
                feeBps: feeBps,
                price: price,
                minter: minter,
                mintType: MINT_TYPE_PUBLIC,
                mintTypeData: abi.encodePacked(publicDropIndex)
            })
        );
    }

    /// @dev Allow list mint order.
    function _allowListMintOrder(
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        bytes32[] memory proof
    ) internal view returns (AdvancedOrder memory, uint256) {
        return _createMintOrder(
            MintOrderArgs({
                token: tokenAddress,
                tokenIds: tokenIds,
                quantities: quantities,
                feeRecipient: feeRecipient,
                feeBps: feeBps,
                price: price,
                minter: minter,
                mintType: MINT_TYPE_ALLOW_LIST,
                mintTypeData: bytes.concat(
                    abi.encode(mintParams), abi.encodePacked(proof)
                )
            })
        );
    }

    /// @dev Signed mint order.
    function _signedMintOrder(
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal view returns (AdvancedOrder memory, uint256) {
        return _createMintOrder(
            MintOrderArgs({
                token: tokenAddress,
                tokenIds: tokenIds,
                quantities: quantities,
                feeRecipient: feeRecipient,
                feeBps: feeBps,
                price: price,
                minter: minter,
                mintType: MINT_TYPE_SIGNED,
                mintTypeData: bytes.concat(
                    abi.encode(mintParams), bytes32(salt), signature
                )
            })
        );
    }

    /**
     * Fulfillment
     */

    /// @dev Fulfills the order through Seaport as `fulfiller`.
    function _fulfill(
        address fulfiller,
        AdvancedOrder memory order,
        uint256 value
    ) internal {
        vm.prank(fulfiller);
        consideration.fulfillAdvancedOrder{ value: value }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
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

    /// @dev Fulfills the order and expects Seaport to revert with
    ///      InvalidContractOrder(orderHash) for the order's offerer.
    function _fulfillExpectingInvalidContractOrder(
        address fulfiller,
        AdvancedOrder memory order,
        uint256 value
    ) internal {
        bytes32 orderHash = _contractOrderHash(order.parameters.offerer);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidContractOrder.selector, orderHash)
        );
        _fulfill(fulfiller, order, value);
    }

    /// @dev Seaport wraps the token's generateOrder revert in
    ///      InvalidContractOrder, so the Hardhat specs could only name the
    ///      inner error in a comment. previewOrder runs the same validation
    ///      without effects and bubbles the inner error, so this asserts it.
    function _expectPreviewRevert(
        address fulfiller,
        AdvancedOrder memory order,
        bytes memory reason
    ) internal {
        (SpentItem[] memory minimumReceived, SpentItem[] memory maximumSpent) =
            _toSpentItems(order);
        address offerer = order.parameters.offerer;
        vm.expectRevert(reason);
        ContractOffererInterface(offerer)
            .previewOrder(
                address(consideration),
                fulfiller,
                minimumReceived,
                maximumSpent,
                order.extraData
            );
    }

    /// @dev Mirrors the minimumReceived / maximumSpent mapping in the
    ///      "previewOrder" specs.
    function _toSpentItems(AdvancedOrder memory order)
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
        ConsiderationItem[] memory considerationItems =
        order.parameters.consideration;
        maximumSpent = new SpentItem[](considerationItems.length);
        for (uint256 i = 0; i < considerationItems.length; i++) {
            maximumSpent[i] = SpentItem({
                itemType: considerationItems[i].itemType,
                token: considerationItems[i].token,
                identifier: considerationItems[i].identifierOrCriteria,
                amount: considerationItems[i].endAmount
            });
        }
    }

    /// @dev Mirrors the "Should return the expected offer and consideration
    ///      in previewOrder" specs: previewOrder (with a zero caller, as in
    ///      txDataForPreviewOrder) returns exactly the order's offer and
    ///      consideration, recipients included.
    function _assertPreviewOrderMatches(
        address fulfiller,
        AdvancedOrder memory order
    ) internal {
        (SpentItem[] memory minimumReceived, SpentItem[] memory maximumSpent) =
            _toSpentItems(order);

        vm.prank(fulfiller);
        (
            SpentItem[] memory offer,
            ReceivedItem[] memory considerationReturned
        ) = ContractOffererInterface(order.parameters.offerer)
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

        ConsiderationItem[] memory expected = order.parameters.consideration;
        assertEq(considerationReturned.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(
                uint256(considerationReturned[i].itemType),
                uint256(expected[i].itemType)
            );
            assertEq(considerationReturned[i].token, expected[i].token);
            assertEq(
                considerationReturned[i].identifier,
                expected[i].identifierOrCriteria
            );
            assertEq(considerationReturned[i].amount, expected[i].endAmount);
            assertEq(considerationReturned[i].recipient, expected[i].recipient);
        }
    }

    /// @dev Mirrors mintTokens in test/utils/helpers.ts: temporarily sets a
    ///      free public drop at index 0 for `tokenId`, mints through Seaport
    ///      and restores the previous public drop.
    function _mintTokens(address minter, uint256 tokenId, uint256 quantity)
        internal
    {
        IERC1155SeaDrop seadropToken = IERC1155SeaDrop(address(token));
        PublicDrop memory prevPublicDrop = seadropToken.getPublicDrop(0);

        PublicDrop memory temporaryPublicDrop = PublicDrop({
            startPrice: 0,
            endPrice: 0,
            startTime: uint40(block.timestamp - 1000),
            endTime: uint40(block.timestamp + 5000),
            paymentToken: address(0),
            fromTokenId: uint24(tokenId),
            toTokenId: uint24(tokenId),
            maxTotalMintableByWallet: 1000,
            maxTotalMintableByWalletPerToken: 1000,
            feeBps: 0,
            restrictFeeRecipients: false
        });
        seadropToken.updatePublicDrop(temporaryPublicDrop, 0);

        (AdvancedOrder memory order, uint256 value) = _publicMintOrder(
            tokenId,
            quantity,
            address(0x1111111111111111111111111111111111111111),
            0,
            0,
            minter,
            0
        );
        _fulfill(minter, order, value);

        // Reset the public drop.
        seadropToken.updatePublicDrop(prevPublicDrop, 0);
    }

    /**
     * Allow list
     */

    /// @dev Mirrors createAllowListAndGetProof. Murky refuses single-leaf
    ///      trees, so a one-minter list uses the leaf as the root and an
    ///      empty proof, as merkletreejs does.
    function _allowListRootAndProof(
        address[] memory minters,
        MintParams memory mintParams,
        uint256 minterIndexForProof
    ) internal returns (bytes32 root, bytes32[] memory proof) {
        if (minters.length == 1) {
            root = keccak256(abi.encode(minters[0], mintParams));
            proof = new bytes32[](0);
        } else {
            (root, proof) = _createMerkleRootAndProof(
                minters, minterIndexForProof, mintParams
            );
        }
    }

    function _updateAllowList(bytes32 root) internal {
        IERC1155SeaDrop(address(token))
            .updateAllowList(
                AllowListData({
                    merkleRoot: root,
                    publicKeyURIs: new string[](0),
                    allowListURI: ""
                })
            );
    }

    /**
     * Signed mint
     */

    /// @dev Mirrors signMint in the mintSigned spec: signs a compact
    ///      (EIP-2098) signature and checks it recovers to the signer.
    function _signMint(
        string memory signerName,
        address tokenAddress,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal returns (bytes memory signature, bytes32 digest) {
        signature = getSignedMint(
            signerName,
            tokenAddress,
            minter,
            feeRecipient,
            mintParams,
            salt,
            true
        );
        digest =
            _getDigest(tokenAddress, minter, feeRecipient, mintParams, salt);
        (bytes32 r, bytes32 vs) = abi.decode(signature, (bytes32, bytes32));
        assertEq(ECDSA.recover(digest, r, vs), makeAddr(signerName));
    }

    /**
     * Misc
     */

    function _single(uint256 a) internal pure returns (uint256[] memory arr) {
        arr = new uint256[](1);
        arr[0] = a;
    }

    function _pair(uint256 a, uint256 b)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](2);
        arr[0] = a;
        arr[1] = b;
    }

    function _triple(uint256 a, uint256 b, uint256 c)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
    }

    function _addresses(address a)
        internal
        pure
        returns (address[] memory arr)
    {
        arr = new address[](1);
        arr[0] = a;
    }

    function _addresses(address a, address b)
        internal
        pure
        returns (address[] memory arr)
    {
        arr = new address[](2);
        arr[0] = a;
        arr[1] = b;
    }
}
