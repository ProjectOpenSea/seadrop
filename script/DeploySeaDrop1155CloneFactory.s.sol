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

        bytes32 salt = 0x000000000000000000000000000000000000000028a4b5c923003304f4352aab;
        address deployed = _immutableCreate2IfNotDeployed(salt, initCode);
        // require(
        //     deployed == 0x05d588AdcF1D332cB0f9F388f7ebF14339baE584,
        //     "did not deploy to correct address"
        // );
    }
}
