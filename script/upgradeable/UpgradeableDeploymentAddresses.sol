// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { Script } from "forge-std/Script.sol";

/**
 * @notice Shared helper for the ERC721SeaDropUpgradeable deploy and upgrade
 *         scripts: reading a proxy's admin and implementation from its
 *         ERC-1967 slots.
 *
 *         The scripts don't write an addresses file. forge script runs them in
 *         simulation before broadcasting, so a file written there would also
 *         be written on dry runs and on broadcasts that fail. forge script
 *         prints the run() return value, and the receipt-backed record of a
 *         broadcast is broadcast/<script>/<chain id>/run-latest.json.
 */
abstract contract UpgradeableDeploymentAddresses is Script {
    struct DeploymentAddresses {
        address proxy;
        address admin;
        address implementation;
    }

    /// @dev ERC-1967 implementation slot:
    ///      bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @dev ERC-1967 admin slot:
    ///      bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function _getImplementation(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
    }

    function _getAdmin(address proxy) internal view returns (address) {
        return address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
    }

    /// @dev The proxy with its current admin and implementation.
    function _addresses(address proxy)
        internal
        view
        returns (DeploymentAddresses memory)
    {
        return DeploymentAddresses({
            proxy: proxy,
            admin: _getAdmin(proxy),
            implementation: _getImplementation(proxy)
        });
    }
}
