// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ConsiderationInterface
} from "seaport/interfaces/ConsiderationInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    OrderParameters,
    OfferItem,
    ConsiderationItem,
    ItemType
} from "seaport/lib/ConsiderationStructs.sol";

import { OrderType } from "seaport/lib/ConsiderationEnums.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import { CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

contract MaliciousRecipient {
    bool public startAttack;
    address public token;
    ConsiderationInterface public seaport;

    CriteriaResolver[] internal criteriaResolvers;

    receive() external payable {
        if (startAttack) {
            startAttack = false;
            seaport.fulfillAdvancedOrder{ value: 1 ether }({
                advancedOrder: _deriveOrder(token),
                criteriaResolvers: criteriaResolvers,
                fulfillerConduitKey: bytes32(0),
                recipient: address(0)
            });
        }
    }

    // Also receive some eth in the process
    function setStartAttack() public payable {
        startAttack = true;
    }

    function attack(
        ConsiderationInterface _seaport,
        address _token
    ) external payable {
        token = _token;
        seaport = _seaport;

        seaport.fulfillAdvancedOrder{ value: 1 ether }({
            advancedOrder: _deriveOrder(token),
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        token = address(0);
        seaport = ConsiderationInterface(address(0));
    }

    function _deriveOrder(
        address _token
    ) internal returns (AdvancedOrder memory order) {
        address feeRecipient = address(this);
        address minter = address(this);

        uint256 totalValue = 1 ether;
        uint256 feeBps = 1000;

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItem({
            itemType: ItemType.ERC1155,
            token: token,
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        CreatorPayout[] memory creatorPayouts = ERC721SeaDrop(token)
            .getCreatorPayouts();
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
            offerer: token,
            zone: address(0),
            offer: offerItems,
            consideration: considerationItems,
            orderType: OrderType.CONTRACT,
            startTime: block.timestamp,
            endTime: block.timestamp + 1000,
            zoneHash: bytes32(0),
            salt: 0,
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
