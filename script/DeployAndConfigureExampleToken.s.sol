// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "forge-std/Script.sol";

import { ExampleToken } from "../examples/ExampleToken.sol";

import { ERC721PartnerSeaDrop } from "../src/ERC721PartnerSeaDrop.sol";

import { ISeaDrop } from "../src/interfaces/ISeaDrop.sol";

import { PublicDrop } from "../src/lib/SeaDropStructs.sol";

contract DeployAndConfigureExampleToken is Script {
    // Addresses
    address seadrop = 0x2fb6FEB663c481E9854a251002C772FEad3974d6;
    address creator = 0x26faf8AE18d15Ed1CA0563727Ad6D4Aa02fb2F80;
    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;
    address minter = 0xf0E16c071E2cd421974dCb76d9af4DeDB578E059;

    // Token config
    uint256 maxSupply = 100;

    // Drop config
    uint16 feeBps = 1000; // 10%
    uint80 mintPrice = 100000000000000; // 0.0001 ether
    uint16 maxTotalMintableByWallet = 10;

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

        token.updatePublicDrop(
            seadrop,
            PublicDrop(
                mintPrice,
                uint48(block.timestamp),
                uint48(block.timestamp) + 1000,
                maxTotalMintableByWallet,
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
