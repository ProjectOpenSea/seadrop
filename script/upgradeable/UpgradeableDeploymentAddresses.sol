// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Script } from "forge-std/Script.sol";

/**
 * @notice Shared helpers for the ERC721SeaDropUpgradeable deploy and upgrade
 *         scripts: reading the ERC-1967 slots of a proxy and reading and
 *         writing the deployment addresses JSON file.
 */
abstract contract UpgradeableDeploymentAddresses is Script {
    struct DeploymentAddresses {
        address proxy;
        address admin;
        address implementation;
    }

    /// @dev Where the scripts read and write the deployment addresses by
    ///      default, relative to the project root. The former Hardhat
    ///      scripts wrote the same file from within src-upgradeable.
    string internal constant DEFAULT_ADDRESSES_PATH =
        "src-upgradeable/deployment-addresses.json";

    /// @dev The addresses file path: DEPLOYMENT_ADDRESSES_PATH if set,
    ///      otherwise DEFAULT_ADDRESSES_PATH. The path must be allowed by
    ///      fs_permissions in foundry.toml.
    function _addressesPath() internal view returns (string memory) {
        return vm.envOr("DEPLOYMENT_ADDRESSES_PATH", DEFAULT_ADDRESSES_PATH);
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

    function _readProxy(string memory addressesPath)
        internal
        view
        returns (address)
    {
        return vm.parseJsonAddress(vm.readFile(addressesPath), ".proxy");
    }

    /**
     * @dev Read the proxy's current admin and implementation from its
     *      ERC-1967 slots and write all three addresses to `addressesPath`.
     *      forge script also prints them as the run() return value.
     */
    function _writeAddresses(string memory addressesPath, address proxy)
        internal
        returns (DeploymentAddresses memory addresses)
    {
        addresses = DeploymentAddresses({
            proxy: proxy,
            admin: _getAdmin(proxy),
            implementation: _getImplementation(proxy)
        });

        string memory objectKey = "deploymentAddresses";
        vm.serializeAddress(objectKey, "proxy", addresses.proxy);
        vm.serializeAddress(objectKey, "admin", addresses.admin);
        string memory json = vm.serializeAddress(
            objectKey,
            "implementation",
            addresses.implementation
        );
        vm.writeJson(json, addressesPath);
    }
}
