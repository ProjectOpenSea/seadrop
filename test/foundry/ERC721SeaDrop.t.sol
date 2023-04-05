// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { SeaDropTest } from "./utils/SeaDropTest.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    CreatorPayout,
    PublicDrop,
    MintParams,
    SignedMintValidationParams,
    SignedMintValidationMinMintPrice,
    TokenGatedDropStage,
    TokenGatedMintParams
} from "seadrop/lib/SeaDropStructs.sol";

import {
    ConsiderationInterface
} from "seaport/interfaces/ConsiderationInterface.sol";

import {
    OfferItem,
    ConsiderationItem,
    AdvancedOrder,
    OrderComponents,
    FulfillmentComponent
} from "seaport/lib/ConsiderationStructs.sol";

import "forge-std/console.sol";

contract ERC721SeaDropTest is SeaDropTest {
    FuzzArgs empty;

    struct FuzzArgs {
        address feeRecipient;
        address creator;
    }

    struct Context {
        FuzzArgs args;
    }

    modifier fuzzConstraints(FuzzArgs memory args) {
        // Assume feeRecipient and creator are not the zero address.
        vm.assume(args.feeRecipient != address(0));
        vm.assume(args.creator != address(0));

        // Assume the feeRecipient is not the creator.
        vm.assume(args.feeRecipient != args.creator);

        // Assume the feeRecipient and creator are not any test token contracts.
        for (uint256 i = 0; i < ignoredTokenContracts.length; i++) {
            vm.assume(args.feeRecipient != ignoredTokenContracts[i]);
            vm.assume(args.creator != ignoredTokenContracts[i]);
        }

        assumeNoPrecompiles(args.feeRecipient);
        assumeNoPrecompiles(args.creator);

        _;
    }

    function testMintPublic(
        Context memory context
    ) public fuzzConstraints(context.args) {
        offerer = new ERC721SeaDrop("", "", allowedSeaport, address(0));

        address feeRecipient = context.args.feeRecipient;
        uint256 feeBps = 500;

        offerer.updateAllowedFeeRecipient(feeRecipient, true);
        offerer.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);
        setPublicDrop(1 ether, 5, feeBps);

        addSeaDropOfferItem(3); // 3 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version: public mint
            bytes20(feeRecipient),
            bytes20(minter)
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(offerer));
        emit SeaDropMint(
            minter,
            feeRecipient,
            address(this),
            3,
            1 ether,
            address(0),
            feeBps,
            0
        );

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(offerer.ownerOf(1), minter);
        assertEq(offerer.ownerOf(2), minter);
        assertEq(offerer.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(offerer))) << 96) +
                    consideration.getContractOffererNonce(address(offerer))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMintAllowedTokenHolder(
        Context memory context
    ) public fuzzConstraints(context.args) {
        offerer = new ERC721SeaDrop("", "", allowedSeaport, address(0));

        address feeRecipient = context.args.feeRecipient;
        uint256 feeBps = 500;

        offerer.updateAllowedFeeRecipient(feeRecipient, true);
        offerer.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        // Configure the drop stage.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage({
            mintPrice: 1 ether,
            paymentToken: address(0),
            maxMintablePerRedeemedToken: 3,
            maxTotalMintableByWallet: 10,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp) + 1000,
            dropStageIndex: 2,
            maxTokenSupplyForStage: 1000,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: false
        });
        offerer.updateTokenGatedDrop(address(test721_1), dropStage);

        // Mint a token gated token to the minter.
        test721_1.mint(address(this), 1);

        // Set the mint params.
        uint256[] memory allowedTokenIds = new uint256[](1);
        allowedTokenIds[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 3;
        TokenGatedMintParams memory mintParams = TokenGatedMintParams({
            allowedNftToken: address(test721_1),
            allowedNftTokenIds: allowedTokenIds,
            amounts: amounts
        });

        addSeaDropOfferItem(3); // 3 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x02), // substandard version: token holder mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams)
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(offerer));
        emit SeaDropMint(
            minter,
            feeRecipient,
            address(this),
            3,
            1 ether,
            address(0),
            feeBps,
            2
        );

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(offerer.ownerOf(1), minter);
        assertEq(offerer.ownerOf(2), minter);
        assertEq(offerer.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(offerer))) << 96) +
                    consideration.getContractOffererNonce(address(offerer))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMintAllowList(
        Context memory context
    ) public fuzzConstraints(context.args) {
        offerer = new ERC721SeaDrop("", "", allowedSeaport, address(0));

        address feeRecipient = context.args.feeRecipient;
        uint256 feeBps = 500;

        offerer.updateAllowedFeeRecipient(feeRecipient, true);
        offerer.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        MintParams memory mintParams = MintParams({
            mintPrice: 1 ether,
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp) + 1000,
            dropStageIndex: 2,
            maxTokenSupplyForStage: 1000,
            feeBps: feeBps,
            restrictFeeRecipients: false
        });

        address[] memory allowList = new address[](2);
        allowList[0] = address(this);
        allowList[1] = makeAddr("fred");
        bytes32[] memory proof = setAllowListMerkleRootAndReturnProof(
            allowList,
            0,
            mintParams
        );

        addSeaDropOfferItem(3); // 3 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x01), // substandard version: allow list mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            abi.encodePacked(proof)
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(offerer));
        emit SeaDropMint(
            minter,
            feeRecipient,
            address(this),
            3,
            1 ether,
            address(0),
            feeBps,
            2
        );

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(offerer.ownerOf(1), minter);
        assertEq(offerer.ownerOf(2), minter);
        assertEq(offerer.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(offerer))) << 96) +
                    consideration.getContractOffererNonce(address(offerer))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function testMintSigned(
        Context memory context
    ) public fuzzConstraints(context.args) {
        offerer = new ERC721SeaDrop("", "", allowedSeaport, address(0));

        address feeRecipient = context.args.feeRecipient;

        offerer.updateAllowedFeeRecipient(feeRecipient, true);
        offerer.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        SignedMintValidationMinMintPrice[]
            memory minMintPrices = new SignedMintValidationMinMintPrice[](1);
        minMintPrices[0] = SignedMintValidationMinMintPrice({
            paymentToken: address(0),
            minMintPrice: 1 ether
        });
        SignedMintValidationParams
            memory validationParams = SignedMintValidationParams({
                minMintPrices: minMintPrices,
                maxMaxTotalMintableByWallet: 10,
                minStartTime: uint40(block.timestamp),
                maxEndTime: uint40(block.timestamp + 1000),
                maxMaxTokenSupplyForStage: 1000,
                minFeeBps: 100,
                maxFeeBps: 1000
            });
        address signer = makeAddr("signer-doug");
        offerer.updateSignedMintValidationParams(signer, validationParams);

        uint256 feeBps = 500;
        MintParams memory mintParams = MintParams({
            mintPrice: 1 ether,
            paymentToken: address(0),
            maxTotalMintableByWallet: 4,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp) + 500,
            dropStageIndex: 3,
            maxTokenSupplyForStage: 1000,
            feeBps: feeBps,
            restrictFeeRecipients: true
        });

        // Get the signature.
        address minter = address(this);
        uint256 salt = 123;
        bytes memory signature = getSignedMint(
            "signer-doug",
            address(offerer),
            minter,
            feeRecipient,
            mintParams,
            salt
        );

        addSeaDropOfferItem(2); // 2 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x03), // substandard version: signed mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            bytes32(salt),
            signature
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(offerer));
        emit SeaDropMint(
            minter,
            feeRecipient,
            address(this),
            2,
            1 ether,
            address(0),
            feeBps,
            3
        );

        consideration.fulfillAdvancedOrder{ value: 2 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(offerer.ownerOf(1), minter);
        assertEq(offerer.ownerOf(2), minter);
        assertEq(context.args.creator.balance, 2 ether * 0.95);

        // Minting more should fail as the digest is used
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(offerer))) << 96) +
                    consideration.getContractOffererNonce(address(offerer))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        // Minting any more should exceed maxTotalMintableByWallet
        salt = 456;
        signature = getSignedMint(
            "signer-doug",
            address(offerer),
            minter,
            feeRecipient,
            mintParams,
            salt
        );
        extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x03), // substandard version: signed mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            bytes32(salt),
            signature
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(offerer))) << 96) +
                    consideration.getContractOffererNonce(address(offerer))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }
}
