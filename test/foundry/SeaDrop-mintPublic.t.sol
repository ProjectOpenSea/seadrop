// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { RaribleDrop } from "raribleDrop/RaribleDrop.sol";

import { ERC721PartnerRaribleDrop } from "raribleDrop/ERC721PartnerRaribleDrop.sol";

import {
    INonFungibleRaribleDropToken
} from "raribleDrop/interfaces/INonFungibleRaribleDropToken.sol";

import { PublicDrop } from "raribleDrop/lib/RaribleDropStructs.sol";

import { MaliciousRecipient } from "raribleDrop/test/MaliciousRecipient.sol";

contract ERC721RaribleDropMintPublicTest is TestHelper {
    MaliciousRecipient attacker;

    function setUp() public {
        attacker = new MaliciousRecipient();
        // Deploy the ERC721PartnerRaribleDrop token.
        address[] memory allowedRaribleDrop = new address[](1);
        allowedRaribleDrop[0] = address(raribleDrop);
        token = new ERC721PartnerRaribleDrop("", "", address(this), allowedRaribleDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(raribleDrop), creator);

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
        raribleDrop.updatePublicDrop(publicDrop);
    }

    function testMintPublicReenter() public payable {
        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            1 ether, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp) + 100, // end time
            1, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
            // If true, then only the fee recipient can perform the attack
        );
        vm.prank(address(token));
        raribleDrop.updatePublicDrop(publicDrop);

        assert(!attacker.startAttack());
        // send some eth and set startAttack
        attacker.setStartAttack{ value: 10 ether }();
        assert(attacker.startAttack());

        assertEq(token.balanceOf(address(attacker)), 0);
        assertEq(
            uint256(
                raribleDrop.getPublicDrop(address(token)).maxTotalMintableByWallet
            ),
            1
        );

        // expect fail on reentrancy
        vm.expectRevert("ETH_TRANSFER_FAILED");
        attacker.attack(raribleDrop, address(token));
    }

    function testMintPublic(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = raribleDrop.getPublicDrop(address(token));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        hoax(args.minter, 100 ether);

        uint256 preMinterBalance = args.minter.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        raribleDrop.mintPublic{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints
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
        PublicDrop memory publicDrop = raribleDrop.getPublicDrop(address(token));
        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.expectRevert(
            abi.encodeWithSelector(IncorrectPayment.selector, 1, mintValue)
        );

        hoax(args.minter, 100 ether);

        raribleDrop.mintPublic{ value: 1 wei }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints
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
        raribleDrop.updatePublicDrop(publicDrop);

        vm.prank(args.minter);

        raribleDrop.mintPublic(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintPublic_differentPayerThanMinter(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        PublicDrop memory publicDrop = raribleDrop.getPublicDrop(address(token));

        address payer = makeAddr("payer");

        // Allow the payer.
        token.updatePayer(address(raribleDrop), payer, true);

        vm.assume(
            payer != creator &&
                payer != args.minter &&
                payer != args.feeRecipient
        );

        hoax(payer, 100 ether);

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        uint256 prePayerBalance = payer.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        raribleDrop.mintPublic{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            args.numMints
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

    function testMintRaribleDrop_revertNonRaribleDrop(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        vm.expectRevert(INonFungibleRaribleDropToken.OnlyAllowedRaribleDrop.selector);
        token.mintRaribleDrop(args.minter, args.numMints);
    }
}
