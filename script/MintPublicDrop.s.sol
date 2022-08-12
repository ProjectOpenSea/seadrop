// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Script.sol";

import { ISeaDrop } from "../src/interfaces/ISeaDrop.sol";

contract MintPublicDrop is Script {
    // Addresses
    address seadrop = 0x18e55C1728c2CA06878b6b609a26c978596C27EB;
    address token = 0x044F927CFa2D5bDD1DA9E5F6AE45ad7d778b756A;
    address feeRecipient = 0xf0E16c071E2cd421974dCb76d9af4DeDB578E059;
    address minter = 0xfBa662e1a8e91a350702cF3b87D0C2d2Fb4BA57F;

    // Drop config
    uint80 mintPrice = 10000000000000; // 0.00001 ether

    function run() external {
        vm.startBroadcast();

        uint256 quantity = 3;
        ISeaDrop(seadrop).mintPublic{ value: quantity * mintPrice }(
            address(token),
            feeRecipient,
            minter,
            quantity
        );
    }
}
