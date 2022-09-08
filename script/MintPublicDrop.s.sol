// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Script.sol";

import { ISeaDrop } from "../src/interfaces/ISeaDrop.sol";

contract MintPublicDrop is Script {
    // Addresses
    address seadrop = 0x53002b539B8eB1EDe580fc2D86640240CFfFC6B2;
    address token = 0x044F927CFa2D5bDD1DA9E5F6AE45ad7d778b756A;
    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;

    // Drop config
    uint80 mintPrice = 100000000000000; // 0.0001 ether

    function run() external {
        vm.startBroadcast();

        uint256 quantity = 3;
        ISeaDrop(seadrop).mintPublic{ value: quantity * mintPrice }(
            address(token),
            feeRecipient,
            address(0),
            quantity
        );
    }
}
