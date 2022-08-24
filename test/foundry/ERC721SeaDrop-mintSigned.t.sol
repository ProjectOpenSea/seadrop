// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { MintParams } from "seadrop/lib/SeaDropStructs.sol";

import {
    ECDSA
} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract ERC721DropTest is TestHelper {
    using ECDSA for bytes32;
    ERC721SeaDrop token2;

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
    }

    modifier validateFuzzInputsSigners(FuzzInputsSigners memory args) {
        vm.assume(args.numMints > 0 && args.numMints <= 10);
        vm.assume(
            args.feeRecipient.code.length == 0 && args.feeRecipient > address(9)
        );
        vm.assume(args.minter != address(0));
        _;
    }

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);
        token2 = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);
        token2.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);
        token2.updateCreatorPayoutAddress(address(seadrop), creator);
    }

    function testMintSigned(FuzzInputsSigners memory args)
        public
        validateFuzzInputsSigners(args)
    {
        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            address(token),
            args.minter,
            args.feeRecipient,
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.

        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        vm.prank(address(token));

        seadrop.updateSigner(signer, true);

        hoax(args.payer, 100 ether);

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * mintParams.mintPrice;

        seadrop.mintSigned{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
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
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            address(token),
            args.minter,
            args.feeRecipient,
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.

        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        vm.prank(address(token));

        seadrop.updateSigner(signer, true);

        vm.prank(address(token2));
        seadrop.updateSigner(signer, true);

        hoax(args.payer, 100 ether);

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * mintParams.mintPrice;

        seadrop.mintSigned{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
            signature
        );

        {
            bytes32 digest = _getDigest(
                address(token2),
                args.minter,
                args.feeRecipient,
                mintParams
            );
            address expectedRecovered = digest.recover(signature);

            vm.expectRevert(
                abi.encodeWithSelector(
                    InvalidSignature.selector,
                    expectedRecovered
                )
            );
        }
        seadrop.mintSigned{ value: mintValue }(
            address(token2),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
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
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            address(token),
            args.minter,
            args.feeRecipient,
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.

        // Update the approved signers of the token contract.
        {
            address signer = makeAddr(args.signerNameSeed);
            vm.prank(address(token));

            seadrop.updateSigner(signer, true);
        }

        hoax(args.payer, 100 ether);

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

        bytes32 badDigest = _getDigest(
            address(token),
            args.minter,
            badFeeRecipient,
            mintParams
        );
        address expectedRecovered = badDigest.recover(signature);

        vm.expectRevert(
            abi.encodeWithSelector(InvalidSignature.selector, expectedRecovered)
        );

        seadrop.mintSigned{ value: args.numMints * mintParams.mintPrice }(
            address(token),
            badFeeRecipient,
            args.minter,
            args.numMints,
            mintParams,
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
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            address(token),
            args.minter,
            args.feeRecipient,
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.
        vm.prank(address(token));

        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        seadrop.updateSigner(signer, true);

        hoax(args.payer, 100 ether);

        seadrop.mintSigned(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints,
            mintParams,
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
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            true // restrictFeeRecipient
        );

        // Get the signature components.
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            args.signerNameSeed,
            address(token),
            args.minter,
            args.feeRecipient,
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.
        vm.prank(address(token));

        // Update the approved signers of the token contract.
        address signer = makeAddr(args.signerNameSeed);
        seadrop.updateSigner(signer, true);

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
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
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
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.
        vm.prank(address(token));
        // Update the approved signers of the token contract.
        address signer = makeAddr("good seed");
        seadrop.updateSigner(signer, true);

        address expectedRecovered = makeAddr(signerSeed);

        vm.deal(msg.sender, 100 ether);

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
            signature
        );
    }

    function testMintSigned_differentPayerThanMinter(
        address minter,
        address payer
    ) public {
        vm.assume(
            minter != address(0) && payer != address(0) && minter != payer
        );

        // Create a MintParams object.
        MintParams memory mintParams = MintParams(
            0.1 ether, // mint price
            10, // max mints per wallet
            uint64(block.timestamp), // start time
            uint64(block.timestamp) + 1000, // end time
            1,
            1000,
            100, // fee (1%)
            false // restrictFeeRecipient
        );
        address feeRecipient = address(1);

        // Get the signature components with a valid signer
        (bytes32 r, bytes32 s, uint8 v) = _getSignatureComponents(
            "good seed",
            address(token),
            minter,
            feeRecipient,
            mintParams
        );

        // Create the signature from the components.
        bytes memory signature = abi.encodePacked(r, s, v);

        // Impersonate the token contract to update the signers.
        vm.prank(address(token));
        // Update the approved signers of the token contract.
        address signer = makeAddr("good seed");
        seadrop.updateSigner(signer, true);

        hoax(payer, 100 ether);

        vm.expectEmit(true, false, false, false);
        emit Transfer(address(0), minter, 1);

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(address(0), minter, 1);

        seadrop.mintSigned{ value: mintParams.mintPrice * 2 }(
            address(token),
            feeRecipient,
            minter,
            2,
            mintParams,
            signature
        );
    }
}
