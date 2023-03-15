// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    ERC721SeaDropCloneFactory
} from "../../src/clones/ERC721SeaDropCloneFactory.sol";
import {
    ERC721SeaDropCloneable
} from "../../src/clones/ERC721SeaDropCloneable.sol";
import { SeaDrop } from "../../src/SeaDrop.sol";
import { PublicDrop } from "../../src/lib/SeaDropStructs.sol";

contract ERC721SeaDropCloneFactoryTest is Test {
    ERC721SeaDropCloneFactory factory;

    function setUp() public {
        factory = new ERC721SeaDropCloneFactory();
    }

    function testClone__snapshot() public {
        factory.createClone("name", "symbol", bytes32("1"));
    }

    event SeaDropTokenDeployed();

    function testClone1() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl);
        factory = new ERC721SeaDropCloneFactory();
        vm.expectEmit(false, false, false, false);
        emit SeaDropTokenDeployed();
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(clone);

        assertEq(token.name(), "name", "name should be set");
        assertEq(token.symbol(), "symbol", "symbol should be set");
        assertEq(token.owner(), address(this), "owner should be set");
        token.updateCreatorPayoutAddress(
            factory.DEFAULT_SEADROP(),
            address(1234)
        );
        SeaDrop seaDrop = SeaDrop(factory.DEFAULT_SEADROP());
        assertEq(
            seaDrop.getCreatorPayoutAddress(address(token)),
            address(1234)
        );

        assertEq(token.totalSupply(), 0);

        token.updatePublicDrop(
            factory.DEFAULT_SEADROP(),
            PublicDrop({
                mintPrice: 1 ether,
                startTime: uint48(block.timestamp),
                endTime: uint48(block.timestamp + 1 days),
                maxTotalMintableByWallet: 3,
                feeBps: 0,
                restrictFeeRecipients: false
            })
        );
        token.setMaxSupply(100);

        seaDrop.mintPublic{ value: 1 ether }(
            address(token),
            address(1),
            address(0),
            1
        );
        assertEq(token.totalSupply(), 1);
        assertEq(token.ownerOf(1), address(this));

        assertEq(token.tokenURI(1), "", "tokenURI should be blank at first");
        assertEq(token.baseURI(), "", "baseURI should be blank at first");

        token.setBaseURI("https://example.com");
        assertEq(
            token.tokenURI(1),
            token.baseURI(),
            "tokenURI just the baseURI"
        );

        token.setBaseURI("https://example.com/");
        assertEq(
            token.tokenURI(1),
            string(abi.encodePacked(token.baseURI(), "1")),
            "tokenURI the baseURI + tokenID"
        );
    }

    function testClone_Reinitialize() public {
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(clone);
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize("name", "symbol", new address[](0), address(this));
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
