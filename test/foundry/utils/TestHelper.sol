// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { SeaDrop } from "seadrop/SeaDrop.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { SeaDropErrorsAndEvents } from "seadrop/lib/SeaDropErrorsAndEvents.sol";

contract TestHelper is Test, SeaDropErrorsAndEvents {
    SeaDrop seadrop = new SeaDrop();
    ERC721SeaDrop token;

    mapping(address => uint256) privateKeys;
    mapping(bytes => address) seedAddresses;

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

    function makeAndStoreAddrAndKey(bytes memory seed)
        public
        returns (address)
    {
        uint256 pk = uint256(keccak256(seed));
        address derived = vm.addr(pk);
        seedAddresses[seed] = derived;
        privateKeys[derived] = pk;
        return derived;
    }

    function makeAddr(string memory name) internal returns (address addr) {
        (addr, ) = makeAddrAndKey(name);
    }
}
