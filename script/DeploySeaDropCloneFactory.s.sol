// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { console2 } from "forge-std/Script.sol";
import {
    ERC721SeaDropCloneFactory
} from "../src/clones/ERC721SeaDropCloneFactory.sol";
import { BaseCreate2Script } from "create2-scripts/BaseCreate2Script.s.sol";

/**
 * @notice Deploy ERC721SeaDropCloneFactory through the ImmutableCreate2Factory,
 *         so it lands at the same address on every network.
 *
 *         SALT (required) is the CREATE2 salt. Its first 20 bytes must be zero
 *         or the deployer's address, which the ImmutableCreate2Factory checks.
 *         To get a vanity address, mine a salt against the init code hash this
 *         script logs. EXPECTED_ADDRESS (optional) must equal the address SALT
 *         produces, so a stale salt fails before anything is broadcast.
 *
 *         DEPLOYER=<address> SALT=0x... EXPECTED_ADDRESS=0x... forge script \
 *           script/DeploySeaDropCloneFactory.s.sol \
 *           --rpc-url <network> --account <keystore> --broadcast --verify
 */
contract DeploySeaDropCloneFactory is BaseCreate2Script {
    /// @dev The ImmutableCreate2Factory BaseCreate2Script deploys through.
    address internal constant IMMUTABLE_CREATE2_FACTORY =
        0x0000000000FFe8B47B3e2130213B802212439497;

    function run() public returns (address deployed) {
        setUp();

        bytes memory initCode = type(ERC721SeaDropCloneFactory).creationCode;
        bytes32 initCodeHash = keccak256(initCode);
        bytes32 salt = vm.envBytes32("SALT");
        address predicted = vm.computeCreate2Address(
            salt, initCodeHash, IMMUTABLE_CREATE2_FACTORY
        );

        console2.log("ERC721SeaDropCloneFactory init code hash:");
        console2.logBytes32(initCodeHash);
        console2.log("Address for SALT:", predicted);

        if (vm.envExists("EXPECTED_ADDRESS")) {
            require(
                vm.envAddress("EXPECTED_ADDRESS") == predicted,
                "SALT does not produce EXPECTED_ADDRESS"
            );
        }

        deployed = _immutableCreate2IfNotDeployed(deployer, salt, initCode);
    }
}
