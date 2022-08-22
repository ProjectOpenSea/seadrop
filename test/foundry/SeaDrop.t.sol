// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";
import { SeaDrop } from "seadrop/SeaDrop.sol";
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

contract TestERC721 is ERC721("", "") {
    function tokenURI(uint256)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return "";
    }
}

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
}
