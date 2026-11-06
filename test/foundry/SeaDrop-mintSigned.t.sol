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
        signedMintValidationParams.maxMaxTotalMintableByWallet =
        type(uint24).max;
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
            signer, signedMintValidationParams
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

    function testMintSigned_validSignatureWrongToken(FuzzInputsSigners memory args)
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
            signer, signedMintValidationParams
        );
        seadrop.updateAllowedFeeRecipient(args.feeRecipient, true);
        vm.stopPrank();

        vm.startPrank(address(token2));
        seadrop.updateSignedMintValidationParams(
            signer, signedMintValidationParams
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
                    InvalidSignature.selector, expectedRecovered
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
                signer, signedMintValidationParams
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
            signer, signedMintValidationParams
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

    function testMintSigned_revertFeeRecipientNotAllowed(FuzzInputsSigners memory args)
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
            signer, signedMintValidationParams
        );

        // Allow the payer.
        token.updatePayer(address(seadrop), args.payer, true);

        hoax(args.payer, 100 ether);

        // Expect the subsequent call to mintSigned to revert with error
        // FeeRecipientNotAllowed
        vm.expectRevert(abi.encodeWithSelector(FeeRecipientNotAllowed.selector));

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
        vm.assume(keccak256(bytes(signerSeed)) != keccak256(bytes("good seed")));
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
            signer, signedMintValidationParams
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
            minter != address(0) && payer != address(0) && minter != payer
                && minter.code.length == 0 && payer.code.length == 0
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
            signer, signedMintValidationParams
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
            signer, signedMintValidationParams
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
                InvalidSignedMintPrice.selector, 0.1 ether, 0.11 ether
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
            signer, signedMintValidationParams
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
                InvalidSignedMaxTotalMintableByWallet.selector, 1001, 1000
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
            signer, signedMintValidationParams
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
            signer, signedMintValidationParams
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
            signer, signedMintValidationParams
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
                InvalidSignedMaxTokenSupplyForStage.selector, 1001, 1000
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
            signer, signedMintValidationParams
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
            signer, signedMintValidationParams
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
            signer, signedMintValidationParams
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

/// @dev Signed mint scenarios against a fully configured token: max supply
///      100, creator payout set, one allowed fee recipient, and one signer
///      registered with validation params. The Hardhat spec picked a random
///      salt per run; it is fuzzed here.
contract SeaDropMintSignedScenarioTest is TestHelper {
    using ECDSA for bytes32;

    address payer = makeAddr("payer");
    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");
    address signer = makeAddr("signer");

    MintParams mintParams;
    SignedMintValidationParams signedMintValidationParams;
    SignedMintValidationParams emptySignedMintValidationParams;

    function setUp() public {
        // Use a realistic timestamp so stage start times in the past are
        // representable.
        vm.warp(1_700_000_000);

        vm.deal(payer, 10_000 ether);
        vm.deal(minter, 10_000 ether);

        signedMintValidationParams = SignedMintValidationParams(
            1, // min mint price
            11, // max max total mintable by wallet
            50, // min start time
            100000000000, // max end time
            10000, // max max token supply for stage
            1, // min fee bps
            9000 // max fee bps
        );

        // Deploy the token. The test contract is the owner.
        token = _deployToken();

        mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            block.timestamp - 100, // start time
            block.timestamp + 100, // end time
            1, // drop stage index
            100, // max token supply for stage
            1000, // fee (10%)
            true // restrict fee recipients
        );

        // Add the signer.
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer,
            signedMintValidationParams
        );
    }

    function _deployToken() internal returns (ERC721SeaDrop newToken) {
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        newToken = new ERC721SeaDrop("", "", allowedSeaDrop);

        newToken.setMaxSupply(100);
        newToken.updateCreatorPayoutAddress(address(seadrop), creator);
        newToken.updateAllowedFeeRecipient(
            address(seadrop),
            feeRecipient,
            true
        );
    }

    /// @dev Sign a mint with the key derived from `signerName` and check
    ///      that the signature recovers to that signer.
    function _signMint(
        string memory signerName,
        address nftContract,
        address minter_,
        address feeRecipient_,
        MintParams memory params,
        uint256 salt
    ) internal returns (bytes memory signature) {
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            signerName,
            nftContract,
            minter_,
            feeRecipient_,
            params,
            salt
        );
        signature = abi.encodePacked(r, s, v);

        // Verify the recovered address matches the signer address.
        assertEq(
            _recover(nftContract, minter_, feeRecipient_, params, salt, signature),
            makeAddr(signerName)
        );
    }

    /// @dev The address SeaDrop recovers for `signature` over the given
    ///      mint data.
    function _recover(
        address nftContract,
        address minter_,
        address feeRecipient_,
        MintParams memory params,
        uint256 salt,
        bytes memory signature
    ) internal view returns (address) {
        return
            _getDigest(nftContract, minter_, feeRecipient_, params, salt)
                .recover(signature);
    }

    function _expectInvalidSignature(
        address nftContract,
        address minter_,
        address feeRecipient_,
        MintParams memory params,
        uint256 salt,
        bytes memory signature
    ) internal {
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidSignature.selector,
                _recover(
                    nftContract,
                    minter_,
                    feeRecipient_,
                    params,
                    salt,
                    signature
                )
            )
        );
    }

    function _expectSeaDropMint(
        address payer_,
        uint256 quantity,
        MintParams memory params
    ) internal {
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit SeaDropMint(
            address(token),
            minter,
            feeRecipient,
            payer_,
            quantity,
            params.mintPrice,
            params.feeBps,
            params.dropStageIndex
        );
    }

    function _assertSignedMintValidationParams(
        address signer_,
        SignedMintValidationParams memory expected
    ) internal view {
        SignedMintValidationParams memory actual = seadrop
            .getSignedMintValidationParams(address(token), signer_);
        assertEq(actual.minMintPrice, expected.minMintPrice);
        assertEq(
            actual.maxMaxTotalMintableByWallet,
            expected.maxMaxTotalMintableByWallet
        );
        assertEq(actual.minStartTime, expected.minStartTime);
        assertEq(actual.maxEndTime, expected.maxEndTime);
        assertEq(
            actual.maxMaxTokenSupplyForStage,
            expected.maxMaxTokenSupplyForStage
        );
        assertEq(actual.minFeeBps, expected.minFeeBps);
        assertEq(actual.maxFeeBps, expected.maxFeeBps);
    }

    function testMintSigned_payerAllowedAndSignatureUsedOnce(uint256 salt)
        public
    {
        salt = bound(salt, 0, type(uint256).max - 1);
        MintParams memory params = mintParams;

        // Mint signed with payer for minter.
        bytes memory signature = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        uint256 value = params.mintPrice * 3;
        vm.prank(payer);
        vm.expectRevert(PayerNotAllowed.selector);
        seadrop.mintSigned{ value: value }(
            address(token),
            feeRecipient,
            minter,
            3,
            params,
            salt,
            signature
        );

        // Allow the payer.
        token.updatePayer(address(seadrop), payer, true);

        _expectSeaDropMint(payer, 3, params);
        vm.prank(payer);
        seadrop.mintSigned{ value: value }(
            address(token),
            feeRecipient,
            minter,
            3,
            params,
            salt,
            signature
        );

        assertEq(token.balanceOf(minter), 3);
        assertEq(token.totalSupply(), 3);

        // Ensure a signature can only be used once.
        vm.prank(payer);
        vm.expectRevert(SignatureAlreadyUsed.selector);
        seadrop.mintSigned{ value: value }(
            address(token),
            feeRecipient,
            minter,
            3,
            params,
            salt,
            signature
        );

        // Mint signed with minter being payer. Change the salt to use a new
        // digest.
        uint256 newSalt = salt + 1;
        signature = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            newSalt
        );

        _expectSeaDropMint(minter, 3, params);
        vm.prank(minter);
        seadrop.mintSigned{ value: value }(
            address(token),
            feeRecipient,
            address(0),
            3,
            params,
            newSalt,
            signature
        );

        assertEq(token.balanceOf(minter), 6);
        assertEq(token.totalSupply(), 6);
    }

    /// @dev Mint 3 as `caller` and expect InvalidSignature with the address
    ///      SeaDrop recovers for the mint data it actually hashes.
    function _mintSignedExpectingInvalidSignature(
        address nftContract,
        address caller,
        address feeRecipient_,
        address minterIfNotPayer,
        MintParams memory params,
        uint256 salt,
        bytes memory signature
    ) internal {
        address hashedMinter = minterIfNotPayer == address(0)
            ? caller
            : minterIfNotPayer;
        _expectInvalidSignature(
            nftContract,
            hashedMinter,
            feeRecipient_,
            params,
            salt,
            signature
        );
        vm.prank(caller);
        seadrop.mintSigned{ value: params.mintPrice * 3 }(
            nftContract,
            feeRecipient_,
            minterIfNotPayer,
            3,
            params,
            salt,
            signature
        );
    }

    function testMintSigned_revertDifferentParams(uint256 salt) public {
        salt = bound(salt, 1, type(uint256).max);
        MintParams memory params = mintParams;

        // Sign the mint for the minter.
        bytes memory signature = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        // Test with a different minter address (the payer).
        _mintSignedExpectingInvalidSignature(
            address(token),
            payer,
            feeRecipient,
            payer,
            params,
            salt,
            signature
        );

        // Test with a different fee recipient (the payer).
        token.updateAllowedFeeRecipient(address(seadrop), payer, true);
        token.updatePayer(address(seadrop), payer, true);
        _mintSignedExpectingInvalidSignature(
            address(token),
            payer,
            payer,
            minter,
            params,
            salt,
            signature
        );

        // Test with a different token contract.
        {
            ERC721SeaDrop token2 = _deployToken();

            // Test coverage for error SignerNotPresent().
            vm.prank(address(token2));
            vm.expectRevert(SignerNotPresent.selector);
            seadrop.updateSignedMintValidationParams(
                address(uint160(0x8888888888888888888888888888888888888888)),
                emptySignedMintValidationParams
            );

            token2.updateSignedMintValidationParams(
                address(seadrop),
                signer,
                signedMintValidationParams
            );
            _mintSignedExpectingInvalidSignature(
                address(token2),
                payer,
                feeRecipient,
                address(0),
                params,
                salt,
                signature
            );
        }

        // Test with a signer that is not allowed.
        address signer2 = makeAddr("signer2");
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer2,
            signedMintValidationParams
        );
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer2,
            emptySignedMintValidationParams
        );
        _assertSignedMintValidationParams(
            signer2,
            emptySignedMintValidationParams
        );
        {
            address[] memory signers = seadrop.getSigners(address(token));
            assertEq(signers.length, 1);
            assertEq(signers[0], signer);
        }
        {
            bytes memory signature2 = _signMint(
                "signer2",
                address(token),
                minter,
                feeRecipient,
                params,
                salt
            );
            _mintSignedExpectingInvalidSignature(
                address(token),
                payer,
                feeRecipient,
                address(0),
                params,
                salt,
                signature2
            );
        }

        // Test with different mint params.
        {
            MintParams memory differentMintParams = mintParams;
            differentMintParams.maxTokenSupplyForStage = 10000;
            _mintSignedExpectingInvalidSignature(
                address(token),
                minter,
                feeRecipient,
                minter,
                differentMintParams,
                salt,
                signature
            );
        }

        // Test with a different salt.
        _mintSignedExpectingInvalidSignature(
            address(token),
            minter,
            feeRecipient,
            minter,
            params,
            salt - 1,
            signature
        );

        // Ensure that the zero address cannot be added as a signer.
        vm.expectRevert(SignerCannotBeZeroAddress.selector);
        token.updateSignedMintValidationParams(
            address(seadrop),
            address(0),
            signedMintValidationParams
        );

        // Remove the original signer for branch coverage.
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer,
            emptySignedMintValidationParams
        );
        _assertSignedMintValidationParams(
            signer,
            emptySignedMintValidationParams
        );

        // Add two signers and remove the second for branch coverage.
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer,
            signedMintValidationParams
        );
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer2,
            signedMintValidationParams
        );
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer2,
            emptySignedMintValidationParams
        );
        _assertSignedMintValidationParams(
            signer,
            SignedMintValidationParams(1, 11, 50, 100000000000, 10000, 1, 9000)
        );
        _assertSignedMintValidationParams(
            signer2,
            emptySignedMintValidationParams
        );
    }

    function testMintSigned_revertExceedsMaxMintsPerWallet(uint256 salt)
        public
    {
        MintParams memory params = mintParams;
        bytes memory signature = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        // Max mints per wallet is 10. Mint 10.
        _expectSeaDropMint(minter, 10, params);
        vm.prank(minter);
        seadrop.mintSigned{ value: params.mintPrice * 10 }(
            address(token),
            feeRecipient,
            address(0),
            10,
            params,
            salt,
            signature
        );

        // Try to mint one more.
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector,
                11,
                10
            )
        );
        seadrop.mintSigned{ value: params.mintPrice }(
            address(token),
            feeRecipient,
            address(0),
            1,
            params,
            salt,
            signature
        );

        // Try to mint one more with manipulated mint params.
        MintParams memory manipulatedParams = mintParams;
        manipulatedParams.maxTotalMintableByWallet = 11;
        _expectInvalidSignature(
            address(token),
            minter,
            feeRecipient,
            manipulatedParams,
            salt,
            signature
        );
        vm.prank(minter);
        seadrop.mintSigned{ value: params.mintPrice }(
            address(token),
            feeRecipient,
            address(0),
            1,
            manipulatedParams,
            salt,
            signature
        );
    }

    function testMintSigned_feeRoundsDownToZero(uint256 salt) public {
        MintParams memory paramsZeroFee = mintParams;
        paramsZeroFee.mintPrice = 1;
        paramsZeroFee.feeBps = 1;

        bytes memory signature = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            paramsZeroFee,
            salt
        );

        _expectSeaDropMint(minter, 3, paramsZeroFee);
        vm.prank(minter);
        seadrop.mintSigned{ value: 3 }(
            address(token),
            feeRecipient,
            minter,
            3,
            paramsZeroFee,
            salt,
            signature
        );

        assertEq(token.balanceOf(minter), 3);
        assertEq(token.totalSupply(), 3);
    }

    function testMintSigned_revertInvalidFeeBps(uint256 salt) public {
        MintParams memory paramsInvalidFeeBps = mintParams;
        paramsInvalidFeeBps.feeBps = 11_000;

        bytes memory signature = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            paramsInvalidFeeBps,
            salt
        );

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignedFeeBps.selector, 11_000, 9000)
        );
        seadrop.mintSigned{ value: paramsInvalidFeeBps.mintPrice }(
            address(token),
            feeRecipient,
            address(0),
            1,
            paramsInvalidFeeBps,
            salt,
            signature
        );
    }

    /// @dev Sign `params` for the minter and expect a mint of `quantity`
    ///      paying `value` to revert with `expectedRevert`.
    function _expectSignedMintRevert(
        MintParams memory params,
        uint256 salt,
        uint256 quantity,
        uint256 value,
        bytes memory expectedRevert
    ) internal {
        bytes memory signature = _signMint(
            "signer",
            address(token),
            minter,
            feeRecipient,
            params,
            salt
        );

        vm.prank(minter);
        vm.expectRevert(expectedRevert);
        seadrop.mintSigned{ value: value }(
            address(token),
            feeRecipient,
            address(0),
            quantity,
            params,
            salt,
            signature
        );
    }

    function testMintSigned_revertViolatesValidationParams(uint256 salt)
        public
    {
        // Testing a free mint price.
        MintParams memory newMintParams = mintParams;
        newMintParams.mintPrice = 0;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            2,
            0,
            abi.encodeWithSelector(
                InvalidSignedMintPrice.selector,
                0,
                signedMintValidationParams.minMintPrice
            )
        );

        uint256 mintQuantity = 2;
        uint256 value = mintParams.mintPrice * mintQuantity;

        newMintParams = mintParams;
        newMintParams.maxTotalMintableByWallet = 12;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            mintQuantity,
            value,
            abi.encodeWithSelector(
                InvalidSignedMaxTotalMintableByWallet.selector,
                12,
                signedMintValidationParams.maxMaxTotalMintableByWallet
            )
        );

        newMintParams = mintParams;
        newMintParams.startTime = 30;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            mintQuantity,
            value,
            abi.encodeWithSelector(
                InvalidSignedStartTime.selector,
                30,
                signedMintValidationParams.minStartTime
            )
        );

        newMintParams = mintParams;
        newMintParams.endTime =
            uint256(signedMintValidationParams.maxEndTime) +
            1;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            mintQuantity,
            value,
            abi.encodeWithSelector(
                InvalidSignedEndTime.selector,
                newMintParams.endTime,
                signedMintValidationParams.maxEndTime
            )
        );

        newMintParams = mintParams;
        newMintParams.maxTokenSupplyForStage = 10001;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            mintQuantity,
            value,
            abi.encodeWithSelector(
                InvalidSignedMaxTokenSupplyForStage.selector,
                10001,
                signedMintValidationParams.maxMaxTokenSupplyForStage
            )
        );

        newMintParams = mintParams;
        newMintParams.feeBps = 0;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            mintQuantity,
            value,
            abi.encodeWithSelector(
                InvalidSignedFeeBps.selector,
                0,
                signedMintValidationParams.minFeeBps
            )
        );

        newMintParams = mintParams;
        newMintParams.feeBps = 9010;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            mintQuantity,
            value,
            abi.encodeWithSelector(
                InvalidSignedFeeBps.selector,
                9010,
                signedMintValidationParams.maxFeeBps
            )
        );

        newMintParams = mintParams;
        newMintParams.restrictFeeRecipients = false;
        _expectSignedMintRevert(
            newMintParams,
            salt,
            mintQuantity,
            value,
            abi.encodeWithSelector(
                SignedMintsMustRestrictFeeRecipients.selector
            )
        );

        assertEq(token.totalSupply(), 0);
    }

    function testUpdateSignedMintValidationParams_revertInvalidFeeBps()
        public
    {
        SignedMintValidationParams
            memory invalidParams = signedMintValidationParams;
        invalidParams.minFeeBps = 11_000;
        vm.expectRevert(abi.encodeWithSelector(InvalidFeeBps.selector, 11_000));
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer,
            invalidParams
        );

        invalidParams = signedMintValidationParams;
        invalidParams.maxFeeBps = 12_000;
        vm.expectRevert(abi.encodeWithSelector(InvalidFeeBps.selector, 12_000));
        token.updateSignedMintValidationParams(
            address(seadrop),
            signer,
            invalidParams
        );
    }
}
