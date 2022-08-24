// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { TestERC721 } from "test/foundry/utils/TestERC721.sol";
import {
    AllowListData,
    MintParams,
    PublicDrop,
    TokenGatedDropStage,
    TokenGatedMintParams
} from "seadrop/lib/SeaDropStructs.sol";

contract TestSeaDrop is TestHelper {
    TestERC721 badToken;
    mapping(address => bool) seenAddresses;

    struct FuzzSelector {
        address targetAddress;
        bytes4[] targetSelectors;
    }

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);

        // Deploy a vanilla ERC721 token.
        badToken = new TestERC721();
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
        vm.startPrank(address(badToken));
        vm.expectRevert(
            abi.encodeWithSelector(
                OnlyIERC721SeaDrop.selector,
                address(badToken)
            )
        );
        seadrop.updateDropURI(uri);
    }

    function testUpdateSigners_noNullAddress() public {
        vm.startPrank(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(SignerCannotBeZeroAddress.selector)
        );
        seadrop.updateSigner(address(0), true);
    }

    function testUpdateSigner(
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

        seadrop.updateSigner(signer1, true);
        address[] memory signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], signer1);
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer1));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer2));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer3));

        seadrop.updateSigner(signer2, true);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer2);
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer1));
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer2));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer3));

        seadrop.updateSigner(signer3, true);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 3);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer2);
        assertEq(signers[2], signer3);
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer1));
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer2));
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer3));

        // remove signer after
        seadrop.updateSigner(signer2, false);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 2);
        assertEq(signers[0], signer1);
        assertEq(signers[1], signer3);
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer2));
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer1));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer2));
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer3));

        seadrop.updateSigner(signer1, false);
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 1);
        assertEq(signers[0], signer3);
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer1));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer2));
        assertTrue(seadrop.getSignerIsAllowed(address(token), signer3));

        seadrop.updateSigner(signer3, false);
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer2));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer3));
        signers = seadrop.getSigners(address(token));
        assertEq(signers.length, 0);
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer1));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer2));
        assertFalse(seadrop.getSignerIsAllowed(address(token), signer3));
    }

    function invariant_NoDuplicatesInEnumeratedSigners() public {
        address[] memory signers = seadrop.getSigners(address(token));
        for (uint256 i; i < signers.length; ++i) {
            assertTrue(seenAddresses[signers[i]]);
            seenAddresses[signers[i]] = true;
        }
    }

    function invariantNoDuplicatesInEnumeratedTokens() public {
        address[] memory tokens = seadrop.getTokenGatedAllowedTokens(
            address(token)
        );
        for (uint256 i; i < tokens.length; ++i) {
            assertFalse(seenAddresses[tokens[i]]);
            seenAddresses[tokens[i]] = true;

            TokenGatedDropStage memory drop = seadrop.getTokenGatedDrop(
                address(token),
                tokens[i]
            );
            assertGt(drop.maxTotalMintableByWallet, 0);
        }
    }

    // function targetContracts() public view returns (address[] memory) {
    //     address[] memory targets = new address[](1);
    //     targets[0] = address(seadrop);
    //     // targets[1] = address(token);
    //     return targets;
    // }

    function targetSelectors() public view returns (FuzzSelector[] memory) {
        FuzzSelector[] memory fuzzSelectors = new FuzzSelector[](0);
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = seadrop.updateSigner.selector;
        selectors[1] = seadrop.updateTokenGatedDrop.selector;

        fuzzSelectors[0] = FuzzSelector(address(seadrop), selectors);
        return fuzzSelectors;
    }

    function targetSenders() public view returns (address[] memory) {
        address[] memory senders = new address[](1);
        senders[0] = address(token);
        return senders;
    }
}
