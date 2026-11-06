// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721SeaDropUpgradeable
} from "../../src-upgradeable/src/ERC721SeaDropUpgradeable.sol";

import {
    ProxyAdmin
} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {
    UpgradeableDeploymentAddresses
} from "./UpgradeableDeploymentAddresses.sol";

/**
 * @notice Upgrade the ERC721SeaDropUpgradeable proxy at PROXY_ADDRESS to a
 *         freshly deployed implementation, through the proxy's ProxyAdmin, as
 *         OpenZeppelin's hardhat-upgrades upgradeProxy did. The broadcaster
 *         must own the ProxyAdmin. Returns {proxy, admin, implementation}.
 *
 *         Unlike the Hardhat plugin, this does not validate upgrade safety or
 *         storage layout compatibility; check those before upgrading.
 *
 *         PROXY_ADDRESS=0x... FOUNDRY_PROFILE=upgradeable forge script \
 *           script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol \
 *           --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast --verify
 */
contract UpgradeERC721SeaDropUpgradeable is UpgradeableDeploymentAddresses {
    function run() external returns (DeploymentAddresses memory) {
        address proxy = vm.envAddress("PROXY_ADDRESS");

        // The admin slot holds the proxy's ProxyAdmin.
        ProxyAdmin proxyAdmin = ProxyAdmin(_getAdmin(proxy));

        vm.startBroadcast();

        ERC721SeaDropUpgradeable implementation = new ERC721SeaDropUpgradeable();

        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(proxy)), address(implementation)
        );

        vm.stopBroadcast();

        return _addresses(proxy);
    }
}
