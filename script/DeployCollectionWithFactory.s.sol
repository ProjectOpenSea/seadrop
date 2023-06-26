// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Script, console2 } from "forge-std/Script.sol";
import {
    ERC721RaribleDropCloneFactory
} from "../src/clones/ERC721RaribleDropCloneFactory.sol";
import {ScriptBase, console2} from "./ScriptBase.sol";

contract DeployCollectionWithFactory is ScriptBase {
    ERC721RaribleDropCloneFactory constant factory =
        ERC721RaribleDropCloneFactory(0x4a6f0452f21dB81Da87bCB6a940a73D523E4218E);

    function run() public {
        setUp();
        bytes32 salt = bytes32(0x0000000000000000000000000000000000000000d40ba0de8b5adb1cc4070000);
        string memory name = "Test Token";
        string memory symbol = "TT";
        vm.broadcast(deployer);
        address res = factory.createClone(name, symbol, salt);
        console2.logAddress(res);
    }
}
