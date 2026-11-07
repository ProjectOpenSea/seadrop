// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Test } from "forge-std/Test.sol";

import {
    ERC721SeaDropCloneFactory
} from "../../src/clones/ERC721SeaDropCloneFactory.sol";

import {
    DeploySeaDropCloneFactory
} from "../../script/DeploySeaDropCloneFactory.s.sol";

/**
 * @notice Runs the clone factory deploy script against a local EVM, where
 *         BaseCreate2Script etches the ImmutableCreate2Factory.
 */
contract DeploySeaDropCloneFactoryTest is Test {
    address internal constant IMMUTABLE_CREATE2_FACTORY =
        0x0000000000FFe8B47B3e2130213B802212439497;

    bytes32 internal constant SALT = bytes32(uint256(1));

    function _predicted() internal pure returns (address) {
        return vm.computeCreate2Address(
            SALT,
            keccak256(type(ERC721SeaDropCloneFactory).creationCode),
            IMMUTABLE_CREATE2_FACTORY
        );
    }

    /// @dev One test, because vm.setEnv writes process-wide environment
    ///      variables and Foundry runs tests in parallel.
    function testDeploysToTheSaltAddress() public {
        vm.setEnv("SALT", vm.toString(SALT));
        DeploySeaDropCloneFactory script = new DeploySeaDropCloneFactory();

        // An explicit zero address is checked like any other.
        vm.setEnv("EXPECTED_ADDRESS", vm.toString(address(0)));
        vm.expectRevert("SALT does not produce EXPECTED_ADDRESS");
        script.run();

        // A stale EXPECTED_ADDRESS fails before anything is deployed.
        vm.setEnv("EXPECTED_ADDRESS", vm.toString(address(0xdead)));
        vm.expectRevert("SALT does not produce EXPECTED_ADDRESS");
        script.run();
        assertEq(_predicted().code.length, 0);

        vm.setEnv("EXPECTED_ADDRESS", vm.toString(_predicted()));
        address deployed = script.run();

        assertEq(deployed, _predicted());
        assertGt(deployed.code.length, 0);
        // The factory deploys its cloneable implementation in its
        // constructor.
        assertGt(
            ERC721SeaDropCloneFactory(deployed)
                .seaDropCloneableUpgradeableImplementation()
                .code
                .length,
            0
        );
    }
}
