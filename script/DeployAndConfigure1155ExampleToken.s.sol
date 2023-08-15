// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import { ERC1155SeaDrop } from "../src/ERC1155SeaDrop.sol";

import {
    ERC1155SeaDropConfigurer
} from "../src/lib/ERC1155SeaDropConfigurer.sol";

import { IERC1155SeaDrop } from "../src/interfaces/IERC1155SeaDrop.sol";

import { AllowListData, CreatorPayout } from "../src/lib/SeaDropStructs.sol";

import { PublicDrop } from "../src/lib/ERC1155SeaDropStructs.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    CriteriaResolver,
    ItemType,
    OfferItem,
    ConsiderationItem,
    AdvancedOrder,
    OrderComponents,
    OrderParameters,
    FulfillmentComponent
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { OrderType } from "seaport-types/src/lib/ConsiderationEnums.sol";

contract DeployAndConfigure1155ExampleToken is Script {
    // Addresses: Seaport
    address seaport = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    address conduit = 0x1E0049783F008A0085193E00003D00cd54003c71;

    // Addresses: SeaDrop
    address creator = 0x82C21dc207C1F934dFDCa7Ab95eB139Df75DA0B2;
    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;
    
    // We already deployed a configurer that any 1155 NFT contract can rely. Similar concept for proxy / factory contracts where most of the logic lives inside configurer.
    address configurer = 0x00CDa53500210086ea24006a70009400B81d8437;

    address tokenAddress = 0x5b0cEc618Eb2A04907b7dB7613D30118E0d9D14d;
    
    // Token config
    uint256 maxSupply = 160;

    // Drop config
    uint16 feeBps = 1000; // 5%
    uint80 mintPrice = 0 ether;
    uint16 maxTotalMintableByWallet = 10;

    function run() external {
        vm.startBroadcast();

        
        ERC1155SeaDrop token = new ERC1155SeaDrop(
            configurer,
            conduit,
            seaport,
            "One Token 1155",
            "OT"
        );
        tokenAddress = address(token);
        // Configure the token.
        token.setMaxSupply(1, maxSupply);
        
        // Configure the drop parameters.
        setSingleCreatorPayout(token);
        IERC1155SeaDrop(address(token)).updateAllowedFeeRecipient(
            feeRecipient,
            true
        );
        IERC1155SeaDrop(tokenAddress).updatePublicDrop(
            PublicDrop({
                startPrice: mintPrice,
                endPrice: mintPrice,
                startTime: 1691856000,
                endTime: 1691856001,
                paymentToken: address(0),
                fromTokenId: 1,
                toTokenId: 4,
                maxTotalMintableByWallet: maxTotalMintableByWallet,
                maxTotalMintableByWalletPerToken: maxTotalMintableByWallet,
                feeBps: feeBps,
                restrictFeeRecipients: true
            }),
            0
        );

        // Will only need these if you want to set up a presale 
        // IERC1155SeaDrop(tokenAddress).updateDropURI("https://opensea-partners.mypinata.cloud/ipfs/bafkreib74cukyky5lnhnt7vxj52oh6wam2mkyrfx252ct33cfrpn44437u");
        // string[] memory pubkeys = new string[](1);
        // pubkeys[0] = "https://opensea.io/.well-known/allowlist-pubkeys/mainnet/ALLOWLIST_ENCRYPTION_KEY_0.txt";
        // IERC1155SeaDrop(tokenAddress).updateAllowList(
        //     AllowListData(
        //         0x6d9894bca0dfdc416f8c241afe3591d7989bdaae4c16e517d6bd7abf29bf8d10,
        //         pubkeys,
        //         "https://opensea-partners.mypinata.cloud/ipfs/bafkreifuxgr4n6z42bawrz56vtqu76ra723l7b5wiemrxgqnx4y5st4e6q"
        //     )
        // );

        // Some IPFS baseURI where there is a single token metadata file w/ traits set up on it (for the selector)
        IERC1155SeaDrop(tokenAddress).setBaseURI("ipfs://Qmf43FYfjAYxxbymiMAGfNzicA5xC69x4ia8sf3FPmFuC9/{id}");

        // If you want to manually mint some tookens
        // ConsiderationInterface(seaport).fulfillAdvancedOrder{
        //     value: mintPrice * 3
        // }({
        //     advancedOrder: deriveOrder(address(token), 3),
        //     criteriaResolvers: new CriteriaResolver[](0),
        //     fulfillerConduitKey: bytes32(0),
        //     recipient: address(0)
        // });
    }

    function setSingleCreatorPayout(ERC1155SeaDrop token) internal {
        CreatorPayout[] memory creatorPayouts = new CreatorPayout[](1);
        creatorPayouts[0] = CreatorPayout({
            payoutAddress: creator,
            basisPoints: 10_000
        });
        IERC1155SeaDrop(address(token)).updateCreatorPayouts(creatorPayouts);
    }
}
