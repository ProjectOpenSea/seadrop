// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console2 } from "forge-std/Script.sol";
import {
    ERC1155SeaDropCloneFactory
} from "../src/clones/ERC1155SeaDropCloneFactory.sol";
import { BaseCreate2Script } from "create2-scripts/BaseCreate2Script.s.sol";

/**
 * @notice Deploy ERC1155SeaDropCloneFactory through the ImmutableCreate2Factory,
 *         so it lands at the same address on every network.
 *
 *         SEAPORT (optional) is the Seaport the factory's clones allow,
 *         Seaport 1.6 by default. It's a constructor argument, so it changes
 *         the init code hash.
 *
 *         SALT (required) is the CREATE2 salt. Its first 20 bytes must be zero
 *         or the deployer's address, which the ImmutableCreate2Factory checks.
 *         To get a vanity address, mine a salt against the init code hash this
 *         script logs. EXPECTED_ADDRESS (optional) must equal the address SALT
 *         produces, so a stale salt fails before anything is broadcast.
 *
 *         DEPLOYER=<address> SALT=0x... EXPECTED_ADDRESS=0x... forge script \
 *           script/DeploySeaDrop1155CloneFactory.s.sol \
 *           --rpc-url <network> --account <keystore> --broadcast --verify
 */
contract DeploySeaDrop1155CloneFactory is BaseCreate2Script {
    /// @dev The ImmutableCreate2Factory BaseCreate2Script deploys through.
    address internal constant IMMUTABLE_CREATE2_FACTORY =
        0x0000000000FFe8B47B3e2130213B802212439497;

    /// @dev Seaport 1.6, which OpenSea's ERC-1155 clones mint through.
    address internal constant SEAPORT_1_6 =
        0x0000000000000068F116a894984e2DB1123eB395;

    function run() public returns (address deployed) {
        setUp();

        address seaport = vm.envOr("SEAPORT", SEAPORT_1_6);
        bytes memory initCode = bytes.concat(
            type(ERC1155SeaDropCloneFactory).creationCode, abi.encode(seaport)
        );
        bytes32 initCodeHash = keccak256(initCode);
        bytes32 salt = vm.envBytes32("SALT");
        address predicted = vm.computeCreate2Address(
            salt, initCodeHash, IMMUTABLE_CREATE2_FACTORY
        );

        console2.log("Seaport:", seaport);
        console2.log("ERC1155SeaDropCloneFactory init code hash:");
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
