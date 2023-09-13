// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1155SeaDropCloneable } from "./ERC1155SeaDropCloneable.sol";

import { ERC1155SeaDropConfigurer } from "../lib/ERC1155SeaDropConfigurer.sol";

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title  ERC1155SeaDropCloneFactory
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A factory contract that deploys ERC1155 token contracts
 *         that can mint as Seaport contract offerers.
 */
contract ERC1155SeaDropCloneFactory {
    address public immutable seaport;
    address public immutable conduit;
    address public immutable configurer;
    address public immutable cloneableImplementation;

    constructor(address allowedConduit, address allowedSeaport) {
        conduit = allowedConduit;
        seaport = allowedSeaport;

        ERC1155SeaDropConfigurer config = new ERC1155SeaDropConfigurer();
        configurer = address(config);

        ERC1155SeaDropCloneable impl = new ERC1155SeaDropCloneable();
        impl.initialize(configurer, conduit, seaport, "", "", address(this));
        cloneableImplementation = address(impl);
    }

    function createClone(
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (address instance) {
        // Derive a pseudo-random salt, so clone addresses don't collide
        // across chains.
        bytes32 cloneSalt = keccak256(
            abi.encodePacked(salt, blockhash(block.number))
        );

        instance = Clones.cloneDeterministic(
            cloneableImplementation,
            cloneSalt
        );
        ERC1155SeaDropCloneable(instance).initialize(
            configurer,
            conduit,
            seaport,
            name,
            symbol,
            msg.sender
        );
    }
}
