// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

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
        badToken = new TestERC721();
    }

    function testUpdateDropURI() public {
        string memory uri = "https://example.com/";
        vm.expectEmit(true, false, false, true, address(seadrop));
        emit DropURIUpdated(address(token), uri);
        vm.prank(address(token));
        seadrop.updateDropURI(uri);
        assertEq(seadrop.getDropURI(address(token)), uri);
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
}
