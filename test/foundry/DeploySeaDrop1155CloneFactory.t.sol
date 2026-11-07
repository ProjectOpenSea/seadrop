// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import {
    ERC1155SeaDropCloneFactory
} from "../../src/clones/ERC1155SeaDropCloneFactory.sol";

import {
    DeploySeaDrop1155CloneFactory
} from "../../script/DeploySeaDrop1155CloneFactory.s.sol";

/**
 * @notice Runs the ERC-1155 clone factory deploy script against a local EVM,
 *         where BaseCreate2Script etches the ImmutableCreate2Factory.
 */
contract DeploySeaDrop1155CloneFactoryTest is Test {
    address internal constant IMMUTABLE_CREATE2_FACTORY =
        0x0000000000FFe8B47B3e2130213B802212439497;

    address internal constant SEAPORT_1_6 =
        0x0000000000000068F116a894984e2DB1123eB395;

    bytes32 internal constant SALT = bytes32(uint256(1));

    function _predicted(address seaport) internal pure returns (address) {
        return vm.computeCreate2Address(
            SALT,
            keccak256(
                bytes.concat(
                    type(ERC1155SeaDropCloneFactory).creationCode,
                    abi.encode(seaport)
                )
            ),
            IMMUTABLE_CREATE2_FACTORY
        );
    }

    /// @dev One test, because vm.setEnv writes process-wide environment
    ///      variables and Foundry runs tests in parallel.
    function testDeploysToTheSaltAddressWithSeaport16() public {
        vm.setEnv("SALT", vm.toString(SALT));
        DeploySeaDrop1155CloneFactory script =
            new DeploySeaDrop1155CloneFactory();

        // A stale EXPECTED_ADDRESS fails before anything is deployed.
        vm.setEnv("EXPECTED_ADDRESS", vm.toString(address(0xdead)));
        vm.expectRevert("SALT does not produce EXPECTED_ADDRESS");
        script.run();
        assertEq(_predicted(SEAPORT_1_6).code.length, 0);

        // Without SEAPORT set, the factory allows Seaport 1.6.
        vm.setEnv("EXPECTED_ADDRESS", vm.toString(_predicted(SEAPORT_1_6)));
        address deployed = script.run();

        assertEq(deployed, _predicted(SEAPORT_1_6));
        ERC1155SeaDropCloneFactory factory =
            ERC1155SeaDropCloneFactory(deployed);
        assertEq(factory.seaport(), SEAPORT_1_6);
        assertGt(factory.configurer().code.length, 0);
        assertGt(factory.cloneableImplementation().code.length, 0);
    }
}
