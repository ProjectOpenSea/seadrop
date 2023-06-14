// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { TestERC721 } from "raribleDrop/test/TestERC721.sol";

import { RaribleDrop } from "raribleDrop/RaribleDrop.sol";

import { ERC721PartnerRaribleDrop } from "raribleDrop/ERC721PartnerRaribleDrop.sol";

import {
    TokenGatedMintParams,
    TokenGatedDropStage
} from "raribleDrop/lib/RaribleDropStructs.sol";

contract ERC721DropTest is TestHelper {
    struct FuzzInputsAllowedTokenHolders {
        uint16 numMints;
        address minter;
        address feeRecipient;
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
        _;
    }

    function setUp() public {
        // Deploy the ERC721PartnerRaribleDrop token.
        address[] memory allowedRaribleDrop = new address[](1);
        allowedRaribleDrop[0] = address(raribleDrop);
        token = new ERC721PartnerRaribleDrop("", "", address(this), allowedRaribleDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(raribleDrop), creator);
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
        // Create the token gated drop stage.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage(
            0.1 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        uint256[] memory tokenIds = new uint256[](args.numMints);

        // Iterate over the fuzzed number of mints.
        for (uint256 j = 0; j < args.numMints; j++) {
            tokenIds[j] = j;
        }

        // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
        address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

        vm.prank(address(token));
        // Update token gated drop for the deployed gateToken.
        raribleDrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Prank the mint call as the minter.
        hoax(args.minter, 100 ether);

        // Call mintAllowedTokenHolder as the minter.
        raribleDrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            mintParams
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintAllowedTokenHolder_differentPayerThanMinter(
        FuzzInputsAllowedTokenHolders memory args
    ) public validateAllowedTokenHoldersArgs(args) {
        // Create TokenGatedDropStage object.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage(
            0.1 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        uint256[] memory tokenIds = new uint256[](args.numMints);

        for (uint256 j = 0; j < args.numMints; j++) {
            tokenIds[j] = j;
        }

        // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
        address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

        vm.prank(address(token));
        // Update token gated drop for the deployed gateToken.
        raribleDrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Derive an address to call the transaction with.
        address payer = makeAddr("payer");

        // Allow the payer.
        token.updatePayer(address(raribleDrop), payer, true);

        hoax(payer, 100 ether);

        // Call mintAllowedTokenHolder as the payer.
        raribleDrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            mintParams
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintAllowedTokenHolder_revertAlreadyRedeemed(
        FuzzInputsAllowedTokenHolders memory args
    ) public validateAllowedTokenHoldersArgs(args) {
        // Create the token gated drop stage.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage(
            0.1 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        uint256[] memory tokenIds = new uint256[](args.numMints);

        for (uint256 j = 0; j < args.numMints; j++) {
            tokenIds[j] = j;
        }

        // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
        address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

        vm.prank(address(token));
        // Update token gated drop for the deployed gateToken.
        raribleDrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Call mintAllowedTokenHolder.
        hoax(args.minter, 100 ether);
        raribleDrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            mintParams
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);

        // Expect revert since the tokens were already minted in the previous call.
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGatedTokenIdAlreadyRedeemed.selector,
                address(token),
                mintParams.allowedNftToken,
                mintParams.allowedNftTokenIds[0]
            )
        );

        // Attempt to call mintAllowedTokenHolder with the
        // TokenGatedMintParams from the previous call.
        hoax(args.minter, 100 ether);
        raribleDrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            mintParams
        );
    }

    function testMintAllowedTokenHolder_freeMint(
        FuzzInputsAllowedTokenHolders memory args
    ) public validateAllowedTokenHoldersArgs(args) {
        // Create TokenGatedDropStage object with free mint.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage(
            0 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        uint256[] memory tokenIds = new uint256[](args.numMints);

        for (uint256 j = 0; j < args.numMints; j++) {
            tokenIds[j] = j;
        }

        // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
        address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

        vm.prank(address(token));

        // Update token gated drop for the deployed gateToken.
        raribleDrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );

        // Call mintAllowedTokenHolder.
        hoax(args.minter, 100 ether);
        raribleDrop.mintAllowedTokenHolder(
            address(token),
            args.feeRecipient,
            args.minter,
            mintParams
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintAllowedTokenHolder_revertNotOwner(
        FuzzInputsAllowedTokenHolders memory args
    ) public validateAllowedTokenHoldersArgs(args) {
        // Create TokenGatedDropStage object.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage(
            0.1 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            false // if false, allow any fee recipient
        );

        uint256[] memory tokenIds = new uint256[](args.numMints);

        for (uint256 j = 0; j < args.numMints; j++) {
            tokenIds[j] = j;
        }

        // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
        address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

        vm.prank(address(token));

        // Update token gated drop for the deployed gateToken.
        raribleDrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Create an address to attempt to mint the tokens to, that doesn't
        // own the allowed NFT tokens.
        address notOwner = makeAddr("not owner");
        vm.assume(args.minter != notOwner);
        hoax(notOwner, 100 ether);

        // Expect the call to fail since the notOwner address does not own
        // the allowed NFT tokens.
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGatedNotTokenOwner.selector,
                address(token),
                gateToken,
                tokenIds[0]
            )
        );
        // Call mintAllowedTokenHolder.
        raribleDrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token),
            args.feeRecipient,
            notOwner,
            mintParams
        );
    }

    function testMintAllowedTokenHolder_revertFeeRecipientNotAllowed(
        FuzzInputsAllowedTokenHolders memory args
    ) public validateAllowedTokenHoldersArgs(args) {
        // Create TokenGatedDropStage object with restricted fee recipients.
        TokenGatedDropStage memory dropStage = TokenGatedDropStage(
            0.1 ether, // mint price
            200, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 1000), // end time
            1, // drop stage index
            1000, // max token supply for stage
            100, // fee (1%)
            true // restrict fee recipients
        );

        uint256[] memory tokenIds = new uint256[](args.numMints);

        for (uint256 j = 0; j < args.numMints; j++) {
            tokenIds[j] = j;
        }

        // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
        address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

        vm.prank(address(token));

        // Update token gated drop for the deployed gateToken.
        raribleDrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );
        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Expect the call to fail since the passed in fee recipient
        // is not allowed.
        vm.expectRevert(
            abi.encodeWithSelector(FeeRecipientNotAllowed.selector)
        );
        // Attempt to call mintAllowedTokenHolder with a fee recipient.
        hoax(args.minter, 100 ether);
        raribleDrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            mintParams
        );
    }
}
