// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721RaribleDropCloneable } from "./ERC721RaribleDropCloneable.sol";

import { Clones } from "openzeppelin-contracts/proxy/Clones.sol";

contract ERC721RaribleDropCloneFactory {
    address public immutable raribleDropCloneableUpgradeableImplementation;
    address public constant DEFAULT_RARIBLEDROP =
        0x1b916f0472e68A4b4d787BDe7dF13eb255721B90;

    constructor() {
        ERC721RaribleDropCloneable impl = new ERC721RaribleDropCloneable();
        impl.initialize("", "", new address[](0), address(this));
        raribleDropCloneableUpgradeableImplementation = address(impl);
    }

    function createClone(
        string memory name,
        string memory symbol,
        bytes32 salt
    ) external returns (address) {
        // Derive a pseudo-random salt, so clone addresses don't collide
        // across chains.
        bytes32 cloneSalt = keccak256(
            abi.encodePacked(salt, blockhash(block.number))
        );

        address instance = Clones.cloneDeterministic(
            raribleDropCloneableUpgradeableImplementation,
            cloneSalt
        );
        address[] memory allowedRaribleDrop = new address[](1);
        allowedRaribleDrop[0] = DEFAULT_RARIBLEDROP;
        ERC721RaribleDropCloneable(instance).initialize(
            name,
            symbol,
            allowedRaribleDrop,
            msg.sender
        );
        return instance;
    }
}
