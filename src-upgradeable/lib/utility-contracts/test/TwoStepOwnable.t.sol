// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {TwoStepOwnable} from "../src/TwoStepOwnable.sol";

contract TwoStepOwnableTest is TwoStepOwnable, Test {
    TwoStepOwnable ownable;

    function setUp() public {
        ownable = TwoStepOwnable(address(this));
        vm.prank(ownable.owner());
        ownable.transferOwnership(address(this));
        ownable.acceptOwnership();
    }

    function testTransferOwnershipDoesNotImmediatelyTransferOwnership() public {
        ownable.transferOwnership(address(1));
        assertEq(ownable.owner(), address(this));
    }

    function testTransferOwnershipRejectsZeroAddress() public {
        vm.expectRevert(TwoStepOwnable.NewOwnerIsZeroAddress.selector);
        ownable.transferOwnership(address(0));
    }

    function testacceptOwnership() public {
        ownable.transferOwnership(address(1));
        vm.prank(address(1));
        ownable.acceptOwnership();
        assertEq(ownable.owner(), address(1));
    }

    function testTransferOwnershipIsStillOnlyOwner() public {
        ownable.transferOwnership(address(1));
        vm.prank(address(1));
        ownable.acceptOwnership();
        // prank is over, back to regular address
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        ownable.transferOwnership(address(5));
    }

    function testCancelTransferOwnership() public {
        ownable.transferOwnership(address(1));
        ownable.cancelOwnershipTransfer();
        vm.startPrank(address(1));
        vm.expectRevert(TwoStepOwnable.NotNextOwner.selector);
        ownable.acceptOwnership();
    }

    function testNotNextOwner() public {
        ownable.transferOwnership(address(1));
        vm.startPrank(address(5));
        vm.expectRevert(TwoStepOwnable.NotNextOwner.selector);
        ownable.acceptOwnership();
    }

    function testOnlyOwnerCanCancelTransferOwnership() public {
        ownable.transferOwnership(address(1));
        vm.prank(address(1));
        ownable.acceptOwnership();
        // prank is over
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        ownable.cancelOwnershipTransfer();
    }
}
