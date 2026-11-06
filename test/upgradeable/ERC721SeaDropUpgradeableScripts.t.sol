// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Test } from "forge-std/Test.sol";

import {
    ERC721SeaDropUpgradeable
} from "../../src-upgradeable/src/ERC721SeaDropUpgradeable.sol";

import {
    INonFungibleSeaDropTokenUpgradeable
} from "../../src-upgradeable/src/interfaces/INonFungibleSeaDropTokenUpgradeable.sol";

import {
    ProxyAdmin
} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";

import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {
    DeployERC721SeaDropUpgradeable
} from "../../script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol";

import {
    UpgradeERC721SeaDropUpgradeable
} from "../../script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol";

import {
    UpgradeableDeploymentAddresses
} from "../../script/upgradeable/UpgradeableDeploymentAddresses.sol";

/**
 * @notice Runs the upgradeable deploy and upgrade scripts end to end.
 *         Run with FOUNDRY_PROFILE=upgradeable forge test.
 */
contract ERC721SeaDropUpgradeableScriptsTest is Test {
    /// @dev Kept out of src-upgradeable so the test never touches a real
    ///      deployment-addresses.json. Allowed in fs_permissions.
    string internal constant ADDRESSES_PATH =
        "cache/upgradeable-deployment-addresses.test.json";

    /// @dev The allowed SeaDrop the deploy script initializes the token with.
    address internal constant SEADROP =
        0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

    bytes32 internal constant IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    address minter = makeAddr("minter");

    function setUp() public {
        vm.setEnv("DEPLOYMENT_ADDRESSES_PATH", ADDRESSES_PATH);
    }

    function _slotAddress(address proxy, bytes32 slot)
        internal
        view
        returns (address)
    {
        return address(uint160(uint256(vm.load(proxy, slot))));
    }

    /// @dev Assert the addresses file matches `expected` and the proxy's
    ///      ERC-1967 slots.
    function _assertAddresses(
        UpgradeableDeploymentAddresses.DeploymentAddresses memory expected
    ) internal view {
        string memory json = vm.readFile(ADDRESSES_PATH);
        assertEq(vm.parseJsonAddress(json, ".proxy"), expected.proxy);
        assertEq(vm.parseJsonAddress(json, ".admin"), expected.admin);
        assertEq(
            vm.parseJsonAddress(json, ".implementation"),
            expected.implementation
        );

        assertEq(_slotAddress(expected.proxy, ADMIN_SLOT), expected.admin);
        assertEq(
            _slotAddress(expected.proxy, IMPLEMENTATION_SLOT),
            expected.implementation
        );

        // The admin is the ProxyAdmin, and it sees the same implementation.
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(expected.proxy)
        );
        ProxyAdmin proxyAdmin = ProxyAdmin(expected.admin);
        assertEq(proxyAdmin.getProxyAdmin(proxy), expected.admin);
        assertEq(
            proxyAdmin.getProxyImplementation(proxy),
            expected.implementation
        );
        assertGt(expected.implementation.code.length, 0);
    }

    function testDeployInitializeAndUpgrade() public {
        // Deploy.
        UpgradeableDeploymentAddresses.DeploymentAddresses
            memory deployed = new DeployERC721SeaDropUpgradeable().run();
        _assertAddresses(deployed);

        ERC721SeaDropUpgradeable token = ERC721SeaDropUpgradeable(
            deployed.proxy
        );
        ProxyAdmin proxyAdmin = ProxyAdmin(deployed.admin);

        // initialize(name, symbol, allowedSeaDrop) ran in the proxy's
        // constructor, with the deployer as the token owner. The deployer
        // also owns the ProxyAdmin.
        assertEq(token.name(), "ERC721SeaDropUpgradeable");
        assertEq(token.symbol(), "SD");
        address deployer = token.owner();
        assertTrue(deployer != address(0));
        assertEq(proxyAdmin.owner(), deployer);

        // It cannot be initialized again.
        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize("", "", new address[](0));

        // Set state through the proxy.
        vm.startPrank(deployer);
        token.setMaxSupply(100);
        token.setBaseURI("https://example.com/");
        token.setContractURI("https://example.com/contract");
        vm.stopPrank();

        // Only the allowed SeaDrop can mint.
        vm.expectRevert(
            INonFungibleSeaDropTokenUpgradeable.OnlyAllowedSeaDrop.selector
        );
        token.mintSeaDrop(minter, 3);
        vm.prank(SEADROP);
        token.mintSeaDrop(minter, 3);

        // Upgrade.
        UpgradeableDeploymentAddresses.DeploymentAddresses
            memory upgraded = new UpgradeERC721SeaDropUpgradeable().run();
        _assertAddresses(upgraded);

        // Same proxy and admin, new implementation.
        assertEq(upgraded.proxy, deployed.proxy);
        assertEq(upgraded.admin, deployed.admin);
        assertTrue(upgraded.implementation != deployed.implementation);

        // State survives the upgrade.
        assertEq(token.name(), "ERC721SeaDropUpgradeable");
        assertEq(token.symbol(), "SD");
        assertEq(token.owner(), deployer);
        assertEq(proxyAdmin.owner(), deployer);
        assertEq(token.maxSupply(), 100);
        assertEq(token.baseURI(), "https://example.com/");
        assertEq(token.contractURI(), "https://example.com/contract");
        assertEq(token.totalSupply(), 3);
        assertEq(token.balanceOf(minter), 3);
        assertEq(token.ownerOf(1), minter);
        assertEq(token.ownerOf(3), minter);
        assertEq(token.tokenURI(1), "https://example.com/1");

        // The allowed SeaDrop survives the upgrade too.
        vm.expectRevert(
            INonFungibleSeaDropTokenUpgradeable.OnlyAllowedSeaDrop.selector
        );
        token.mintSeaDrop(minter, 2);
        vm.prank(SEADROP);
        token.mintSeaDrop(minter, 2);
        assertEq(token.totalSupply(), 5);
    }
}
