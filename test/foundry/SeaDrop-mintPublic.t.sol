// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    INonFungibleSeaDropToken
} from "seadrop/interfaces/INonFungibleSeaDropToken.sol";

import { PublicDrop } from "seadrop/lib/SeaDropStructs.sol";

import { MaliciousRecipient } from "seadrop/test/MaliciousRecipient.sol";

contract ERC721SeaDropMintPublicTest is TestHelper {
    MaliciousRecipient attacker;

    function setUp() public {
        attacker = new MaliciousRecipient();
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", allowedSeaDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);

        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Impersonate the token contract.
        vm.prank(address(token));

        // Set the public drop for the token contract.
        seadrop.updatePublicDrop(publicDrop);
    }

    function testMintPublicReenter() public payable {
        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            1 ether, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
            2, // max mints per wallet, so the nested mint reaches the guard
            100, // fee (1%), so the reentry happens on the fee transfer
            false // if false, allow any fee recipient
            // If true, then only the fee recipient can perform the attack
        );
        vm.prank(address(token));
        seadrop.updatePublicDrop(publicDrop);

        assert(!attacker.startAttack());
        // send some eth and set startAttack
        attacker.setStartAttack{ value: 10 ether }();
        assert(attacker.startAttack());

        assertEq(token.balanceOf(address(attacker)), 0);
        assertEq(
            uint256(
                seadrop.getPublicDrop(address(token)).maxTotalMintableByWallet
            ),
            2
        );

        // expect fail on reentrancy
        vm.expectRevert("ETH_TRANSFER_FAILED");
        attacker.attack(seadrop, address(token));
        assertEq(token.totalSupply(), 0);
    }

    function testMintPublic(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        hoax(args.minter, 100 ether);

        uint256 preMinterBalance = args.minter.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        seadrop.mintPublic{ value: mintValue }(
            address(token), args.feeRecipient, args.minter, args.numMints
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);

        // Check minter ether balance decreased.
        assertEq(preMinterBalance - mintValue, args.minter.balance);

        // Check fee recipient ether balance increased.
        uint256 feeAmount = (mintValue * 100) / 10_000;
        assertEq(preFeeRecipientBalance + feeAmount, args.feeRecipient.balance);

        // Check creator ether balance increased.
        uint256 payoutAmount = mintValue - feeAmount;
        assertEq(preCreatorBalance + payoutAmount, creator.balance);
    }

    function testMintPublic_incorrectPayment(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));
        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.expectRevert(
            abi.encodeWithSelector(IncorrectPayment.selector, 1, mintValue)
        );

        hoax(args.minter, 100 ether);

        seadrop.mintPublic{ value: 1 wei }(
            address(token), args.feeRecipient, args.minter, args.numMints
        );
    }

    function testMintPublic_freeMint(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        // Create public drop object with free mint.
        PublicDrop memory publicDrop = PublicDrop(
            0 ether, // mint price (free)
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        vm.prank(address(token));
        // Set the public drop for the erc721 contract.
        seadrop.updatePublicDrop(publicDrop);

        vm.prank(args.minter);

        seadrop.mintPublic(
            address(token), args.feeRecipient, args.minter, args.numMints
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintPublic_differentPayerThanMinter(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));

        address payer = makeAddr("payer");

        // Allow the payer.
        token.updatePayer(address(seadrop), payer, true);

        vm.assume(
            payer != creator && payer != args.minter
                && payer != args.feeRecipient
        );

        hoax(payer, 100 ether);

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        uint256 prePayerBalance = payer.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        seadrop.mintPublic{ value: mintValue }(
            address(token), args.feeRecipient, args.minter, args.numMints
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);

        // Check payer ether balance decreased.
        assertEq(prePayerBalance - mintValue, payer.balance);

        // Check fee recipient ether balance increased.
        uint256 feeAmount = (mintValue * 100) / 10_000;
        assertEq(preFeeRecipientBalance + feeAmount, args.feeRecipient.balance);

        // Check creator ether balance increased.
        uint256 payoutAmount = mintValue - feeAmount;
        assertEq(preCreatorBalance + payoutAmount, creator.balance);
    }

    function testMintSeaDrop_revertNonSeaDrop(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        vm.expectRevert(INonFungibleSeaDropToken.OnlyAllowedSeaDrop.selector);
        token.mintSeaDrop(args.minter, args.numMints);
    }
}

/// @dev Public mint scenarios against a fully configured token: max supply
///      100, creator payout set, and a public drop that restricts fee
///      recipients to an allowed one.
contract SeaDropMintPublicScenarioTest is TestHelper {
    address payer = makeAddr("payer");
    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");

    PublicDrop publicDrop;

    function setUp() public {
        // Use a realistic timestamp so stage start times in the past are
        // representable.
        vm.warp(1_700_000_000);

        vm.deal(payer, 10_000 ether);
        vm.deal(minter, 10_000 ether);

        // Deploy the ERC721SeaDrop token. The test contract is the owner.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", allowedSeaDrop);

        // Configure the token.
        token.setMaxSupply(100);
        token.updateCreatorPayoutAddress(address(seadrop), creator);
        publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint48(block.timestamp - 100), // start time
            uint48(block.timestamp + 100), // end time
            10, // max mints per wallet
            1000, // fee (10%)
            true // restrict fee recipients
        );
        token.updatePublicDrop(address(seadrop), publicDrop);
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);
    }

    function _expectSeaDropMint(
        address minter_,
        address payer_,
        uint256 quantity,
        uint256 feeBps
    ) internal {
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit SeaDropMint(
            address(token),
            minter_,
            feeRecipient,
            payer_,
            quantity,
            publicDrop.mintPrice,
            feeBps,
            0 // drop stage index (0 for public)
        );
    }

    function testMintPublic_withAllowedPayer() public {
        // Mint public with payer for minter.
        uint256 value = uint256(publicDrop.mintPrice) * 3;
        vm.prank(payer);
        vm.expectRevert(PayerNotAllowed.selector);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, 3
        );

        assertEq(seadrop.getPayers(address(token)).length, 0);
        assertFalse(seadrop.getPayerIsAllowed(address(token), payer));

        // Allow the payer.
        token.updatePayer(address(seadrop), payer, true);

        address[] memory payers = seadrop.getPayers(address(token));
        assertEq(payers.length, 1);
        assertEq(payers[0], payer);
        assertTrue(seadrop.getPayerIsAllowed(address(token), payer));

        _expectSeaDropMint(minter, payer, 3, publicDrop.feeBps);
        vm.prank(payer);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, 3
        );

        assertEq(token.balanceOf(minter), 3);
        assertEq(token.totalSupply(), 3);

        // Mint public with minter being payer.
        _expectSeaDropMint(minter, minter, 3, publicDrop.feeBps);
        vm.prank(minter);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, address(0), 3
        );

        assertEq(token.balanceOf(minter), 6);
        assertEq(token.totalSupply(), 6);
    }

    function testMintPublic_revertNotStarted() public {
        // Set start time in the future.
        publicDrop.startTime = uint48(block.timestamp + 100);
        token.updatePublicDrop(address(seadrop), publicDrop);

        bytes memory expectedRevert = abi.encodeWithSelector(
            NotActive.selector,
            block.timestamp,
            publicDrop.startTime,
            publicDrop.endTime
        );

        // Mint public with payer for minter.
        uint256 value = uint256(publicDrop.mintPrice) * 3;
        vm.prank(payer);
        vm.expectRevert(expectedRevert);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, 3
        );

        // Mint public with minter being payer.
        vm.prank(minter);
        vm.expectRevert(expectedRevert);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, address(0), 3
        );
    }

    function testMintPublic_revertEnded() public {
        // Set end time in the past.
        publicDrop.endTime = uint48(block.timestamp - 100);
        token.updatePublicDrop(address(seadrop), publicDrop);

        bytes memory expectedRevert = abi.encodeWithSelector(
            NotActive.selector,
            block.timestamp,
            publicDrop.startTime,
            publicDrop.endTime
        );

        // Mint public with payer for minter.
        uint256 value = uint256(publicDrop.mintPrice) * 3;
        vm.prank(payer);
        vm.expectRevert(expectedRevert);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, 3
        );

        // Mint public with minter being payer.
        vm.prank(minter);
        vm.expectRevert(expectedRevert);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, address(0), 3
        );
    }

    function testMintPublic_maxMintsPerWalletAndMaxSupply() public {
        // Update max limit per wallet to 2.
        publicDrop.maxTotalMintableByWallet = 2;
        token.updatePublicDrop(address(seadrop), publicDrop);

        // Update max supply to 1.
        token.setMaxSupply(1);

        // Mint one.
        uint256 value = publicDrop.mintPrice;
        _expectSeaDropMint(minter, minter, 1, publicDrop.feeBps);
        vm.prank(minter);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, 1
        );

        // Minting the next should revert with MintQuantityExceedsMaxSupply.
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(MintQuantityExceedsMaxSupply.selector, 2, 1)
        );
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, 1
        );

        // Update max supply to 3.
        token.setMaxSupply(3);

        // Mint one.
        _expectSeaDropMint(minter, minter, 1, publicDrop.feeBps);
        vm.prank(minter);
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, address(0), 1
        );

        // Minting the next should revert with
        // MintQuantityExceedsMaxMintedPerWallet.
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector, 3, 2
            )
        );
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, 1
        );
    }

    function testMintPublic_revertIncorrectPayment() public {
        // Pay for only 1 mint, but request quantity of 2.
        uint256 value = publicDrop.mintPrice;
        uint256 mintQuantity = 2;
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                IncorrectPayment.selector,
                value,
                uint256(publicDrop.mintPrice) * mintQuantity
            )
        );
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, minter, mintQuantity
        );

        // Pay for 3 mints but request quantity of 2.
        value = uint256(publicDrop.mintPrice) * 3;
        mintQuantity = 2;
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IncorrectPayment.selector,
                value,
                uint256(publicDrop.mintPrice) * mintQuantity
            )
        );
        seadrop.mintPublic{ value: value }(
            address(token), feeRecipient, address(0), mintQuantity
        );
    }

    function testMintPublic_revertInvalidFeeRecipient() public {
        uint256 value = publicDrop.mintPrice;

        vm.prank(minter);
        vm.expectRevert(FeeRecipientCannotBeZeroAddress.selector);
        seadrop.mintPublic{ value: value }(
            address(token), address(0), minter, 1
        );

        vm.prank(minter);
        vm.expectRevert(FeeRecipientNotAllowed.selector);
        seadrop.mintPublic{ value: value }(address(token), creator, minter, 1);
    }

    function testUpdatePublicDrop_revertInvalidFeeBps() public {
        publicDrop.feeBps = 15_000;
        vm.expectRevert(abi.encodeWithSelector(InvalidFeeBps.selector, 15_000));
        token.updatePublicDrop(address(seadrop), publicDrop);
    }

    function testMintPublic_zeroFeeBps() public {
        publicDrop.feeBps = 0;
        token.updatePublicDrop(address(seadrop), publicDrop);

        _expectSeaDropMint(minter, minter, 1, 0);
        vm.prank(minter);
        seadrop.mintPublic{ value: publicDrop.mintPrice }(
            address(token), feeRecipient, address(0), 1
        );
    }

    function testMintPublic_revertZeroQuantity() public {
        vm.prank(minter);
        vm.expectRevert(MintQuantityCannotBeZero.selector);
        seadrop.mintPublic(address(token), feeRecipient, minter, 0);
    }
}
