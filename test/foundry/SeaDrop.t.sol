// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
        badToken = new TestERC721();
    }

    function testUpdateDropURI() public {
        string memory uri = "https://example.com/";
        vm.expectEmit(true, false, false, true, address(test));
        emit DropURIUpdated(address(token), uri);
        vm.prank(address(token));
        test.updateDropURI(uri);
        assertEq(test.getDropURI(address(token)), uri);
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
        test.updateDropURI(uri);
    }

    function testUpdateSigners_noNullAdress(address[10] memory signers) public {
        address[] memory newSigners = new address[](10);
        for (uint256 i = 0; i < 10; i++) {
            newSigners[i] = signers[i];
        }
        newSigners[9] = address(0);
        vm.startPrank(address(token));
        vm.expectRevert(
            abi.encodeWithSelector(SignerCannotBeZeroAddress.selector)
        );
        test.updateSigners(newSigners);
    }
}
