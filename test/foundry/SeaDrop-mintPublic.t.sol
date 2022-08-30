// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721PartnerSeaDrop } from "seadrop/ERC721PartnerSeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/SeaDropStructs.sol";

contract MaliciousRecipient {
    bool public startAttack;
    address public token;
    SeaDrop public seaDrop;

    fallback() external payable {
        if (startAttack) {
            startAttack = false;
            seaDrop.mintPublic{ value: 1 ether }({
                nftContract: token,
                feeRecipient: address(this),
                minterIfNotPayer: address(this),
                quantity: 1
            });
        }
    }

    // Also receive some eth in the process
    function setStartAttack() public payable {
        startAttack = true;
    }

    function attack(SeaDrop _seaDrop, address _token) external payable {
        token = _token;
        seaDrop = _seaDrop;

        _seaDrop.mintPublic{ value: 1 ether }({
            nftContract: _token,
            feeRecipient: address(this),
            minterIfNotPayer: address(this),
            quantity: 1
        });

        token = address(0);
        seaDrop = SeaDrop(address(0));
    }
}

contract ERC721SeaDropMintPublicTest is TestHelper {
    MaliciousRecipient attacker;

    function setUp() public {
        attacker = new MaliciousRecipient();
        // Deploy the ERC721PartnerSeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721PartnerSeaDrop("", "", address(this), allowedSeaDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);

        // Create the public drop stage.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint64(block.timestamp), // start time
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
            uint64(block.timestamp), // start time
            1, // max mints per wallet
            100, // fee (1%)
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
            1
        );

        // expect fail on reentrancy
        vm.expectRevert("ETH_TRANSFER_FAILED");
        attacker.attack(seadrop, address(token));
    }

    function testMintPublic(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        hoax(args.minter, 100 ether);

        uint256 preMinterBalance = args.minter.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        seadrop.mintPublic{ value: mintValue }(
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
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));
        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.expectRevert(
            abi.encodeWithSelector(IncorrectPayment.selector, 1, mintValue)
        );

        hoax(args.minter, 100 ether);

        seadrop.mintPublic{ value: 1 wei }(
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
            uint64(block.timestamp), // start time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        vm.prank(address(token));
        // Set the public drop for the erc721 contract.
        seadrop.updatePublicDrop(publicDrop);

        vm.prank(args.minter);

        seadrop.mintPublic(
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
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));

        address payer = makeAddr("payer");

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

        seadrop.mintPublic{ value: mintValue }(
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

    function testMintSeaDrop_revertNonSeaDrop(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(token));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.deal(args.minter, 100 ether);
        vm.expectRevert(IERC721SeaDrop.OnlySeaDrop.selector);

        token.mintSeaDrop{ value: mintValue }(args.minter, args.numMints);
    }

    // testMintPublic_revertFeeRecipientNotAllowed
}
