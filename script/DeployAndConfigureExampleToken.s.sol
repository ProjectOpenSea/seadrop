// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import { ERC721SeaDrop } from "../src/ERC721SeaDrop.sol";

import {
    ERC721SeaDropConfigurer
} from "../src/lib/ERC721SeaDropConfigurer.sol";

import { CreatorPayout } from "../src/lib/SeaDropStructs.sol";

import { PublicDrop } from "../src/lib/ERC721SeaDropStructs.sol";

import {
    ConsiderationInterface
} from "seaport/interfaces/ConsiderationInterface.sol";

import {
    CriteriaResolver,
    ItemType,
    OfferItem,
    ConsiderationItem,
    AdvancedOrder,
    OrderComponents,
    OrderParameters,
    FulfillmentComponent
} from "seaport/lib/ConsiderationStructs.sol";

import { OrderType } from "seaport/lib/ConsiderationEnums.sol";

contract DeployAndConfigureExampleToken is Script {
    // Addresses: Seaport
    address seaport = 0x00000000000001ad428e4906aE43D8F9852d0dD6;
    address conduit = 0x1E0049783F008A0085193E00003D00cd54003c71;

    // Addresses: SeaDrop
    address creator = 0x1108f964b384f1dCDa03658B24310ccBc48E226F;
    address feeRecipient = 0x0000a26b00c1F0DF003000390027140000fAa719;

    // Token config
    uint256 maxSupply = 100;

    // Drop config
    uint16 feeBps = 500; // 5%
    uint80 mintPrice = 0.0001 ether;
    uint16 maxTotalMintableByWallet = 25;

    function run() external {
        vm.startBroadcast();

        ERC721SeaDropConfigurer configurer = new ERC721SeaDropConfigurer();

        ERC721SeaDrop token = new ERC721SeaDrop(
            "My Example Token",
            "ExTKN",
            address(configurer),
            conduit,
            seaport
        );

        // Configure the token.
        token.setMaxSupply(maxSupply);

        // Configure the drop parameters.
        setSingleCreatorPayout(configurer, token);
        configurer.updateAllowedFeeRecipient(
            address(token),
            feeRecipient,
            true
        );
        configurer.updatePublicDrop(
            address(token),
            PublicDrop({
                startPrice: mintPrice,
                endPrice: mintPrice,
                paymentToken: address(0),
                startTime: uint48(block.timestamp),
                endTime: uint48(block.timestamp) + 10_000_000,
                maxTotalMintableByWallet: maxTotalMintableByWallet,
                feeBps: feeBps,
                restrictFeeRecipients: true
            })
        );

        // We are ready, let's mint the first 3 tokens!
        ConsiderationInterface(seaport).fulfillAdvancedOrder{
            value: mintPrice * 3
        }({
            advancedOrder: deriveOrder(configurer, address(token), 3),
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });
    }

    function setSingleCreatorPayout(
        ERC721SeaDropConfigurer configurer,
        ERC721SeaDrop token
    ) internal {
        CreatorPayout[] memory creatorPayouts = new CreatorPayout[](1);
        creatorPayouts[0] = CreatorPayout({
            payoutAddress: creator,
            basisPoints: 10_000
        });
        configurer.updateCreatorPayouts(address(token), creatorPayouts);
    }

    function deriveOrder(
        ERC721SeaDropConfigurer configurer,
        address token,
        uint256 quantity
    ) internal view returns (AdvancedOrder memory order) {
        address minter = msg.sender;
        uint256 totalValue = mintPrice * quantity;

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItem({
            itemType: ItemType.ERC1155,
            token: token,
            identifierOrCriteria: 0,
            startAmount: quantity,
            endAmount: quantity
        });

        CreatorPayout[] memory creatorPayouts = configurer.getCreatorPayouts(
            address(token)
        );
        ConsiderationItem[] memory considerationItems = new ConsiderationItem[](
            creatorPayouts.length + 1
        );

        // Add consideration item for fee recipient.
        uint256 feeAmount = (totalValue * feeBps) / 10_000;
        uint256 creatorAmount = totalValue - feeAmount;
        considerationItems[0] = ConsiderationItem({
            itemType: ItemType.NATIVE,
            token: address(0),
            identifierOrCriteria: 0,
            startAmount: feeAmount,
            endAmount: feeAmount,
            recipient: payable(feeRecipient)
        });

        // Add consideration items for creator payouts.
        for (uint256 i = 0; i < creatorPayouts.length; i++) {
            uint256 amount = (creatorAmount * creatorPayouts[i].basisPoints) /
                10_000;
            considerationItems[i + 1] = ConsiderationItem({
                itemType: ItemType.NATIVE,
                token: address(0),
                identifierOrCriteria: 0,
                startAmount: amount,
                endAmount: amount,
                recipient: payable(creatorPayouts[i].payoutAddress)
            });
        }

        OrderParameters memory orderParameters = OrderParameters({
            orderType: OrderType.CONTRACT,
            offerer: token,
            offer: offerItems,
            consideration: considerationItems,
            startTime: block.timestamp,
            endTime: block.timestamp + 10_000_000,
            salt: 0,
            zone: address(0),
            zoneHash: bytes32(0),
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: considerationItems.length
        });

        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version byte: public mint
            bytes20(feeRecipient),
            bytes20(minter)
        );

        order = AdvancedOrder({
            parameters: orderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });
    }
}
