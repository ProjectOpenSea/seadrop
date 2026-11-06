// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { TestERC721 } from "seadrop/test/TestERC721.sol";

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

    modifier validateAllowedTokenHoldersArgs(FuzzInputsAllowedTokenHolders memory args) {
        vm.assume(args.numMints > 0 && args.numMints < 20);
        vm.assume(args.minter != address(0) && args.feeRecipient != address(0));
        vm.assume(
            args.feeRecipient.code.length == 0 && args.feeRecipient > address(9)
        );
        vm.assume(args.minter.code.length == 0 && args.minter > address(9));
        vm.assume(
            args.minter != args.feeRecipient && args.minter != creator
                && args.feeRecipient != creator
        );
        _;
    }

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", allowedSeaDrop);

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

    function testMintAllowedTokenHolder(FuzzInputsAllowedTokenHolders memory args)
        public
        validateAllowedTokenHoldersArgs(args)
    {
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
        seadrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams =
            TokenGatedMintParams(gateToken, tokenIds);

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Prank the mint call as the minter.
        hoax(args.minter, 100 ether);

        // Call mintAllowedTokenHolder as the minter.
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), args.feeRecipient, args.minter, mintParams
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintAllowedTokenHolder_differentPayerThanMinter(FuzzInputsAllowedTokenHolders memory args)
        public
        validateAllowedTokenHoldersArgs(args)
    {
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
        seadrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams =
            TokenGatedMintParams(gateToken, tokenIds);

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Derive an address to call the transaction with.
        address payer = makeAddr("payer");

        // Allow the payer.
        token.updatePayer(address(seadrop), payer, true);

        hoax(payer, 100 ether);

        // Call mintAllowedTokenHolder as the payer.
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), args.feeRecipient, args.minter, mintParams
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintAllowedTokenHolder_revertAlreadyRedeemed(FuzzInputsAllowedTokenHolders memory args)
        public
        validateAllowedTokenHoldersArgs(args)
    {
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
        TokenGatedMintParams memory mintParams =
            TokenGatedMintParams(gateToken, tokenIds);

        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Call mintAllowedTokenHolder.
        hoax(args.minter, 100 ether);
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), args.feeRecipient, args.minter, mintParams
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
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), args.feeRecipient, args.minter, mintParams
        );
    }

    function testMintAllowedTokenHolder_freeMint(FuzzInputsAllowedTokenHolders memory args)
        public
        validateAllowedTokenHoldersArgs(args)
    {
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
        seadrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams =
            TokenGatedMintParams(gateToken, tokenIds);

        // Call mintAllowedTokenHolder.
        hoax(args.minter, 100 ether);
        seadrop.mintAllowedTokenHolder(
            address(token), args.feeRecipient, args.minter, mintParams
        );

        // Check minter token balance increased.
        assertEq(token.balanceOf(args.minter), args.numMints);
    }

    function testMintAllowedTokenHolder_revertNotOwner(FuzzInputsAllowedTokenHolders memory args)
        public
        validateAllowedTokenHoldersArgs(args)
    {
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
        seadrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams =
            TokenGatedMintParams(gateToken, tokenIds);

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
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), args.feeRecipient, notOwner, mintParams
        );
    }

    function testMintAllowedTokenHolder_revertFeeRecipientNotAllowed(FuzzInputsAllowedTokenHolders memory args)
        public
        validateAllowedTokenHoldersArgs(args)
    {
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
        seadrop.updateTokenGatedDrop(gateToken, dropStage);

        // Keep track of the mint params.
        TokenGatedMintParams memory mintParams =
            TokenGatedMintParams(gateToken, tokenIds);
        // Calculate the value to send with the transaction.
        uint256 mintValue = args.numMints * dropStage.mintPrice;

        // Expect the call to fail since the passed in fee recipient
        // is not allowed.
        vm.expectRevert(abi.encodeWithSelector(FeeRecipientNotAllowed.selector));
        // Attempt to call mintAllowedTokenHolder with a fee recipient.
        hoax(args.minter, 100 ether);
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), args.feeRecipient, args.minter, mintParams
        );
    }
}

/// @dev Token gated mint scenarios against a fully configured token: max
///      supply 100, creator payout set, one allowed fee recipient, and a
///      token gated drop stage for `allowedNftToken` that restricts fee
///      recipients.
contract SeaDropMintAllowedTokenHolderScenarioTest is TestHelper {
    TestERC721 allowedNftToken;

    address minter = makeAddr("minter");
    address feeRecipient = makeAddr("feeRecipient");

    TokenGatedDropStage dropStage;

    function setUp() public {
        // Use a realistic timestamp so stage start times in the past are
        // representable.
        vm.warp(1_700_000_000);

        vm.deal(minter, 10_000 ether);

        // Deploy the token. The test contract is the owner.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", allowedSeaDrop);

        // Deploy the allowed NFT token.
        allowedNftToken = new TestERC721();

        // Configure the token.
        token.setMaxSupply(100);
        token.updateCreatorPayoutAddress(address(seadrop), creator);
        token.updateAllowedFeeRecipient(address(seadrop), feeRecipient, true);

        // Create the drop stage object.
        dropStage = TokenGatedDropStage(
            0.01 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp - 100), // start time
            uint48(block.timestamp + 500), // end time
            1, // drop stage index
            100, // max token supply for stage
            100, // fee (1%)
            true // restrict fee recipients
        );

        // Update the token gated drop for the deployed allowed NFT token.
        token.updateTokenGatedDrop(
            address(seadrop), address(allowedNftToken), dropStage
        );
    }

    /// @dev Mint params for `allowedNftToken` token ids 0..count-1, minting
    ///      each of those ids to the minter.
    function _mintParamsForMinter(uint256 count)
        internal
        returns (TokenGatedMintParams memory mintParams)
    {
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = i;
            allowedNftToken.mint(minter, i);
        }
        mintParams = TokenGatedMintParams(address(allowedNftToken), tokenIds);
    }

    function _expectSeaDropMint(address payer, uint256 mintPrice) internal {
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit SeaDropMint(
            address(token),
            minter,
            feeRecipient,
            payer,
            1, // mint quantity
            mintPrice,
            dropStage.feeBps,
            dropStage.dropStageIndex
        );
    }

    function testMintAllowedTokenHolder_redeemsAndEmitsSeaDropMint() public {
        TokenGatedMintParams memory mintParams = _mintParamsForMinter(1);

        // Ensure the token id is not already redeemed.
        assertFalse(
            seadrop.getAllowedNftTokenIdIsRedeemed(
                address(token),
                mintParams.allowedNftToken,
                mintParams.allowedNftTokenIds[0]
            )
        );

        // Mint the token to the minter and verify the expected event was
        // emitted.
        _expectSeaDropMint(minter, dropStage.mintPrice);
        vm.prank(minter);
        seadrop.mintAllowedTokenHolder{ value: dropStage.mintPrice }(
            address(token), feeRecipient, minter, mintParams
        );

        // Ensure the token id was redeemed.
        assertTrue(
            seadrop.getAllowedNftTokenIdIsRedeemed(
                address(token),
                mintParams.allowedNftToken,
                mintParams.allowedNftTokenIds[0]
            )
        );

        address[] memory allowedTokens =
            seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(allowedTokens.length, 1);
        assertEq(allowedTokens[0], address(allowedNftToken));
    }

    function testMintAllowedTokenHolder_payerMustBeAllowed() public {
        TokenGatedMintParams memory mintParams = _mintParamsForMinter(1);

        // The payer (the owner, this contract) must be allowed first.
        vm.expectRevert(PayerNotAllowed.selector);
        seadrop.mintAllowedTokenHolder{ value: dropStage.mintPrice }(
            address(token), feeRecipient, minter, mintParams
        );

        // Allow the payer.
        token.updatePayer(address(seadrop), address(this), true);

        _expectSeaDropMint(address(this), dropStage.mintPrice);
        seadrop.mintAllowedTokenHolder{ value: dropStage.mintPrice }(
            address(token), feeRecipient, minter, mintParams
        );

        assertEq(token.balanceOf(minter), 1);
    }

    function testMintAllowedTokenHolder_freeMintEmitsSeaDropMint() public {
        // Update the token gated drop with a free mint drop stage.
        TokenGatedDropStage memory dropStageFreeMint = dropStage;
        dropStageFreeMint.mintPrice = 0;
        token.updateTokenGatedDrop(
            address(seadrop), address(allowedNftToken), dropStageFreeMint
        );

        TokenGatedMintParams memory mintParams = _mintParamsForMinter(1);

        _expectSeaDropMint(minter, 0);
        vm.prank(minter);
        seadrop.mintAllowedTokenHolder(
            address(token), feeRecipient, minter, mintParams
        );

        assertEq(token.balanceOf(minter), 1);
    }

    function testMintAllowedTokenHolder_revertAlreadyRedeemedAfterMint()
        public
    {
        TokenGatedMintParams memory mintParams = _mintParamsForMinter(1);

        _expectSeaDropMint(minter, dropStage.mintPrice);
        vm.prank(minter);
        seadrop.mintAllowedTokenHolder{ value: dropStage.mintPrice }(
            address(token), feeRecipient, minter, mintParams
        );

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenGatedTokenIdAlreadyRedeemed.selector,
                address(token),
                address(allowedNftToken),
                0
            )
        );
        seadrop.mintAllowedTokenHolder{ value: dropStage.mintPrice }(
            address(token), feeRecipient, minter, mintParams
        );
    }

    function testMintAllowedTokenHolder_revertStageNotActive() public {
        // Update the token gated drop with an expired drop stage.
        TokenGatedDropStage memory dropStageExpired = dropStage;
        dropStageExpired.endTime = uint48(block.timestamp - 500);
        token.updateTokenGatedDrop(
            address(seadrop), address(allowedNftToken), dropStageExpired
        );

        TokenGatedMintParams memory mintParams = _mintParamsForMinter(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                NotActive.selector,
                block.timestamp,
                dropStage.startTime,
                dropStageExpired.endTime
            )
        );
        seadrop.mintAllowedTokenHolder(
            address(token), feeRecipient, address(0), mintParams
        );
    }

    function testMintAllowedTokenHolder_revertDifferentTokenContract() public {
        TokenGatedMintParams memory mintParams = _mintParamsForMinter(1);

        // Deploy and configure a new ERC721SeaDrop.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        ERC721SeaDrop differentToken = new ERC721SeaDrop("", "", allowedSeaDrop);
        differentToken.setMaxSupply(1000);
        differentToken.updateAllowedFeeRecipient(
            address(seadrop), feeRecipient, true
        );
        differentToken.updateCreatorPayoutAddress(address(seadrop), creator);

        // The drop stage for a different token does not exist, so its start
        // and end times are 0.
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(NotActive.selector, block.timestamp, 0, 0)
        );
        seadrop.mintAllowedTokenHolder{ value: dropStage.mintPrice }(
            address(differentToken), feeRecipient, minter, mintParams
        );
    }

    function testMintAllowedTokenHolder_revertDifferentAllowedNftToken()
        public
    {
        // Deploy a different allowed NFT token.
        TestERC721 differentAllowedNftToken = new TestERC721();

        // Mint an allowedNftToken to the minter, but pass the different
        // allowed NFT token in the mint params.
        _mintParamsForMinter(1);
        uint256[] memory tokenIds = new uint256[](1);
        TokenGatedMintParams memory mintParams =
            TokenGatedMintParams(address(differentAllowedNftToken), tokenIds);

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(NotActive.selector, block.timestamp, 0, 0)
        );
        seadrop.mintAllowedTokenHolder{ value: dropStage.mintPrice }(
            address(token), feeRecipient, minter, mintParams
        );
    }

    function testMintAllowedTokenHolder_revertExceedsMaxMintsPerWallet()
        public
    {
        // Token ids exceeding maxTotalMintableByWallet.
        TokenGatedMintParams memory mintParams = _mintParamsForMinter(20);

        uint256 mintValue = uint256(dropStage.mintPrice) * 20;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxMintedPerWallet.selector,
                20,
                dropStage.maxTotalMintableByWallet
            )
        );
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), feeRecipient, minter, mintParams
        );
    }

    function testMintAllowedTokenHolder_revertExceedsMaxTokenSupplyForStage()
        public
    {
        TokenGatedDropStage memory newDropStage = dropStage;
        newDropStage.maxTotalMintableByWallet = 20;
        newDropStage.maxTokenSupplyForStage = 5;
        token.updateTokenGatedDrop(
            address(seadrop), address(allowedNftToken), newDropStage
        );

        TokenGatedMintParams memory mintParams = _mintParamsForMinter(20);

        uint256 mintValue = uint256(dropStage.mintPrice) * 20;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxTokenSupplyForStage.selector, 20, 5
            )
        );
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), feeRecipient, address(0), mintParams
        );
    }

    function testMintAllowedTokenHolder_revertExceedsMaxSupply() public {
        TokenGatedDropStage memory newDropStage = dropStage;
        newDropStage.maxTotalMintableByWallet = 110;
        newDropStage.maxTokenSupplyForStage = 110;
        token.updateTokenGatedDrop(
            address(seadrop), address(allowedNftToken), newDropStage
        );

        TokenGatedMintParams memory mintParams = _mintParamsForMinter(110);

        uint256 mintValue = uint256(dropStage.mintPrice) * 110;

        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                MintQuantityExceedsMaxSupply.selector, 110, 100
            )
        );
        seadrop.mintAllowedTokenHolder{ value: mintValue }(
            address(token), feeRecipient, minter, mintParams
        );
    }

    function testUpdateTokenGatedDrop_revertDropTokenOrZeroAddress() public {
        vm.expectRevert(TokenGatedDropAllowedNftTokenCannotBeDropToken.selector);
        token.updateTokenGatedDrop(address(seadrop), address(token), dropStage);

        vm.expectRevert(
            TokenGatedDropAllowedNftTokenCannotBeZeroAddress.selector
        );
        token.updateTokenGatedDrop(address(seadrop), address(0), dropStage);
    }

    function testUpdateTokenGatedDrop_revertInvalidFeeBps() public {
        TokenGatedDropStage memory invalidDropStage = dropStage;
        invalidDropStage.feeBps = 15_000;

        vm.expectRevert(abi.encodeWithSelector(InvalidFeeBps.selector, 15_000));
        token.updateTokenGatedDrop(
            address(seadrop), address(allowedNftToken), invalidDropStage
        );
    }

    function testUpdateTokenGatedDrop_revertStageNotPresent() public {
        // A non-mintable drop stage, which signals removal.
        TokenGatedDropStage memory zeroMintDropStage = dropStage;
        zeroMintDropStage.maxTotalMintableByWallet = 0;
        zeroMintDropStage.maxTokenSupplyForStage = 5;

        address token2 =
            address(uint160(0x2222222222222222222222222222222222222222));

        // Expect the call to revert since there is no existing drop stage.
        vm.prank(address(token));
        vm.expectRevert(TokenGatedDropStageNotPresent.selector);
        seadrop.updateTokenGatedDrop(token2, zeroMintDropStage);
    }

    function testUpdateTokenGatedDrop_clearsEnumerationWhenDeleted() public {
        TokenGatedDropStage memory deleteDropStage = dropStage;
        deleteDropStage.maxTotalMintableByWallet = 0;
        token.updateTokenGatedDrop(
            address(seadrop), address(allowedNftToken), deleteDropStage
        );

        assertEq(seadrop.getTokenGatedAllowedTokens(address(token)).length, 0);

        TokenGatedDropStage memory stored = seadrop.getTokenGatedDrop(
            address(token), address(allowedNftToken)
        );
        assertEq(stored.mintPrice, 0);
        assertEq(stored.maxTotalMintableByWallet, 0);
        assertEq(stored.startTime, 0);
        assertEq(stored.endTime, 0);
        assertEq(stored.dropStageIndex, 0);
        assertEq(stored.maxTokenSupplyForStage, 0);
        assertEq(stored.feeBps, 0);
        assertFalse(stored.restrictFeeRecipients);
    }
}
