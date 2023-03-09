// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script, console2} from "forge-std/Script.sol";
import {ERC721SeaDropCloneFactory} from "../src/clones/ERC721SeaDropCloneFactory.sol";
import {BaseCreate2Script} from "create2-scripts/BaseCreate2Script.s.sol";

contract DeploySeaDropCloneFactory is BaseCreate2Script {
    event log(bytes32);

    function run() public {
        setUp();
        vm.createSelectFork("goerli");
        emit log(keccak256(type(ERC721SeaDropCloneFactory).creationCode));
        // bytes32 salt = 0x000000000000000000000000000000000000000021f603d672480b0267b5cad3;
        // address deployed =
        //     _immutableCreate2IfNotDeployed(address(deployer), salt, type(ERC721SeaDropCloneFactory).creationCode);
        // require(deployed == 0x0000000092A8aC080B3100419c79139bEe23194F, "did not deploy to correct address");
    }
}
