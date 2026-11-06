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
 * @notice Deploy ERC721SeaDropUpgradeable behind a transparent proxy, the
 *         layout that OpenZeppelin's hardhat-upgrades deployProxy used for this
 *         (non-UUPS) contract: an implementation, a ProxyAdmin owned by the
 *         deployer, and a TransparentUpgradeableProxy whose constructor calls
 *         initialize(name, symbol, allowedSeaDrop).
 *
 *         Returns {proxy, admin, implementation}, which forge script prints.
 *
 *         FOUNDRY_PROFILE=upgradeable forge script \
 *           script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol \
 *           --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast --verify
 */
contract DeployERC721SeaDropUpgradeable is UpgradeableDeploymentAddresses {
    string internal constant TOKEN_NAME = "ERC721SeaDropUpgradeable";
    string internal constant TOKEN_SYMBOL = "SD";

    /// @dev The canonical SeaDrop deployment.
    address internal constant SEADROP =
        0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

    function run() external returns (DeploymentAddresses memory) {
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = SEADROP;

        vm.startBroadcast();

        // initialize() can only run in a constructor context, so the bare
        // implementation cannot be initialized by anyone after deployment.
        ERC721SeaDropUpgradeable implementation = new ERC721SeaDropUpgradeable();

        ProxyAdmin proxyAdmin = new ProxyAdmin();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(implementation),
            address(proxyAdmin),
            abi.encodeCall(
                ERC721SeaDropUpgradeable.initialize,
                (TOKEN_NAME, TOKEN_SYMBOL, allowedSeaDrop)
            )
        );

        vm.stopBroadcast();

        return _addresses(address(proxy));
    }
}
