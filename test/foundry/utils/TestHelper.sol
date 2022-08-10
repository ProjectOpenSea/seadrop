// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

contract TestHelper is Test {
    function makeAddrAndKey(string memory name)
        internal
        returns (address addr, uint256 privateKey)
    {
        privateKey = uint256(keccak256(abi.encodePacked(name)));
        addr = vm.addr(privateKey);
        vm.label(addr, name);
    }

    function makeAddr(string memory name) internal returns (address addr) {
        (addr, ) = makeAddrAndKey(name);
    }
}
