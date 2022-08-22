// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

contract TestHelper is Test, SeaDropErrorsAndEvents {
    address creator = makeAddr("creator");

    struct FuzzInputs {
        uint40 numMints;
        address minter;
        address feeRecipient;
        address[10] allowList;
    }

    modifier validateArgs(FuzzInputs memory args) {
        vm.assume(args.numMints > 0 && args.numMints <= 10);
        vm.assume(args.minter != address(0) && args.feeRecipient != address(0));
        vm.assume(
            args.feeRecipient.code.length == 0 && args.feeRecipient > address(9)
        );
        vm.assume(
            args.minter != args.feeRecipient &&
                args.minter != creator &&
                args.feeRecipient != creator
        );
        _;
    }

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
