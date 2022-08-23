// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

<<<<<<< HEAD
import "forge-std/Test.sol";
import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";
import { SeaDrop } from "seadrop/SeaDrop.sol";
import { TestERC721 } from "test/foundry/utils/TestERC721.sol";
import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

contract TestSeaDrop is Test, SeaDropErrorsAndEvents {
    SeaDrop test;
    ERC721SeaDrop token;
    TestERC721 badToken;

    function setUp() public {
        test = new SeaDrop();
        address[] memory seadrop = new address[](1);
        seadrop[0] = address(test);
        token = new ERC721SeaDrop("", "", address(this), seadrop);
=======
import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { TestERC721 } from "test/foundry/utils/TestERC721.sol";

contract TestSeaDrop is TestHelper {
    TestERC721 badToken;

    function setUp() public {
        // Deploy the ERC721SeaDrop token.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = new ERC721SeaDrop("", "", address(this), allowedSeaDrop);

        // Deploy a vanilla ERC721 token.
>>>>>>> main
        badToken = new TestERC721();
    }

    function testUpdateDropURI() public {
        string memory uri = "https://example.com/";
<<<<<<< HEAD
        vm.expectEmit(true, false, false, true, address(test));
        emit DropURIUpdated(address(token), uri);
        vm.prank(address(token));
        test.updateDropURI(uri);
        assertEq(test.getDropURI(address(token)), uri);
=======
        vm.expectEmit(true, false, false, true, address(seadrop));
        emit DropURIUpdated(address(token), uri);
        vm.prank(address(token));
        seadrop.updateDropURI(uri);
        assertEq(seadrop.getDropURI(address(token)), uri);
>>>>>>> main
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
<<<<<<< HEAD
        test.updateDropURI(uri);
=======
        seadrop.updateDropURI(uri);
    }

    function testUpdateSigners_noNullAddress(address[10] memory signers)
        public
    {
        address[] memory newSigners = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            newSigners[i] = signers[i];
        }
        newSigners[9] = address(0);
        vm.startPrank(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(SignerCannotBeZeroAddress.selector)
        );
        seadrop.updateSigners(newSigners);
>>>>>>> main
    }
}
