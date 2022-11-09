// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {Test} from "forge-std/Test.sol";
import {ConstructorInitializable} from "../src/ConstructorInitializable.sol";

contract InitializableImpl is ConstructorInitializable {
    function specialMethod() public onlyConstructor {}
}

contract InitializableTest is Test {
    InitializableImpl initializable;

    function setUp() public {
        initializable = new InitializableImpl();
    }

    function testOnlyConstructor() public {
        vm.expectRevert(ConstructorInitializable.AlreadyInitialized.selector);
        initializable.specialMethod();
    }
}
