// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Script.sol";

import { ExampleToken } from "../examples/ExampleToken.sol";

import { ERC721SeaDrop } from "../src/ERC721SeaDrop.sol";

import { ISeaDrop } from "../src/interfaces/ISeaDrop.sol";

import { PublicDrop } from "../src/lib/SeaDropStructs.sol";

contract DeployAndConfigureExampleToken is Script {
    // Addresses
    address seadrop = 0x2fb6FEB663c481E9854a251002C772FEad3974d6;
    address creator = 0x8252cAcDf4318A65Fb061B0AFe127afe770b8067;
    address feeRecipient = 0xf0E16c071E2cd421974dCb76d9af4DeDB578E059;
    address minter = 0x6C1C4f642ab5611A46ee6F3ED95Bbf2E3Caf4D1c;

    // Token config
    uint256 maxSupply = 1000;

    // Drop config
    uint16 feeBps = 100;
    uint80 mintPrice = 10000000000000; // 0.00001 ether
    uint40 maxMintsPerWallet = 10;

    function run() external {
        vm.startBroadcast();

        address[] memory allowedSeadrop = new address[](1);
        allowedSeadrop[0] = seadrop;

        ExampleToken token = new ExampleToken(
            "My Example Token",
            "ExTKN",
            msg.sender,
            allowedSeadrop
        );

        token.setMaxSupply(maxSupply);

        token.updateCreatorPayoutAddress(seadrop, creator);

        token.updateAllowedFeeRecipient(seadrop, feeRecipient, true);
        token.updatePublicDropFee(seadrop, feeBps);

        token.updatePublicDrop(
            seadrop,
            PublicDrop(
                mintPrice,
                uint64(block.timestamp),
                maxMintsPerWallet,
                feeBps,
                true
            )
        );

        // We are ready, let's mint the first 3 tokens!
        uint256 quantity = 3;
        ISeaDrop(seadrop).mintPublic{ value: quantity * mintPrice }(
            address(token),
            feeRecipient,
            minter,
            quantity
        );
    }
}
