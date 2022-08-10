// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { TestHelper } from "./utils/TestHelper.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import { Conduit, PublicDrop } from "seadrop/lib/SeaDropStructs.sol";

contract ERC721DropTest is Test, TestHelper, SeaDropErrorsAndEvents {
    SeaDrop seadrop;
    ERC721SeaDrop test;

    address creator = makeAddr("creator");

    struct FuzzInputs {
        uint40 numMints;
        address minter;
        address feeRecipient;
    }

    modifier validateArgs(FuzzInputs memory args) {
        vm.assume(args.numMints > 0 && args.numMints <= 10);
        vm.assume(args.minter != address(0) && args.feeRecipient != address(0));
        vm.assume(
            args.feeRecipient.code.length == 0 && args.feeRecipient > address(9)
        );
        vm.assume(
            args.minter != args.feeRecipient &&
                args.minter != creator &&
                args.feeRecipient != creator
        );
        _;
    }

    function setUp() public {
        // Deploy SeaDrop.
        seadrop = new SeaDrop();

        // Deploy test ERC721SeaDrop.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        test = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);

        // Set maxSupply to 1000.
        test.setMaxSupply(1000);

        // Set creator payout address.
        test.updateCreatorPayoutAddress(address(seadrop), creator);

        // Create public drop object.
        PublicDrop memory publicDrop = PublicDrop(
            0.1 ether, // mint price
            uint64(block.timestamp), // start time
            10, // max mints per wallet
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Impersonate test erc721 contract.
        vm.prank(address(test));

        // Set the public drop for the erc721 contract.
        seadrop.updatePublicDrop(publicDrop);
        /**
        // Set the allow list merkle root.
        seaport.updateAllowList(allowList);

        // Set the token gated drop stage.
        seaport.updateTokenGatedDrop(tokenGatedDropStage);

        // Set the signers for server signed drops.
        seaport.updateSigners(signers);
        */
    }

    function testMintPublic(FuzzInputs memory args) public validateArgs(args) {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(test));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        hoax(args.minter, 100 ether);

        uint256 preMinterBalance = args.minter.balance;
        uint256 preFeeRecipientBalance = args.feeRecipient.balance;
        uint256 preCreatorBalance = creator.balance;

        seadrop.mintPublic{ value: mintValue }(
            address(test),
            args.feeRecipient,
            args.numMints,
            Conduit(address(0), bytes32(0))
        );

        // Check minter token balance increased.
        assertEq(test.balanceOf(args.minter), args.numMints);

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
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(test));
        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.expectRevert(
            abi.encodeWithSelector(IncorrectPayment.selector, 1, mintValue)
        );

        vm.deal(args.minter, 100 ether);
        vm.prank(args.minter);

        seadrop.mintPublic{ value: 1 wei }(
            address(test),
            args.feeRecipient,
            args.numMints,
            Conduit(address(0), bytes32(0))
        );
    }

    function testMintSeaDrop_revertNonSeaDrop(FuzzInputs memory args)
        public
        validateArgs(args)
    {
        PublicDrop memory publicDrop = seadrop.getPublicDrop(address(test));

        uint256 mintValue = args.numMints * publicDrop.mintPrice;

        vm.deal(args.minter, 100 ether);
        vm.expectRevert(IERC721SeaDrop.OnlySeaDrop.selector);

        test.mintSeaDrop{ value: mintValue }(args.minter, args.numMints);
    }

    /**
    function testMintAllowList(FuzzInputs memory args) public validateArgs(args) {
        MintParams memory mintParams = seadrop.getPublicDrop(address(test));

        uint256 mintValue = args.numMints * mintParams.mintPrice;

        vm.deal(args.minter, 100 ether);
        vm.prank(args.minter);

        seadrop.mintAllowList{ value: mintValue }(
            address(test),
            args.feeRecipient,
            args.numMints,
            mintParams,
            Conduit(address(0), bytes32(0))
        );

        assertEq(test.balanceOf(args.minter), args.numMints);
    }

    // testMintAllowList_unauthorizedMinter
    // testMintAllowList_unauthorizedFeeRecipient
    // testMintAllowList_exceedsMaxMintableByWallet
    // testMintSigned
    // testMintSigned_unknownSigner
    // testMintAllowedTokenHolder
    // testMintAllowedTokenHolder_alreadyRedeemed
    // testMintAllowedTokenHolder_notOwner
    // set saleToken and test with and without conduit,
    //     with and without balance and approvals
    // reset saleToken and mint with ether
    */
}
