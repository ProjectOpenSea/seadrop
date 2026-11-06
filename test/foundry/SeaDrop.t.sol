// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { TestERC721 } from "seadrop/test/TestERC721.sol";

import { MaliciousRecipient } from "seadrop/test/MaliciousRecipient.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

import {
    AllowListData,
    MintParams,
    PublicDrop,
    TokenGatedDropStage,
    TokenGatedMintParams,
    SignedMintValidationParams
} from "seadrop/lib/SeaDropStructs.sol";

contract TestSeaDrop is TestHelper {
    TestERC721 standard721Token;
    mapping(address => bool) seenAddresses;

    TokenGatedDropStage remove;
    TokenGatedDropStage add;
    TokenGatedDropStage update;
    SignedMintValidationParams addSigned;
    SignedMintValidationParams updateSigned;
    SignedMintValidationParams removeSigned;

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = _newToken("", "", allowedSeaDrop);

        // Deploy a standard ERC721 token.
        standard721Token = new TestERC721();
        add.maxTotalMintableByWallet = 1;
        update.maxTotalMintableByWallet = 2;
        addSigned.maxMaxTotalMintableByWallet = 1;
        updateSigned.maxMaxTotalMintableByWallet = 2;
    }

    function testUpdateDropURI() public {
        string memory uri = "https://example.com/";
        vm.expectEmit(true, false, false, true, address(seadrop));
        emit DropURIUpdated(address(token), uri);
        vm.prank(address(token));
        seadrop.updateDropURI(uri);
    }

    function testUpdateDropURI_onlyERC721SeaDrop() public {
        string memory uri = "https://example.com/";
        vm.startPrank(address(standard721Token));
        vm.expectRevert(
            abi.encodeWithSelector(
                OnlyINonFungibleSeaDropToken.selector, address(standard721Token)
            )
        );
        seadrop.updateDropURI(uri);
    }

    function testUpdateSigners_noNullAddress() public {
        vm.startPrank(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(SignerCannotBeZeroAddress.selector)
        );
        seadrop.updateSignedMintValidationParams(address(0), addSigned);
    }

    function testupdateSignedMintValidationParams(
        address signer1,
        address signer2,
        address signer3
    ) public {
        vm.assume(signer1 != address(0));
        vm.assume(signer2 != address(0));
        vm.assume(signer3 != address(0));
        vm.assume(signer1 != signer2);
        vm.assume(signer1 != signer3);
        vm.assume(signer2 != signer3);

        vm.startPrank(address(token));

        seadrop.updateSignedMintValidationParams(signer1, addSigned);
        address[] memory signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], signer1);
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer1)
            .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer2)
            .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer3)
            .maxMaxTotalMintableByWallet,
            0
        );

        seadrop.updateSignedMintValidationParams(signer2, addSigned);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer2);
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer1)
            .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer2)
            .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer3)
            .maxMaxTotalMintableByWallet,
            0
        );

        seadrop.updateSignedMintValidationParams(signer3, addSigned);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 3);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer2);
        assertEq(signers[2], signer3);
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer1)
            .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer2)
            .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer3)
            .maxMaxTotalMintableByWallet,
            1
        );

        // remove signer after
        seadrop.updateSignedMintValidationParams(signer2, removeSigned);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer3);
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer1)
            .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer2)
            .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer3)
            .maxMaxTotalMintableByWallet,
            1
        );

        seadrop.updateSignedMintValidationParams(signer1, removeSigned);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], signer3);
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer1)
            .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer2)
            .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer3)
            .maxMaxTotalMintableByWallet,
            1
        );

        seadrop.updateSignedMintValidationParams(signer3, removeSigned);
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer1)
            .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer2)
            .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getSignedMintValidationParams(address(token), signer3)
            .maxMaxTotalMintableByWallet,
            0
        );
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 0);
    }

    function testUpdateAllowedFeeRecipient(
        address recipient1,
        address recipient2,
        address recipient3
    ) public {
        vm.assume(recipient1 != address(0));
        vm.assume(recipient2 != address(0));
        vm.assume(recipient3 != address(0));
        vm.assume(recipient1 != recipient2);
        vm.assume(recipient1 != recipient3);
        vm.assume(recipient2 != recipient3);

        vm.startPrank(address(token));

        seadrop.updateAllowedFeeRecipient(recipient1, true);
        address[] memory signers =
            seadrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], recipient1);
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient1));
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );

        seadrop.updateAllowedFeeRecipient(recipient2, true);
        signers = seadrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], recipient1);
        assertEq(signers[1], recipient2);
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient1));
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient2));
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );

        seadrop.updateAllowedFeeRecipient(recipient3, true);
        signers = seadrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 3);
        assertEq(signers[0], recipient1);
        assertEq(signers[1], recipient2);
        assertEq(signers[2], recipient3);
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient1));
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient2));
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient3));

        // remove signer after
        seadrop.updateAllowedFeeRecipient(recipient2, false);
        signers = seadrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], recipient1);
        assertEq(signers[1], recipient3);
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient1));
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient3));

        seadrop.updateAllowedFeeRecipient(recipient1, false);
        signers = seadrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], recipient3);
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertTrue(seadrop.getFeeRecipientIsAllowed(address(token), recipient3));

        seadrop.updateAllowedFeeRecipient(recipient3, false);
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );
        signers = seadrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 0);
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertFalse(
            seadrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );
    }

    function testUpdateTokenGatedDrop(
        address token1,
        address token2,
        address token3
    ) public {
        vm.assume(token1 != address(0));
        vm.assume(token2 != address(0));
        vm.assume(token3 != address(0));
        vm.assume(address(token) != token1);
        vm.assume(address(token) != token2);
        vm.assume(address(token) != token3);
        vm.assume(token1 != token2);
        vm.assume(token1 != token3);
        vm.assume(token2 != token3);

        vm.startPrank(address(token));

        seadrop.updateTokenGatedDrop(token1, add);
        address[] memory tokens =
            seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token1);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token1)
            .maxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token3)
            .maxTotalMintableByWallet,
            0
        );

        seadrop.updateTokenGatedDrop(token2, add);
        tokens = seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token1)
            .maxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token3)
            .maxTotalMintableByWallet,
            0
        );

        seadrop.updateTokenGatedDrop(token3, add);
        tokens = seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 3);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(tokens[2], token3);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token1)
            .maxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token3)
            .maxTotalMintableByWallet,
            1
        );

        // test update
        seadrop.updateTokenGatedDrop(token2, update);
        tokens = seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 3);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            2
        );
        // remove signer after
        seadrop.updateTokenGatedDrop(token2, remove);
        tokens = seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token3);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token1)
            .maxTotalMintableByWallet,
            1
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token3)
            .maxTotalMintableByWallet,
            1
        );

        seadrop.updateTokenGatedDrop(token1, remove);
        tokens = seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token3);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token1)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token3)
            .maxTotalMintableByWallet,
            1
        );

        seadrop.updateTokenGatedDrop(token3, remove);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token3)
            .maxTotalMintableByWallet,
            0
        );
        tokens = seadrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 0);
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token1)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token2)
            .maxTotalMintableByWallet,
            0
        );
        assertEq(
            seadrop.getTokenGatedDrop(address(token), token3)
            .maxTotalMintableByWallet,
            0
        );
    }

    function testTokenMethods_onlyINonFungibleSeaDropToken() public {
        // A standard ERC721A token that does not implement
        // INonFungibleSeaDropToken.
        ERC721A standardERC721A = new ERC721A("", "");
        address minter = makeAddr("minter");

        bytes memory expectedRevert = abi.encodeWithSelector(
            OnlyINonFungibleSeaDropToken.selector, address(standardERC721A)
        );

        vm.startPrank(address(standardERC721A));

        PublicDrop memory publicDrop = PublicDrop(
            1000, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 100), // end time
            1, // max mints per wallet
            1000, // fee (10%)
            false // restrict fee recipients
        );
        vm.expectRevert(expectedRevert);
        seadrop.updatePublicDrop(publicDrop);

        AllowListData memory allowListData =
            AllowListData(bytes32(0), new string[](0), "");
        vm.expectRevert(expectedRevert);
        seadrop.updateAllowList(allowListData);

        TokenGatedDropStage memory tokenGatedDropStage = TokenGatedDropStage(
            0.01 ether, // mint price
            10, // max mints per wallet
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 500), // end time
            1, // drop stage index
            100, // max token supply for stage
            100, // fee (1%)
            true // restrict fee recipients
        );
        vm.expectRevert(expectedRevert);
        seadrop.updateTokenGatedDrop(minter, tokenGatedDropStage);

        vm.expectRevert(expectedRevert);
        seadrop.updateCreatorPayoutAddress(minter);

        vm.expectRevert(expectedRevert);
        seadrop.updateAllowedFeeRecipient(minter, true);

        SignedMintValidationParams memory signedMintValidationParams =
            SignedMintValidationParams(
                1, // min mint price
                11, // max max total mintable by wallet
                50, // min start time
                100000000000, // max end time
                10000, // max max token supply for stage
                1, // min fee bps
                9000 // max fee bps
            );
        vm.expectRevert(expectedRevert);
        seadrop.updateSignedMintValidationParams(
            minter, signedMintValidationParams
        );

        vm.expectRevert(expectedRevert);
        seadrop.updateDropURI("http://test.com");

        vm.expectRevert(expectedRevert);
        seadrop.updatePayer(minter, true);

        vm.stopPrank();

        // An INonFungibleSeaDropToken can use the token methods.
        vm.expectEmit(true, true, true, true, address(seadrop));
        emit DropURIUpdated(address(token), "http://test.com");
        token.updateDropURI(address(seadrop), "http://test.com");
    }

    function testMintPublic_reentrancyThroughCreatorPayout() public {
        token.setMaxSupply(10);

        // Allow two mints per wallet so the nested mint passes the quantity
        // checks and reaches the reentrancy guard, and charge no fee so the
        // first ETH transfer (and the reentry) is the creator payout.
        PublicDrop memory publicDrop = PublicDrop(
            1 ether, // mint price
            uint48(block.timestamp), // start time
            uint48(block.timestamp + 100), // end time
            2, // max mints per wallet
            0, // fee
            false // restrict fee recipients
        );
        vm.prank(address(token));
        seadrop.updatePublicDrop(publicDrop);

        MaliciousRecipient maliciousRecipient = new MaliciousRecipient();

        // Set the creator payout address to the MaliciousRecipient.
        token.updateCreatorPayoutAddress(
            address(seadrop), address(maliciousRecipient)
        );

        // Should not be able to mint with reentrancy.
        maliciousRecipient.setStartAttack{ value: 10 ether }();
        vm.expectRevert("ETH_TRANSFER_FAILED");
        maliciousRecipient.attack(seadrop, address(token));
        assertEq(token.totalSupply(), 0);
    }
}
