// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {TwoStepAdministered} from "../src/TwoStepAdministered.sol";

contract TwoStepAdministeredImpl is TwoStepAdministered(address(0)) {
    function specialMethod() public onlyOwnerOrAdministrator {}
}

contract TwoStepAdministeredTest is Test {
    TwoStepAdministeredImpl administered;

    function setUp() public {
        administered = new TwoStepAdministeredImpl();
        vm.prank(administered.administrator());
        administered.transferAdministration(address(this));
        administered.acceptAdministration();

        administered.transferOwnership(address(42));
        vm.prank(address(42));
        administered.acceptOwnership();
    }

    function testTransferAdministrationDoesNotImmediatelyTransferAdministration()
        public
    {
        administered.transferAdministration(address(1));
        assertEq(administered.administrator(), address(this));
    }

    function testTransferAdministrationRejectsZeroAddress() public {
        vm.expectRevert(
            TwoStepAdministered.NewAdministratorIsZeroAddress.selector
        );

        administered.transferAdministration(address(0));
    }

    function testAcceptAdministration() public {
        administered.transferAdministration(address(1));
        vm.prank(address(1));
        administered.acceptAdministration();
        assertEq(administered.administrator(), address(1));
    }

    function testTransferAdministrationIsStillOnlyAdministrator() public {
        administered.transferAdministration(address(1));
        vm.prank(address(1));
        administered.acceptAdministration();
        // prank is over, back to regular address
        vm.expectRevert(TwoStepAdministered.OnlyAdministrator.selector);
        administered.transferAdministration(address(5));
    }

    function testCancelTransferAdministration() public {
        administered.transferAdministration(address(1));
        administered.cancelAdministrationTransfer();
        vm.startPrank(address(1));
        vm.expectRevert(TwoStepAdministered.NotNextAdministrator.selector);
        administered.acceptAdministration();
    }

    function testNotNextAdministrator() public {
        administered.transferAdministration(address(1));
        vm.startPrank(address(5));
        vm.expectRevert(TwoStepAdministered.NotNextAdministrator.selector);
        administered.acceptAdministration();
    }

    function testOnlyAdministratorCanCancelTransferAdministration() public {
        administered.transferAdministration(address(1));
        vm.prank(address(1));
        administered.acceptAdministration();
        // prank is over
        vm.expectRevert(TwoStepAdministered.OnlyAdministrator.selector);
        administered.cancelAdministrationTransfer();
    }

    function testOnlyOwnerOrAdministrator() public {
        administered.specialMethod();
        vm.prank(administered.owner());
        administered.specialMethod();
    }

    function testOnlyOwnerOrAdministrator_reverts(
        address notOwnerOrAdministrator
    ) public {
        vm.assume(
            notOwnerOrAdministrator != administered.owner() &&
                notOwnerOrAdministrator != administered.administrator()
        );
        vm.startPrank(notOwnerOrAdministrator);
        vm.expectRevert(TwoStepAdministered.OnlyOwnerOrAdministrator.selector);

        administered.specialMethod();
    }
}
