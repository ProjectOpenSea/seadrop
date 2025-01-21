// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    MintParams,
    SignedMintValidationParams
} from "seadrop/lib/SeaDropStructs.sol";

import { ECDSA } from "openzeppelin-contracts/utils/cryptography/ECDSA.sol";

contract SeaDropMintSignedTest is TestHelper {
    using ECDSA for bytes32;
    ERC721SeaDrop token2;
    SignedMintValidationParams signedMintValidationParams;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed identifier
    );

    struct FuzzInputsSigners {
        address payer;
        address minter;
        uint40 numMints;
        address feeRecipient;
        string signerNameSeed;
        uint256 salt;
    }

    modifier validateFuzzInputsSigners(FuzzInputsSigners memory args) {
        vm.assume(args.numMints > 0 && args.numMints <= 10);
        vm.assume(
            args.feeRecipient.code.length == 0 && args.feeRecipient > address(9)
        );
        vm.assume(args.minter.code.length == 0 && args.minter > address(9));
        vm.assume(args.minter != address(0) && args.payer != address(0));
        _;
    }

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", allowedSeaDrop);
        token2 = new ERC721SeaDrop("", "", allowedSeaDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);
        token2.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);
        token2.updateCreatorPayoutAddress(address(seadrop), creator);
        signedMintValidationParams.maxEndTime = type(uint40).max;
        signedMintValidationParams.maxMaxTotalMintableByWallet = type(uint24)
            .max;
        signedMintValidationParams.maxMaxTokenSupplyForStage = type(uint24).max;
        signedMintValidationParams.maxFeeBps = 10000;
    }

    function testMintSigned(FuzzInputsSigners memory args)
        public
        validateFuzzInputsSigners(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // if false, allow any fee recipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            address(token),
            args.minter,
            args.feeRecipient,
            mintParams,
            args.salt
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.

        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        vm.startPrank(address(token));
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(args.feeRecipient, true);
        vm.stopPrank();

        // Allow the payer.
        token.updatePayer(address(seadrop), args.payer, true);

        hoax(args.payer, 100 ether);

        // Calculate the value to send with the transaction.

        seadrop.mintSigned{ value: args.numMints * mintParams.mintPrice }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            args.salt,
            signature
        );

        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintSigned_validSignatureWrongToken(
        FuzzInputsSigners memory args
    ) public validateFuzzInputsSigners(args) {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // if false, allow any fee recipient
        );

        bytes memory signature;
        {
            // Get the signature components.
            (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
                args.signerNameSeed,
                address(token),
                args.minter,
                args.feeRecipient,
                mintParams,
                args.salt
            );

            // Create the signature from the components.
            signature = abi.encodePacked(r, s, v);
        }

        // Impersonate the token contract to update the signers.

        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        vm.startPrank(address(token));
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(args.feeRecipient, true);
        vm.stopPrank();

        vm.startPrank(address(token2));
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(args.feeRecipient, true);

        vm.stopPrank();

        // Allow the payer.
        token.updatePayer(address(seadrop), args.payer, true);
        token2.updatePayer(address(seadrop), args.payer, true);

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * mintParams.mintPrice;

        hoax(args.payer, 100 ether);
        seadrop.mintSigned{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            args.salt,
            signature
        );

        {
            bytes32 digest = _getDigest(
                address(token2),
                args.minter,
                args.feeRecipient,
                mintParams,
                args.salt
            );
            address expectedRecovered = digest.recover(signature);

            vm.expectRevert(
                abi.encodeWithSelector(
                    InvalidSignature.selector,
                    expectedRecovered
                )
            );
        }
        hoax(args.payer, 100 ether);
        seadrop.mintSigned{ value: mintValue }(
            address(token2),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            args.salt,
            signature
        );
    }

    function testMintSigned_invalidFeeRecipient(FuzzInputsSigners memory args)
        public
        validateFuzzInputsSigners(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        bytes memory signature;
        {
            // Get the signature components.
            (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
                args.signerNameSeed,
                address(token),
                args.minter,
                args.feeRecipient,
                mintParams,
                args.salt
            );

            // Create the signature from the components.
            signature = abi.encodePacked(r, s, v);
        }

        // Impersonate the token contract to update the signers.

        // Update the approved signers of the token contract.
        {
            address signer = makeAddr(args.signerNameSeed);
            vm.startPrank(address(token));

            seadrop.updateSignedMintValidationParams(
                signer,
                signedMintValidationParams
            );
            seadrop.updateAllowedFeeRecipient(args.feeRecipient, true);
            vm.stopPrank();
        }

        // Allow the payer.
        token.updatePayer(address(seadrop), args.payer, true);

        // Calculate the value to send with the transaction.
        address badFeeRecipient;
        {
            uint160 addressVal = uint160(args.feeRecipient);
            if (addressVal < type(uint160).max) {
                ++addressVal;
            } else {
                --addressVal;
            }
            badFeeRecipient = address(addressVal);
        }
        address expectedRecovered;
        {
            bytes32 badDigest = _getDigest(
                address(token),
                args.minter,
                badFeeRecipient,
                mintParams,
                args.salt
            );
            expectedRecovered = badDigest.recover(signature);
        }

        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignature.selector, expectedRecovered)
        );

        hoax(args.payer, 100 ether);
        seadrop.mintSigned{ value: args.numMints * mintParams.mintPrice }(
            address(token),
            badFeeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            args.salt,
            signature
        );
    }

    function testMintSigned_freeMint(FuzzInputsSigners memory args)
        public
        validateFuzzInputsSigners(args)
    {
        // Create a MintParams object with a mint price of 0 ether.
        MintParams memory mintParams = MintParams(
            0 ether, // mint price (free)
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // if false, allow any fee recipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            address(token),
            args.minter,
            args.feeRecipient,
            mintParams,
            args.salt
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.
        vm.startPrank(address(token));
        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(args.feeRecipient, true);
        vm.stopPrank();

        // Allow the payer.
        token.updatePayer(address(seadrop), args.payer, true);

        hoax(args.payer, 100 ether);

        seadrop.mintSigned(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            args.salt,
            signature
        );

        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintSigned_revertFeeRecipientNotAllowed(
        FuzzInputsSigners memory args
    ) public validateFuzzInputsSigners(args) {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // restrictFeeRecipient
        );

        bytes memory signature;

        // Get the signature components.
        {
            (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
                args.signerNameSeed,
                address(token),
                args.minter,
                args.feeRecipient,
                mintParams,
                args.salt
            );

            // Create the signature from the components.
            signature = abi.encodePacked(r, s, v);
        }

        // Impersonate the token contract to update the signers.
        vm.prank(address(token));

        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );

        // Allow the payer.
        token.updatePayer(address(seadrop), args.payer, true);

        hoax(args.payer, 100 ether);

        // Expect the subsequent call to mintSigned to revert with error
        // FeeRecipientNotAllowed
        vm.expectRevert(
            abi.encodeWithSelector(FeeRecipientNotAllowed.selector)
        );

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * mintParams.mintPrice;

        seadrop.mintSigned{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            args.salt,
            signature
        );
    }

    function testMintSigned_unknownSigner(string memory signerSeed) public {
        vm.assume(
            keccak256(bytes(signerSeed)) != keccak256(bytes("good seed"))
        );
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // restrictFeeRecipient
        );
        address feeRecipient = address(1);
        // Get the signature components with an invalid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            signerSeed,
            address(token),
            msg.sender,
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.
        vm.prank(address(token));
        // Update the approved signers of the token contract.
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );

        address expectedRecovered = makeAddr(signerSeed);

        hoax(msg.sender, 100 ether);

        // Expect the subsequent call to mintSigned to revert with error
        // InvalidSignature
        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignature.selector, expectedRecovered)
        );

        seadrop.mintSigned{ value: mintParams.mintPrice }(
            address(token),
            feeRecipient,
            msg.sender,
            1,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_differentPayerThanMinter(
        address minter,
        address payer
    ) public {
        vm.assume(
            minter != address(0) &&
                payer != address(0) &&
                minter != payer &&
                minter.code.length == 0 &&
                payer.code.length == 0
        );

        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // restrictFeeRecipient
        );
        address feeRecipient = address(1);

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            minter,
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.
        vm.startPrank(address(token));
        // Update the approved signers of the token contract.
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Allow the payer.
        token.updatePayer(address(seadrop), payer, true);

        hoax(payer, 100 ether);

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), minter, 1);

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(address(0), minter, 2);

        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            minter,
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_invalidMintPrice() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.11 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 0,
            maxEndTime: 1001,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 0,
            maxFeeBps: 100
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSignedMintPrice.selector,
                .1 ether,
                .11 ether
            )
        );
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_invalidMaxTotalMintableByWallet() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            1001, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.1 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 0,
            maxEndTime: 1001,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 0,
            maxFeeBps: 100
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSignedMaxTotalMintableByWallet.selector,
                1001,
                1000
            )
        );
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_invalidStartTime() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            5, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.1 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 2,
            maxEndTime: 1001,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 0,
            maxFeeBps: 100
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignedStartTime.selector, 1, 2)
        );
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_invalidEndTime() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            5, // max mints per wallet
            uint48(block.timestamp), // start time
            1001, // end time
            1,
            1000,
            100, // fee (1%)
            true // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.1 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 0,
            maxEndTime: 1000,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 0,
            maxFeeBps: 100
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignedEndTime.selector, 1001, 1000)
        );
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_invalidMaxTokenSupplyForStage() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            5, // max mints per wallet
            uint48(block.timestamp), // start time
            1000, // end time
            1, // ignore drop stage index
            1001, // max token supply for stage
            100, // fee (1%)
            true // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.1 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 0,
            maxEndTime: 1000,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 0,
            maxFeeBps: 100
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSignedMaxTokenSupplyForStage.selector,
                1001,
                1000
            )
        );
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_invalidMinFeeBps() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            5, // max mints per wallet
            uint48(block.timestamp), // start time
            1000, // end time
            1, // ignore drop stage index
            1000, // max token supply for stage
            0, // fee (1%)
            true // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.1 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 0,
            maxEndTime: 1000,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 1,
            maxFeeBps: 100
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignedFeeBps.selector, 0, 1)
        );
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_invalidMaxFeeBps() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            5, // max mints per wallet
            uint48(block.timestamp), // start time
            1000, // end time
            1, // ignore drop stage index
            1000, // max token supply for stage
            1, // fee (1%)
            true // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.1 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 0,
            maxEndTime: 1000,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 0,
            maxFeeBps: 0
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignedFeeBps.selector, 1, 0)
        );
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }

    function testMintSigned_mustRestrictFeeRecipients() public {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            5, // max mints per wallet
            uint48(block.timestamp), // start time
            1000, // end time
            1, // ignore drop stage index
            1000, // max token supply for stage
            1, // fee (1%)
            false // restrictFeeRecipient
        );

        signedMintValidationParams = SignedMintValidationParams({
            minMintPrice: 0.1 ether,
            maxMaxTotalMintableByWallet: 1000,
            minStartTime: 0,
            maxEndTime: 1000,
            maxMaxTokenSupplyForStage: 1000,
            minFeeBps: 0,
            maxFeeBps: 1
        });
        address feeRecipient = address(1234);

        vm.startPrank(address(token));
        address signer = makeAddr("good seed");
        seadrop.updateSignedMintValidationParams(
            signer,
            signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(feeRecipient, true);
        vm.stopPrank();

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            address(this),
            feeRecipient,
            mintParams,
            101010101010101
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(SignedMintsMustRestrictFeeRecipients.selector);
        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            address(0),
            2,
            mintParams,
            101010101010101,
            signature
        );
    }
}
