// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./SeaDrop721Test.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import {
    IDelegationRegistry
} from "seadrop/interfaces/IDelegationRegistry.sol";

import { MintParams, PublicDrop } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

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

import {
    ContractOffererInterface
} from "seaport-types/src/interfaces/ContractOffererInterface.sol";

/**
 * @dev Mint helpers for the ERC721SeaDrop Forge tests that were ported from
 *      the Hardhat specs. They mirror test/utils/order.ts (createMintOrder),
 *      test/utils/allow-list.ts (createAllowListAndGetProof) and
 *      test/utils/helpers.ts (mintTokens), building orders in memory so that
 *      a test can hold several orders at once.
 */
abstract contract SeaDrop721MintHelpers is SeaDrop721Test {
    enum MintType {
        PUBLIC,
        ALLOW_LIST,
        SIGNED
    }

    struct MintOrder {
        address token;
        uint256 quantity;
        address feeRecipient;
        uint256 feeBps;
        uint256 price;
        address minter;
        MintType mintType;
        MintParams mintParams;
        bytes32[] proof;
        uint256 salt;
        bytes signature;
    }

    /// @dev The canonical DelegationRegistry, etched by SeaDrop721Test.
    IDelegationRegistry internal constant DELEGATION_REGISTRY =
        IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);

    /// @dev The canonical OpenSea conduit, preapproved by ERC721SeaDrop.
    address internal constant OPENSEA_CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /// @dev Start at a realistic timestamp so stages can start in the past,
    ///      like the Hardhat specs' Date.now() based times.
    uint256 internal constant START_TIMESTAMP = 1_700_000_000;

    function setUp() public virtual override {
        super.setUp();
        vm.warp(START_TIMESTAMP);
    }

    /**
     * Order building
     */
    function _publicOrder(
        address tokenAddress,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        MintOrder memory m;
        m.token = tokenAddress;
        m.quantity = quantity;
        m.feeRecipient = feeRecipient;
        m.feeBps = feeBps;
        m.price = price;
        m.minter = minter;
        m.mintType = MintType.PUBLIC;
        return _createMintOrder(m);
    }

    function _allowListOrder(
        address tokenAddress,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        bytes32[] memory proof
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        MintOrder memory m;
        m.token = tokenAddress;
        m.quantity = quantity;
        m.feeRecipient = feeRecipient;
        m.feeBps = feeBps;
        m.price = price;
        m.minter = minter;
        m.mintType = MintType.ALLOW_LIST;
        m.mintParams = mintParams;
        m.proof = proof;
        return _createMintOrder(m);
    }

    function _signedOrder(
        address tokenAddress,
        uint256 quantity,
        address feeRecipient,
        uint256 feeBps,
        uint256 price,
        address minter,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    ) internal view returns (AdvancedOrder memory order, uint256 value) {
        MintOrder memory m;
        m.token = tokenAddress;
        m.quantity = quantity;
        m.feeRecipient = feeRecipient;
        m.feeBps = feeBps;
        m.price = price;
        m.minter = minter;
        m.mintType = MintType.SIGNED;
        m.mintParams = mintParams;
        m.salt = salt;
        m.signature = signature;
        return _createMintOrder(m);
    }

    /// @dev Mirrors createMintOrder in test/utils/order.ts.
    function _createMintOrder(MintOrder memory m)
        internal
        view
        returns (AdvancedOrder memory order, uint256 value)
    {
        OfferItem[] memory offer = new OfferItem[](1);
        offer[0] = OfferItem({
            itemType: ItemType.ERC1155,
            token: m.token,
            identifierOrCriteria: 0,
            startAmount: m.quantity,
            endAmount: m.quantity
        });

        value = m.price * m.quantity;
        ConsiderationItem[] memory items =
            _mintConsiderationItems(m.token, m.feeRecipient, m.feeBps, value);

        OrderParameters memory parameters = OrderParameters({
            offerer: m.token,
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

        order = AdvancedOrder({
            parameters: parameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: _mintExtraData(m)
        });
    }

    /// @dev Fee item only when the fee is non-zero, creator payout items only
    ///      when the creator amount is non-zero, as in order.ts.
    function _mintConsiderationItems(
        address tokenAddress,
        address feeRecipient,
        uint256 feeBps,
        uint256 value
    ) internal view returns (ConsiderationItem[] memory items) {
        uint256 feeAmount = (value * feeBps) / 10_000;
        uint256 creatorAmount = value - feeAmount;
        CreatorPayout[] memory payouts =
            IERC721SeaDrop(tokenAddress).getCreatorPayouts();

        items = new ConsiderationItem[](
            (feeAmount != 0 ? 1 : 0) + (creatorAmount != 0 ? payouts.length : 0)
        );

        uint256 index;
        if (feeAmount != 0) {
            items[index++] = _nativeConsiderationItem(feeRecipient, feeAmount);
        }
        if (creatorAmount != 0) {
            for (uint256 i = 0; i < payouts.length; i++) {
                items[index++] = _nativeConsiderationItem(
                    payouts[i].payoutAddress,
                    (creatorAmount * payouts[i].basisPoints) / 10_000
                );
            }
        }
    }

    function _nativeConsiderationItem(address recipient, uint256 amount)
        internal
        pure
        returns (ConsiderationItem memory)
    {
        return ConsiderationItem({
            itemType: ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: amount,
            endAmount: amount,
            recipient: payable(recipient)
        });
    }

    function _mintExtraData(MintOrder memory m)
        internal
        pure
        returns (bytes memory extraData)
    {
        extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(uint8(m.mintType)), // substandard version byte
            bytes20(m.feeRecipient),
            bytes20(m.minter)
        );
        if (m.mintType == MintType.ALLOW_LIST) {
            extraData = bytes.concat(
                extraData, abi.encode(m.mintParams), abi.encodePacked(m.proof)
            );
        } else if (m.mintType == MintType.SIGNED) {
            extraData = bytes.concat(
                extraData,
                abi.encode(m.mintParams),
                bytes32(m.salt),
                m.signature
            );
        }
    }

    /// @dev The minimumReceived and maximumSpent Seaport derives from the
    ///      order, as built by txDataForPreviewOrder in helpers.ts.
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

    /**
     * Fulfillment and assertions
     */
    function _fulfill(
        AdvancedOrder memory order,
        address fulfiller,
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

    /// @dev The InvalidContractOrder(orderHash) Seaport reverts with when the
    ///      contract offerer's generateOrder reverts.
    function _invalidContractOrderError(address tokenAddress)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            InvalidContractOrder.selector,
            bytes32(
                (uint256(uint160(tokenAddress)) << 96)
                    + consideration.getContractOffererNonce(tokenAddress)
            )
        );
    }

    /**
     * @dev Assert that fulfilling the mint order through Seaport reverts with
     *      InvalidContractOrder(orderHash), which is all the Hardhat specs
     *      could observe. Also assert the inner SeaDrop error that Seaport
     *      wraps, by calling previewOrder on the token with the same
     *      fulfiller, which runs the same validation without effects.
     */
    function _assertMintReverts(
        AdvancedOrder memory order,
        address fulfiller,
        uint256 value,
        bytes memory innerError
    ) internal {
        address tokenAddress = order.parameters.offerer;

        (SpentItem[] memory minimumReceived, SpentItem[] memory maximumSpent) =
            _previewItems(order);
        (bool success, bytes memory returnData) = tokenAddress.staticcall(
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
        assertEq(returnData, innerError, "unexpected inner revert reason");

        vm.expectRevert(_invalidContractOrderError(tokenAddress));
        _fulfill(order, fulfiller, value);
    }

    /**
     * @dev Assert that previewOrder on the token, called by the fulfiller with
     *      a zero caller as in helpers.ts txDataForPreviewOrder, returns the
     *      order's own offer as the offer and its consideration (with
     *      recipients) as the consideration.
     */
    function _assertPreviewOrderEchoesOrder(
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
     * Allow list
     */

    /// @dev Mirrors createAllowListAndGetProof in allow-list.ts. Murky does not
    ///      build single-leaf trees, so a lone leaf is its own root with an
    ///      empty proof, as merkletreejs does.
    function _createAllowListAndGetProof(
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

    function _createAllowListAndGetProof(
        address minter,
        MintParams memory mintParams
    ) internal returns (bytes32 root, bytes32[] memory proof) {
        address[] memory minters = new address[](1);
        minters[0] = minter;
        return _createAllowListAndGetProof(minters, mintParams, 0);
    }

    /// @dev A copy of mint params, since assigning a memory struct aliases
    ///      it (unlike the spec's `{ ...mintParams }`).
    function _copyMintParams(MintParams memory mintParams)
        internal
        pure
        returns (MintParams memory)
    {
        return abi.decode(abi.encode(mintParams), (MintParams));
    }

    function _updateAllowList(address tokenAddress, bytes32 root) internal {
        IERC721SeaDrop(tokenAddress)
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

    /// @dev Mirrors signMint in the mintSigned spec: signs the EIP-712 digest,
    ///      checks the signer recovers, and returns the EIP-2098 compact
    ///      signature the token expects.
    function _signMint(
        string memory signerName,
        address tokenAddress,
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal returns (bytes memory signature, bytes32 digest) {
        digest =
            _getDigest(tokenAddress, minter, feeRecipient, mintParams, salt);
        (address signerAddress, uint256 pk) = makeAddrAndKey(signerName);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        assertEq(ecrecover(digest, v, r, s), signerAddress);
        signature = _encodeSignature2098(r, s, v);
    }

    /**
     * Minting setup
     */

    /// @dev Mirrors mintTokens in helpers.ts: temporarily sets a free public
    ///      drop on `token`, mints `quantity` to `minter` through Seaport,
    ///      then restores the previous public drop.
    function _mintTokens(address minter, uint256 quantity) internal {
        IERC721SeaDrop seaDropToken = IERC721SeaDrop(address(token));
        PublicDrop memory prevPublicDrop = seaDropToken.getPublicDrop();

        seaDropToken.updatePublicDrop(
            PublicDrop({
                startPrice: 0,
                endPrice: 0,
                startTime: uint40(block.timestamp - 1000),
                endTime: uint40(block.timestamp + 5000),
                paymentToken: address(0),
                maxTotalMintableByWallet: 1000,
                feeBps: 0,
                restrictFeeRecipients: false
            })
        );

        (AdvancedOrder memory order, uint256 value) = _publicOrder(
            address(token),
            quantity,
            address(0x1111111111111111111111111111111111111111),
            0,
            0,
            minter
        );
        _fulfill(order, minter, value);

        seaDropToken.updatePublicDrop(prevPublicDrop);
    }

    function _setSingleCreatorPayout(address tokenAddress, address creator)
        internal
    {
        CreatorPayout[] memory creatorPayouts = new CreatorPayout[](1);
        creatorPayouts[0] =
            CreatorPayout({ payoutAddress: creator, basisPoints: 10_000 });
        IERC721SeaDrop(tokenAddress).updateCreatorPayouts(creatorPayouts);
    }

    function _setCreatorPayouts(
        address tokenAddress,
        address creatorA,
        uint256 bpsA,
        address creatorB,
        uint256 bpsB
    ) internal {
        CreatorPayout[] memory creatorPayouts = new CreatorPayout[](2);
        creatorPayouts[0] = CreatorPayout({
            payoutAddress: creatorA,
            basisPoints: uint16(bpsA)
        });
        creatorPayouts[1] = CreatorPayout({
            payoutAddress: creatorB,
            basisPoints: uint16(bpsB)
        });
        IERC721SeaDrop(tokenAddress).updateCreatorPayouts(creatorPayouts);
    }
}
