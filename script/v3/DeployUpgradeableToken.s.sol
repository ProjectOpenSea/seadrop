// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import {
    UpgradeableDeploymentAddresses
} from "../upgradeable/UpgradeableDeploymentAddresses.sol";
import { ERC721SeaDropV3 } from "seadrop/v3/ERC721SeaDropV3.sol";
import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";
import {
    ProxyAdmin
} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import {
    TransparentUpgradeableProxy
} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/// @notice Deploy a v3 token behind a transparent proxy. The broadcaster
///         owns the dedicated ProxyAdmin and deploys both the implementation
///         and proxy so the token's factory-only initializer accepts the call.
contract DeployUpgradeableToken is UpgradeableDeploymentAddresses {
    function deployERC721(
        address owner,
        address minter,
        address conduit,
        string calldata name,
        string calldata symbol
    ) external returns (DeploymentAddresses memory) {
        _validate(owner, minter);
        vm.startBroadcast();
        address implementation = address(new ERC721SeaDropV3(conduit));
        return _deploy(
            implementation,
            abi.encodeCall(
                ERC721SeaDropV3.initialize, (owner, minter, name, symbol)
            )
        );
    }

    function deployERC1155(address owner, address minter, address conduit)
        external
        returns (DeploymentAddresses memory)
    {
        _validate(owner, minter);
        vm.startBroadcast();
        address implementation = address(new ERC1155SeaDropV3(conduit));
        return _deploy(
            implementation,
            abi.encodeCall(ERC1155SeaDropV3.initialize, (owner, minter))
        );
    }

    function _validate(address owner, address minter) private view {
        require(owner != address(0), "Missing token owner");
        require(minter.code.length != 0, "Missing deployed minter");
    }

    function _deploy(address implementation, bytes memory init)
        private
        returns (DeploymentAddresses memory)
    {
        ProxyAdmin admin = new ProxyAdmin();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            implementation, address(admin), init
        );
        vm.stopBroadcast();
        return _addresses(address(proxy));
    }
}
