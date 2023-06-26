// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";

import { ERC721RaribleDrop } from "../src/ERC721RaribleDrop.sol";

import { IRaribleDrop } from "../src/interfaces/IRaribleDrop.sol";

import { PublicDrop } from "../src/lib/RaribleDropStructs.sol";

contract DeployAndConfigureExampleToken is Script {
    // Addresses
    address raribleDrop = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;
    address creator = 0x5b04Bd4CF6ac8F976a1d578b7156206b781ca861;
    address feeRecipient = 0x5b04Bd4CF6ac8F976a1d578b7156206b781ca861;

    // Token config
    uint256 maxSupply = 100;

    // Drop config
    uint16 feeBps = 500; // 5%
    uint80 mintPrice = 0.0001 ether;
    uint16 maxTotalMintableByWallet = 5;

    function run() external {
        vm.startBroadcast();

        address[] memory allowedRaribledrop = new address[](1);
        allowedRaribledrop[0] = raribleDrop;

        // This example uses ERC721RaribleDrop. For separate Owner and
        // Administrator privileges, use ERC721PartnerRaribleDrop.
        ERC721RaribleDrop token = new ERC721RaribleDrop(
            "My Example Token",
            "ExTKN",
            allowedRaribledrop
        );

        // Configure the token.
        token.setMaxSupply(maxSupply);

        // Configure the drop parameters.
        token.updateCreatorPayoutAddress(raribleDrop, creator);
        token.updateAllowedFeeRecipient(raribleDrop, feeRecipient, true);
        token.updatePublicDrop(
            raribleDrop,
            PublicDrop(
                mintPrice,
                uint48(block.timestamp), // start time
                uint48(block.timestamp) + 1000, // end time
                maxTotalMintableByWallet,
                feeBps,
                true
            )
        );

        // We are ready, let's mint the first 3 tokens!
        IRaribleDrop(raribleDrop).mintPublic{ value: mintPrice * 3 }(
            address(token),
            feeRecipient,
            address(0),
            3 // quantity
        );
    }
}
