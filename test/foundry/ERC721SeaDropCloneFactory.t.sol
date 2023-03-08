// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import {
    ERC721SeaDropCloneFactory
} from "../../src/ERC721SeaDropCloneFactory.sol";
import { ERC721SeaDropCloneable } from "../../src/ERC721SeaDropCloneable.sol";
import { SeaDrop } from "../../src/SeaDrop.sol";

contract ERC721SeaDropCloneFactoryTest is Test {
    ERC721SeaDropCloneFactory factory;

    function setUp() public {
        factory = new ERC721SeaDropCloneFactory();
    }

    function testClone__snapshot() public {
        factory.createClone("name", "symbol");
    }

    function testClone1() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl);
        factory = new ERC721SeaDropCloneFactory();
        address clone = factory.createClone("name", "symbol");
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
    }

    function testClone_Reinitialize() public {
        address clone = factory.createClone("name", "symbol");
        ERC721SeaDropCloneable token = ERC721SeaDropCloneable(clone);
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize("name", "symbol", new address[](0), address(this));
    }
}
