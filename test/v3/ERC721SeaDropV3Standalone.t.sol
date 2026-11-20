// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";
import {
    ERC721SeaDropV3Standalone
} from "seadrop/v3/ERC721SeaDropV3Standalone.sol";
import { SeaDropTokenV3Base } from "seadrop/v3/SeaDropTokenV3Base.sol";
import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

contract ERC721SeaDropV3StandaloneTest is SeaDropV3TestHelper {
    function test_deployAndMint() public {
        ERC721SeaDropV3Standalone token = new ERC721SeaDropV3Standalone(
            alice, address(minter), "Collection", "COL", CONDUIT
        );
        assertEq(token.owner(), alice);
        assertEq(token.name(), "Collection");
        assertEq(token.symbol(), "COL");
        assertEq(token.factory(), address(this));
        assertTrue(token.allowedMinters(address(minter)));
        assertTrue(token.isApprovedForAll(bob, CONDUIT));
        vm.startPrank(alice);
        token.setMaxSupply(2);
        minter.ownerMint(address(token), 0, bob, 2);
        vm.stopPrank();
        assertEq(token.ownerOf(1), bob);
        assertEq(token.ownerOf(2), bob);
        vm.expectRevert(
            bytes("ERC721A__Initializable: contract is already initialized")
        );
        token.initialize(bob, bob, "", "");
    }

    function test_deployRejectsZeroOwnerOrMinter() public {
        vm.expectRevert(TwoStepOwnable.NewOwnerIsZeroAddress.selector);
        new ERC721SeaDropV3Standalone(
            address(0), address(minter), "", "", CONDUIT
        );
        vm.expectRevert(SeaDropTokenV3Base.MinterIsZeroAddress.selector);
        new ERC721SeaDropV3Standalone(alice, address(0), "", "", CONDUIT);
    }
}
