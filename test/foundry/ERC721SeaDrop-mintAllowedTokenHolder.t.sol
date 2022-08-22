// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { TestERC721 } from "test/foundry/utils/TestERC721.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { IERC721SeaDrop } from "seadrop/interfaces/IERC721SeaDrop.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

import {
    TokenGatedMintParams,
    TokenGatedDropStage
} from "seadrop/lib/SeaDropStructs.sol";

contract ERC721DropTest is Test, TestHelper, SeaDropErrorsAndEvents {
    SeaDrop seadrop;
    ERC721SeaDrop test;

    struct FuzzInputsAllowedTokenHolders {
        uint16 numMints;
        address minter;
        address feeRecipient;
        uint16 numAllowedNftToken;
    }

    modifier validateAllowedTokenHoldersArgs(
        FuzzInputsAllowedTokenHolders memory args
    ) {
        vm.assume(args.numMints > 0 && args.numMints < 20);
        vm.assume(args.minter != address(0) && args.feeRecipient != address(0));
        vm.assume(
            args.feeRecipient.code.length == 0 && args.feeRecipient > address(9)
        );
        vm.assume(
            args.minter != args.feeRecipient &&
                args.minter != creator &&
                args.feeRecipient != creator
        );
        vm.assume(args.numAllowedNftToken > 0 && args.numAllowedNftToken < 5);
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
    }

    function _deployAndMintGateToken(address minter, uint256[] memory tokenIds)
        internal
        returns (address)
    {
        // Create new ERC721 for token gating.
        TestERC721 gateToken = new TestERC721();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Mint tokenId to minter address.
            gateToken.mint(minter, tokenIds[i]);
        }

        // Return the address of the newly created token.
        return address(gateToken);
    }

    function testMintAllowedTokenHolder(
        FuzzInputsAllowedTokenHolders memory args
    ) public validateAllowedTokenHoldersArgs(args) {
        // Create TokenGatedDropStage object.
        TokenGatedDropStage memory tokenGatedDropStage = TokenGatedDropStage(
            0.1 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Declare TokenGatedMintParams array.
        TokenGatedMintParams[]
            memory tokenGatedMintParamsArray = new TokenGatedMintParams[](
                args.numAllowedNftToken
            );

        // Iterate over the fuzzed number of gate tokens.
        for (uint256 i = 0; i < args.numAllowedNftToken; i++) {
            uint256[] memory tokenIds = new uint256[](args.numMints);

            for (uint256 j = 0; j < args.numMints; j++) {
                tokenIds[j] = j;
            }

            // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
            address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

            vm.prank(address(test));
            // Update token gated drop for the deployed gateToken.
            seadrop.updateTokenGatedDrop(gateToken, tokenGatedDropStage);

            // Add TokenGatedMintParams object to the array.
            tokenGatedMintParamsArray[i] = TokenGatedMintParams(
                gateToken,
                tokenIds
            );
        }

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints *
            args.numAllowedNftToken *
            tokenGatedDropStage.mintPrice;

        // Call mintAllowedTokenHolder.
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(test),
            args.feeRecipient,
            args.minter,
            tokenGatedMintParamsArray
        );

        // Calculate the expected number of tokens to be minted to the minter.
        uint256 mintQuantity = args.numAllowedNftToken * args.numMints;

        // Check minter token balance increased.
        assertEq(test.balanceOf(args.minter), mintQuantity);
    }

    function testMintAllowedTokenHolder_revertAlreadyRedeemed(
        FuzzInputsAllowedTokenHolders memory args
    ) public validateAllowedTokenHoldersArgs(args) {
        // Create TokenGatedDropStage object.
        TokenGatedDropStage memory tokenGatedDropStage = TokenGatedDropStage(
            0.1 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        // Declare TokenGatedMintParams array.
        TokenGatedMintParams[]
            memory tokenGatedMintParamsArray = new TokenGatedMintParams[](
                args.numAllowedNftToken
            );

        // Iterate over the fuzzed number of gate tokens.
        for (uint256 i = 0; i < args.numAllowedNftToken; i++) {
            uint256[] memory tokenIds = new uint256[](args.numMints);

            for (uint256 j = 0; j < args.numMints; j++) {
                tokenIds[j] = j;
            }

            // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
            address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

            vm.prank(address(test));
            // Update token gated drop for the deployed gateToken.
            seadrop.updateTokenGatedDrop(gateToken, tokenGatedDropStage);

            // Add TokenGatedMintParams object to the array.
            tokenGatedMintParamsArray[i] = TokenGatedMintParams(
                gateToken,
                tokenIds
            );
        }

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints *
            args.numAllowedNftToken *
            tokenGatedDropStage.mintPrice;

        // Call mintAllowedTokenHolder.
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(test),
            args.feeRecipient,
            args.minter,
            tokenGatedMintParamsArray
        );

        // Calculate the expected number of tokens to be minted to the minter.
        uint256 mintQuantity = args.numAllowedNftToken * args.numMints;

        // Check minter token balance increased.
        assertEq(test.balanceOf(args.minter), mintQuantity);

        // Create TokenGatedMintParams array of length 1 with the first
        // TokenGatedMintParams of the original array.
        TokenGatedMintParams[]
            memory revertTokenGatedMintParamsArray = new TokenGatedMintParams[](
                1
            );
        revertTokenGatedMintParamsArray[0] = tokenGatedMintParamsArray[0];

        // Expect revert since the tokens were already minted in the previous call.
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGatedTokenIdAlreadyRedeemed.selector,
                address(test),
                revertTokenGatedMintParamsArray[0].allowedNftToken,
                revertTokenGatedMintParamsArray[0].allowedNftTokenIds[0]
            )
        );

        // Attempt to call mintAllowedTokenHolder with the
        // TokenGatedMintParams from the previous call.
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(test),
            args.feeRecipient,
            args.minter,
            tokenGatedMintParamsArray
        );
    }

    // testMintAllowedTokenHolder_notOwner
    // testMintAllowedTokenHolder_differentPayerThanMinter
    // testMintAllowedTokenHolder_freeMint
}
