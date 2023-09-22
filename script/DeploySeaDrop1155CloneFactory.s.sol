// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console2 } from "forge-std/Script.sol";
import {
    ERC1155SeaDropCloneFactory
} from "../src/clones/ERC1155SeaDropCloneFactory.sol";
import { BaseCreate2Script } from "create2-scripts/BaseCreate2Script.s.sol";

contract DeploySeaDrop1155CloneFactory is BaseCreate2Script {
    function run() public {
        setUp();

        address seaport_v1_5 = 0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
        bytes memory initCode = bytes.concat(
            type(ERC1155SeaDropCloneFactory).creationCode,
            abi.encode(seaport_v1_5)
        );

        bytes32 salt = 0x0000000000000000000000000000000000000000b98a7c38d8355702858f4296;
        address deployed = _immutableCreate2IfNotDeployed(salt, initCode);
        require(
            deployed == 0x000000F20032b9e171844B00EA507E11960BD94a,
            "did not deploy to correct address"
        );
    }
}
