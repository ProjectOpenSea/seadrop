// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDropTest } from "./utils/SeaDropTest.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    MintParams,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "seadrop/lib/ERC721SeaDropStructs.sol";

import { TokenGatedMintParams } from "seadrop/lib/SeaDropStructs.sol";

import { AdvancedOrder } from "seaport/lib/ConsiderationStructs.sol";

contract ERC721SeaDropTest is SeaDropTest {
    FuzzArgs empty;

    uint256 feeBps = 500;

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

        // Assume creator has zero balance.
        vm.assume(args.creator.balance == 0);

        // Assume feeRecipient is not the creator.
        vm.assume(args.feeRecipient != args.creator);

        // Assume feeRecipient and creator are EOAs.
        vm.assume(args.feeRecipient.code.length == 0);
        vm.assume(args.creator.code.length == 0);

        assumeNoPrecompiles(args.feeRecipient);
        assumeNoPrecompiles(args.creator);

        _;
    }

    function setUp() public override {
        super.setUp();
        token = new ERC721SeaDrop(
            "",
            "",
            address(configurer),
            address(0),
            allowedSeaport
        );
    }

    function testMintPublic(
        Context memory context
    ) public fuzzConstraints(context.args) {
        address feeRecipient = context.args.feeRecipient;
        configurer.updateAllowedFeeRecipient(
            address(token),
            feeRecipient,
            true
        );
        token.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp + 500),
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        configurer.updatePublicDrop(address(token), publicDrop);

        addSeaDropOfferItem(3); // 3 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version byte: public mint
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

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 0);

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96) +
                    consideration.getContractOffererNonce(address(token))
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
        address feeRecipient = context.args.feeRecipient;
        configurer.updateAllowedFeeRecipient(
            address(token),
            feeRecipient,
            true
        );
        token.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            paymentToken: address(0),
            maxTotalMintableByWallet: 5,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp) + 500,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 2,
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
            bytes1(0x01), // substandard version byte: allow list mint
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

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 2);

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96) +
                    consideration.getContractOffererNonce(address(token))
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
        address feeRecipient = context.args.feeRecipient;
        configurer.updateAllowedFeeRecipient(
            address(token),
            feeRecipient,
            true
        );
        token.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        // Configure the drop stage.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            paymentToken: address(0),
            maxMintablePerRedeemedToken: 3,
            maxTotalMintableByWallet: 10,
            dropStageIndex: 2,
            maxTokenSupplyForStage: 1000,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: false
        });
        configurer.updateTokenGatedDrop(
            address(token),
            address(test721_1),
            dropStage
        );

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
            bytes1(0x02), // substandard version byte: token holder mint
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

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 2);

        consideration.fulfillAdvancedOrder{ value: 3 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWallet
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96) +
                    consideration.getContractOffererNonce(address(token))
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
        address feeRecipient = context.args.feeRecipient;
        configurer.updateAllowedFeeRecipient(
            address(token),
            feeRecipient,
            true
        );
        token.setMaxSupply(10);
        setSingleCreatorPayout(context.args.creator);

        SignedMintValidationParams
            memory validationParams = SignedMintValidationParams({
                minMintPrice: 1 ether,
                paymentToken: address(0),
                maxMaxTotalMintableByWallet: 10,
                minStartTime: uint40(block.timestamp),
                maxEndTime: uint40(block.timestamp + 500),
                maxMaxTokenSupplyForStage: 1000,
                minFeeBps: 100,
                maxFeeBps: 1000
            });
        address signer = makeAddr("signer-doug");
        configurer.updateSignedMintValidationParams(
            address(token),
            signer,
            validationParams
        );

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp) + 500,
            paymentToken: address(0),
            maxTotalMintableByWallet: 4,
            maxTokenSupplyForStage: 1000,
            dropStageIndex: 3,
            feeBps: feeBps,
            restrictFeeRecipients: true
        });

        // Get the signature.
        address minter = address(this);
        uint256 salt = 123;
        bytes memory signature = getSignedMint(
            "signer-doug",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt,
            false
        );

        addSeaDropOfferItem(2); // 2 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x03), // substandard version byte: signed mint
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

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 3);

        consideration.fulfillAdvancedOrder{ value: 2 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(2), minter);
        assertEq(context.args.creator.balance, 2 ether * 0.95);

        // Minting more should fail as the digest is used
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96) +
                    consideration.getContractOffererNonce(address(token))
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
            address(token),
            minter,
            feeRecipient,
            mintParams,
            salt,
            false
        );
        extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x03), // substandard version byte: signed mint
            bytes20(feeRecipient),
            bytes20(minter),
            abi.encode(mintParams),
            bytes32(salt),
            signature
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96) +
                    consideration.getContractOffererNonce(address(token))
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
