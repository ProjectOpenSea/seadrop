// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import {
    ERC1155SeaDropCloneFactory
} from "../../src/clones/ERC1155SeaDropCloneFactory.sol";

import {
    ERC1155SeaDropCloneable
} from "../../src/clones/ERC1155SeaDropCloneable.sol";

import {
    SeaDropErrorsAndEvents
} from "../../src/lib/SeaDropErrorsAndEvents.sol";

import { IERC1155SeaDrop } from "../../src/interfaces/IERC1155SeaDrop.sol";

import { ERC1155SeaDrop } from "../../src/ERC1155SeaDrop.sol";

import { PublicDrop } from "seadrop/lib/ERC1155SeaDropStructs.sol";

import { CreatorPayout } from "seadrop/lib/SeaDropStructs.sol";

import { AdvancedOrder } from "seaport-types/src/lib/ConsiderationStructs.sol";

import { BaseOrderTest } from "seaport-test-utils/BaseOrderTest.sol";

contract ERC1155SeaDropCloneFactoryTest is SeaDrop1155Test {
    ERC1155SeaDropCloneFactory factory;
    uint256 feeBps = 500;

    function setUp() public override {
        super.setUp();

        factory = new ERC1155SeaDropCloneFactory(address(consideration));
    }

    function testClone__snapshot() public {
        factory.createClone("name", "symbol", bytes32("1"));
    }

    function testClone1() public {
        vm.expectEmit(false, false, false, false);
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC1155_CLONE);
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        token = ERC1155SeaDrop(clone);

        assertEq(token.name(), "name", "name should be set");
        assertEq(token.symbol(), "symbol", "symbol should be set");
        assertEq(token.owner(), address(this), "owner should be set");

        address creator = makeAddr("creator");
        setSingleCreatorPayout(creator);

        assertEq(token.totalSupply(0), 0);
        assertEq(token.totalSupply(1), 0);

        address feeRecipient = makeAddr("feeRecipient");
        IERC1155SeaDrop(clone).updateAllowedFeeRecipient(feeRecipient, true);
        token.setMaxSupply(1, 10);
        token.setMaxSupply(3, 10);

        PublicDrop memory publicDrop = PublicDrop({
            startPrice: 1 ether,
            endPrice: 1 ether,
            startTime: uint40(block.timestamp),
            endTime: uint40(block.timestamp + 500),
            paymentToken: address(0),
            fromTokenId: 1,
            toTokenId: 3,
            maxTotalMintableByWallet: 6,
            maxTotalMintableByWalletPerToken: 5,
            feeBps: uint16(feeBps),
            restrictFeeRecipients: true
        });
        IERC1155SeaDrop(clone).updatePublicDrop(publicDrop, 0);

        addSeaDropOfferItem(1, 3); // token id 1, 3 mints
        addSeaDropOfferItem(3, 1); // token id 3, 1 mint
        addSeaDropConsiderationItems(feeRecipient, feeBps, 4 ether);
        configureSeaDropOrderParameters();

        address minter = address(this);
        bytes memory extraData = bytes.concat(
            bytes1(0x00), // SIP-6 version byte
            bytes1(0x00), // substandard version byte: public mint
            bytes20(feeRecipient),
            bytes20(minter),
            bytes1(0x00) // public drop index 0
        );

        AdvancedOrder memory order = AdvancedOrder({
            parameters: baseOrderParameters,
            numerator: 1,
            denominator: 1,
            signature: "",
            extraData: extraData
        });

        vm.deal(address(this), 10 ether);

        vm.expectEmit(true, true, true, true, address(token));
        emit SeaDropMint(address(this), 0);

        consideration.fulfillAdvancedOrder{ value: 4 ether }({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.balanceOf(minter, 1), 3);
        assertEq(token.balanceOf(minter, 3), 1);
        assertEq(creator.balance, 4 ether * 0.95);

        // Minting any more should exceed maxTotalMintableByWalletPerToken
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidContractOrder.selector,
                (uint256(uint160(address(token))) << 96) +
                    consideration.getContractOffererNonce(address(token))
            )
        );
        consideration.fulfillAdvancedOrder({
            advancedOrder: order,
            criteriaResolvers: criteriaResolvers,
            fulfillerConduitKey: bytes32(0),
            recipient: address(0)
        });

        assertEq(token.uri(1), "", "tokenURI should be blank at first");
        assertEq(token.baseURI(), "", "baseURI should be blank at first");

        token.setBaseURI("https://example.com");
        assertEq(token.baseURI(), "https://example.com");
        assertEq(token.uri(1), "https://example.com");
    }

    function testClone_Reinitialize() public {
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC1155SeaDropCloneable token = ERC1155SeaDropCloneable(clone);
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize(
            address(0),
            address(0),
            "name",
            "symbol",
            address(this)
        );
    }
}
