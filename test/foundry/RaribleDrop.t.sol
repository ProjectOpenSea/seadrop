// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721PartnerRaribleDrop } from "raribleDrop/ERC721PartnerRaribleDrop.sol";

import { TestERC721 } from "raribleDrop/test/TestERC721.sol";

import {
    AllowListData,
    MintParams,
    PublicDrop,
    TokenGatedDropStage,
    TokenGatedMintParams,
    SignedMintValidationParams
} from "raribleDrop/lib/RaribleDropStructs.sol";

contract TestRaribleDrop is TestHelper {
    TestERC721 standard721Token;
    mapping(address => bool) seenAddresses;

    TokenGatedDropStage remove;
    TokenGatedDropStage add;
    TokenGatedDropStage update;
    SignedMintValidationParams addSigned;
    SignedMintValidationParams updateSigned;
    SignedMintValidationParams removeSigned;

    function setUp() public {
        // Deploy the ERC721PartnerRaribleDrop token.
        address[] memory allowedRaribleDrop = new address[](1);
        allowedRaribleDrop[0] = address(raribleDrop);
        token = new ERC721PartnerRaribleDrop("", "", address(this), allowedRaribleDrop);

        // Deploy a standard ERC721 token.
        standard721Token = new TestERC721();
        add.maxTotalMintableByWallet = 1;
        update.maxTotalMintableByWallet = 2;
        addSigned.maxMaxTotalMintableByWallet = 1;
        updateSigned.maxMaxTotalMintableByWallet = 2;
    }

    function testUpdateDropURI() public {
        string memory uri = "https://example.com/";
        vm.expectEmit(true, false, false, true, address(raribleDrop));
        emit DropURIUpdated(address(token), uri);
        vm.prank(address(token));
        raribleDrop.updateDropURI(uri);
    }

    function testUpdateDropURI_onlyERC721PartnerRaribleDrop() public {
        string memory uri = "https://example.com/";
        vm.startPrank(address(standard721Token));
        vm.expectRevert(
            abi.encodeWithSelector(
                OnlyINonFungibleRaribleDropToken.selector,
                address(standard721Token)
            )
        );
        raribleDrop.updateDropURI(uri);
    }

    function testUpdateSigners_noNullAddress() public {
        vm.startPrank(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(SignerCannotBeZeroAddress.selector)
        );
        raribleDrop.updateSignedMintValidationParams(address(0), addSigned);
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

        raribleDrop.updateSignedMintValidationParams(signer1, addSigned);
        address[] memory signers = raribleDrop.getSigners(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], signer1);
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer1)
                .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer2)
                .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer3)
                .maxMaxTotalMintableByWallet,
            0
        );

        raribleDrop.updateSignedMintValidationParams(signer2, addSigned);
        signers = raribleDrop.getSigners(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer2);
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer1)
                .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer2)
                .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer3)
                .maxMaxTotalMintableByWallet,
            0
        );

        raribleDrop.updateSignedMintValidationParams(signer3, addSigned);
        signers = raribleDrop.getSigners(address(token));
        assertEq(signers.length, 3);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer2);
        assertEq(signers[2], signer3);
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer1)
                .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer2)
                .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer3)
                .maxMaxTotalMintableByWallet,
            1
        );

        // remove signer after
        raribleDrop.updateSignedMintValidationParams(signer2, removeSigned);
        signers = raribleDrop.getSigners(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer3);
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer1)
                .maxMaxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer2)
                .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer3)
                .maxMaxTotalMintableByWallet,
            1
        );

        raribleDrop.updateSignedMintValidationParams(signer1, removeSigned);
        signers = raribleDrop.getSigners(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], signer3);
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer1)
                .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer2)
                .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer3)
                .maxMaxTotalMintableByWallet,
            1
        );

        raribleDrop.updateSignedMintValidationParams(signer3, removeSigned);
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer1)
                .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer2)
                .maxMaxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getSignedMintValidationParams(address(token), signer3)
                .maxMaxTotalMintableByWallet,
            0
        );
        signers = raribleDrop.getSigners(address(token));
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

        raribleDrop.updateAllowedFeeRecipient(recipient1, true);
        address[] memory signers = raribleDrop.getAllowedFeeRecipients(
            address(token)
        );
        assertEq(signers.length, 1);
        assertEq(signers[0], recipient1);
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );

        raribleDrop.updateAllowedFeeRecipient(recipient2, true);
        signers = raribleDrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], recipient1);
        assertEq(signers[1], recipient2);
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );

        raribleDrop.updateAllowedFeeRecipient(recipient3, true);
        signers = raribleDrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 3);
        assertEq(signers[0], recipient1);
        assertEq(signers[1], recipient2);
        assertEq(signers[2], recipient3);
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );

        // remove signer after
        raribleDrop.updateAllowedFeeRecipient(recipient2, false);
        signers = raribleDrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], recipient1);
        assertEq(signers[1], recipient3);
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );

        raribleDrop.updateAllowedFeeRecipient(recipient1, false);
        signers = raribleDrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], recipient3);
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertTrue(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );

        raribleDrop.updateAllowedFeeRecipient(recipient3, false);
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient3)
        );
        signers = raribleDrop.getAllowedFeeRecipients(address(token));
        assertEq(signers.length, 0);
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient1)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient2)
        );
        assertFalse(
            raribleDrop.getFeeRecipientIsAllowed(address(token), recipient3)
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

        raribleDrop.updateTokenGatedDrop(token1, add);
        address[] memory tokens = raribleDrop.getTokenGatedAllowedTokens(
            address(token)
        );
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token1);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token1)
                .maxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token3)
                .maxTotalMintableByWallet,
            0
        );

        raribleDrop.updateTokenGatedDrop(token2, add);
        tokens = raribleDrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token1)
                .maxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token3)
                .maxTotalMintableByWallet,
            0
        );

        raribleDrop.updateTokenGatedDrop(token3, add);
        tokens = raribleDrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 3);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token2);
        assertEq(tokens[2], token3);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token1)
                .maxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token3)
                .maxTotalMintableByWallet,
            1
        );

        // test update
        raribleDrop.updateTokenGatedDrop(token2, update);
        tokens = raribleDrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 3);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            2
        );
        // remove signer after
        raribleDrop.updateTokenGatedDrop(token2, remove);
        tokens = raribleDrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 2);
        assertEq(tokens[0], token1);
        assertEq(tokens[1], token3);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token1)
                .maxTotalMintableByWallet,
            1
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token3)
                .maxTotalMintableByWallet,
            1
        );

        raribleDrop.updateTokenGatedDrop(token1, remove);
        tokens = raribleDrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 1);
        assertEq(tokens[0], token3);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token1)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token3)
                .maxTotalMintableByWallet,
            1
        );

        raribleDrop.updateTokenGatedDrop(token3, remove);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token3)
                .maxTotalMintableByWallet,
            0
        );
        tokens = raribleDrop.getTokenGatedAllowedTokens(address(token));
        assertEq(tokens.length, 0);
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token1)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token2)
                .maxTotalMintableByWallet,
            0
        );
        assertEq(
            raribleDrop
                .getTokenGatedDrop(address(token), token3)
                .maxTotalMintableByWallet,
            0
        );
    }
}
