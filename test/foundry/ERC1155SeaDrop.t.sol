// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import { ERC1155SeaDrop } from "seadrop/ERC1155SeaDrop.sol";

import { IERC1155SeaDrop } from "seadrop/interfaces/IERC1155SeaDrop.sol";

import {
    MintParams,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { TokenGatedMintParams } from "seadrop/lib/SeaDropStructs.sol";

import { AdvancedOrder } from "seaport/lib/ConsiderationStructs.sol";

contract ERC1155SeaDropTest is SeaDrop1155Test {
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
        token = new ERC1155SeaDrop(
            address(configurer),
            address(0),
            allowedSeaport
        );
    }

    function testMintPublic(
        Context memory context
    ) public fuzzConstraints(context.args) {
        address feeRecipient = context.args.feeRecipient;
        IERC1155SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
        token.setMaxSupply(1, 10);
        setSingleCreatorPayout(context.args.creator);

        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 1,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        IERC1155SeaDrop(address(token)).updatePublicDrop(publicDrop, 0);

        addSeaDropOfferItem(1, 3); // token id 1, 3 mints
        addSeaDropConsiderationItems(feeRecipient, feeBps, 3 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version byte: public mint
            bytes20(feeRecipient),
            bytes20(minter),
            bytes1(0x00) // public drop index 0
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

        assertEq(token.balanceOf(minter, 1), 3);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWalletPerToken
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
        IERC1155SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
        token.setMaxSupply(1, 10);
        setSingleCreatorPayout(context.args.creator);

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp) + 500,
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 1,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
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

        addSeaDropOfferItem(1, 3); // token id 1, 3 mints
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

        assertEq(token.balanceOf(minter, 1), 3);
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
        IERC1155SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
        token.setMaxSupply(1, 10);
        setSingleCreatorPayout(context.args.creator);

        // Configure the drop stage.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp) + 500,
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 1,
            maxMintablePerRedeemedToken: 3,
            maxTotalMintableByWallet: 10,
            maxTotalMintableByWalletPerToken: 10,
            dropStageIndex: 2,
            maxTokenSupplyForStage: 1000,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: false
        });
        IERC1155SeaDrop(address(token)).updateTokenGatedDrop(
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

        addSeaDropOfferItem(1, 3); // token id 1, 3 mints
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

        assertEq(token.balanceOf(minter, 1), 3);
        assertEq(context.args.creator.balance, 3 ether * 0.95);

        // Minting any more should exceed maxMintablePerRedeemedToken
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
        IERC1155SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
        token.setMaxSupply(1, 10);
        setSingleCreatorPayout(context.args.creator);

        SignedMintValidationParams
            memory validationParams = SignedMintValidationParams({
                minMintPrice: 1 ether,
                paymentToken: address(0),
                fromTokenId: 1,
                toTokenId: 1,
                maxMaxTotalMintableByWallet: 10,
                maxMaxTotalMintableByWalletPerToken: 9,
                minStartTime: uint40(block.timestamp),
                maxEndTime: uint40(block.timestamp + 500),
                maxMaxTokenSupplyForStage: 1000,
                minFeeBps: 100,
                maxFeeBps: 1000
            });
        address signer = makeAddr("signer-doug");
        IERC1155SeaDrop(address(token)).updateSignedMintValidationParams(
            signer,
            validationParams
        );

        MintParams memory mintParams = MintParams({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint48(block.timestamp),
            endTime: uint48(block.timestamp) + 500,
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 1,
            maxTotalMintableByWallet: 4,
            maxTotalMintableByWalletPerToken: 4,
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

        addSeaDropOfferItem(1, 2); // token id 1, 2 mints
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

        assertEq(token.balanceOf(minter, 1), 2);
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
