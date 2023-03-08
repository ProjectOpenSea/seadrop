// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script, console2 } from "forge-std/Script.sol";
import {
    ERC721SeaDropCloneFactory
} from "../src/ERC721SeaDropCloneFactory.sol";
import { BaseCreate2Script } from "create2-scripts/BaseCreate2Script.s.sol";

contract DeploySeaDropCloneFactory is BaseCreate2Script {
    function run() public {
        setUp();
        vm.createSelectFork("mainnet");
        bytes32 salt = 0x00000000000000000000000000000000000000002880aa7f8ae2ea08631058e6;
        address deployed = _immutableCreate2IfNotDeployed(
            address(deployer),
            salt,
            type(ERC721SeaDropCloneFactory).creationCode
        );
        require(
            deployed == 0x00000000C2f8CB9a79739832b90D9718219833dE,
            "did not deploy to correct"
        );
    }
}
