// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
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

contract ERC1155SeaDropCloneFactoryTest is Test, SeaDropErrorsAndEvents {
    ERC1155SeaDropCloneFactory factory;

    function setUp() public {
        factory = new ERC1155SeaDropCloneFactory();
    }

    function testClone__snapshot() public {
        factory.createClone("name", "symbol", bytes32("1"));
    }

    function testClone1() public {
        vm.createSelectFork(getChain("mainnet").rpcUrl);
        factory = new ERC1155SeaDropCloneFactory();
        vm.expectEmit(false, false, false, false);
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC1155_CLONE);
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC1155SeaDropCloneable token = ERC1155SeaDropCloneable(clone);

        assertEq(token.name(), "name", "name should be set");
        assertEq(token.symbol(), "symbol", "symbol should be set");
        assertEq(token.owner(), address(this), "owner should be set");

        IERC1155SeaDrop(token).updateCreatorPayoutAddress(address(1234));
        assertEq(
            IERC1155SeaDrop(token).getCreatorPayoutAddress(address(token)),
            address(1234)
        );

        assertEq(token.totalSupply(), 0);

        /*
        TODO update to minting through Seaport
        token.updatePublicDrop(
            factory.DEFAULT_SEADROP(),
            PublicDrop({
                mintPrice: 1 ether,
                startTime: uint40(block.timestamp),
                endTime: uint40(block.timestamp + 1 days),
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
        */
    }

    function testClone_Reinitialize() public {
        address clone = factory.createClone("name", "symbol", bytes32("1"));
        ERC1155SeaDropCloneable token = ERC1155SeaDropCloneable(clone);
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize("name", "symbol", new address[](0), address(this));
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
