// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script, console2 } from "forge-std/Script.sol";
import {
    ERC721SeaDropCloneFactory
} from "../src/ERC721SeaDropCloneFactory.sol";
import { BaseCreate2Script } from "create2-scripts/BaseCreate2Script.s.sol";

contract DeploySeaDropCloneFactory is BaseCreate2Script {
    event log(bytes32);

    function run() public {
        setUp();
        vm.createSelectFork("mainnet");
        // emit log(keccak256(type(ERC721SeaDropCloneFactory).creationCode));
        bytes32 salt = 0x0000000000000000000000000000000000000000668b68e73536f804134f637c;
        address deployed = _immutableCreate2IfNotDeployed(
            address(deployer),
            salt,
            type(ERC721SeaDropCloneFactory).creationCode
        );
        require(
            deployed == 0x0000000064335cB434247c1143a3695b6DFe1FEf,
            "did not deploy to correct address"
        );
    }
}
