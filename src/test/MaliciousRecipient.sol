// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { CreatorPayout } from "../lib/SeaDropStructs.sol";

import { ISeaDropToken } from "../interfaces/ISeaDropToken.sol";

import {
    ConsiderationInterface
} from "seaport-types/src/interfaces/ConsiderationInterface.sol";

import {
    AdvancedOrder,
    CriteriaResolver,
    OrderParameters,
    OfferItem,
    ConsiderationItem,
    ItemType
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { OrderType } from "seaport-types/src/lib/ConsiderationEnums.sol";

abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

contract MaliciousRecipient is ERC1155TokenReceiver {
    bool public startAttack;
    address public token;
    ConsiderationInterface public seaport;

    receive() external payable {
        if (startAttack) {
            startAttack = false;
            seaport.fulfillAdvancedOrder{ value: 1 ether }({
                advancedOrder: _deriveOrder(),
                criteriaResolvers: new CriteriaResolver[](0),
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
            advancedOrder: _deriveOrder(),
            criteriaResolvers: new CriteriaResolver[](0),
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        token = address(0);
        seaport = ConsiderationInterface(address(0));
    }

    function _deriveOrder() internal view returns (AdvancedOrder memory order) {
        uint256 mintPrice = 1 ether;
        uint256 feeBps = 1000;

        address feeRecipient = address(this);
        address minter = address(this);

        uint256 mintQuantity = 1;
        uint256 totalValue = mintPrice * mintQuantity;

        OfferItem[] memory offerItems = new OfferItem[](1);
        offerItems[0] = OfferItem({
            itemType: ItemType.ERC1155,
            token: token,
            identifierOrCriteria: 0,
            startAmount: 1,
            endAmount: 1
        });

        (, bytes memory data) = token.staticcall(
            abi.encode(ISeaDropToken.getCreatorPayouts.selector)
        );
        CreatorPayout[] memory creatorPayouts = abi.decode(
            data,
            (CreatorPayout[])
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
            endTime: block.timestamp + 1000,
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
            bytes20(minter),
            bytes1(0x00) // public drop index (for 1155)
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
