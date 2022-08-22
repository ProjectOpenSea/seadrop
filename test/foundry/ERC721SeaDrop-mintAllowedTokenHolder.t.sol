// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { TestERC721 } from "test/foundry/utils/TestERC721.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    TokenGatedMintParams,
    TokenGatedDropStage
} from "seadrop/lib/SeaDropStructs.sol";

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
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);

        // Set the max supply to 1000.
        token.setMaxSupply(1000);

        // Set the creator payout address.
        token.updateCreatorPayoutAddress(address(seadrop), creator);
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

        // Iterate over the fuzzed number of gate tokens.
        uint256[] memory tokenIds = new uint256[](args.numMints);

        for (uint256 j = 0; j < args.numMints; j++) {
            tokenIds[j] = j;
        }

        // Deploy a gateToken, mint tokenIds to the minter and store the token's address.
        address gateToken = _deployAndMintGateToken(args.minter, tokenIds);

        vm.prank(address(token));
        // Update token gated drop for the deployed gateToken.
        seadrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Call mintAllowedTokenHolder.
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
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
        seadrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams = TokenGatedMintParams(
            gateToken,
            tokenIds
        );

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Call mintAllowedTokenHolder.
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
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
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token),
            args.feeRecipient,
            args.minter,
            mintParams
        );
    }

    // testMintAllowedTokenHolder_notOwner
    // testMintAllowedTokenHolder_differentPayerThanMinter
    // testMintAllowedTokenHolder_freeMint
    // testMintAllowedTokenHolder_revertFeeRecipientNotAllowed
}
