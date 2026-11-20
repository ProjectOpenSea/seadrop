// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropTokensV3Test } from "./SeaDropTokensV3.t.sol";
import { DeployUpgradeableToken } from "script/v3/DeployUpgradeableToken.s.sol";
import {
    UpgradeableDeploymentAddresses
} from "script/upgradeable/UpgradeableDeploymentAddresses.sol";
import { ERC721SeaDropV3 } from "seadrop/v3/ERC721SeaDropV3.sol";
import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";
import {
    ProxyAdmin
} from "openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract SeaDropUpgradeableTokensTest is SeaDropTokensV3Test {
    ProxyAdmin private admin721;
    ProxyAdmin private admin1155;

    function _deployTokens(address conduit) internal override {
        DeployUpgradeableToken script = new DeployUpgradeableToken();
        UpgradeableDeploymentAddresses.DeploymentAddresses memory deployed =
            script.deployERC721(
                address(this), address(minter), conduit, "Test", "TEST"
            );
        token721 = ERC721SeaDropV3(deployed.proxy);
        admin721 = ProxyAdmin(deployed.admin);
        deployed = script.deployERC1155(address(this), address(minter), conduit);
        token1155 = ERC1155SeaDropV3(deployed.proxy);
        admin1155 = ProxyAdmin(deployed.admin);
    }

    function test_upgradePreservesStateAndMinting() public {
        minter.ownerMint(address(token721), 0, alice, 1);
        minter.ownerMint(address(token1155), ID_1155, alice, 3);
        token721.setBaseURI("ipfs://base/");
        token1155.setURI("ipfs://{id}");
        vm.startPrank(alice);
        token721.approve(bob, 1);
        token1155.setApprovalForAll(CONDUIT, false);
        vm.stopPrank();

        _upgrade(
            address(token721), admin721, address(new ERC721SeaDropV3(CONDUIT))
        );
        _upgrade(
            address(token1155),
            admin1155,
            address(new ERC1155SeaDropV3(CONDUIT))
        );

        assertEq(token721.owner(), address(this));
        assertEq(token1155.owner(), address(this));
        assertEq(token721.tokenURI(1), "ipfs://base/1");
        assertEq(token721.ownerOf(1), alice);
        assertEq(token721.getApproved(1), bob);
        assertEq(token1155.uri(ID_1155), "ipfs://{id}");
        assertFalse(token1155.isApprovedForAll(alice, CONDUIT));
        assertEq(token1155.balanceOf(alice, ID_1155), 3);
        minter.ownerMint(address(token721), 0, bob, 1);
        minter.ownerMint(address(token1155), ID_1155, bob, 1);
        assertEq(token721.ownerOf(2), bob);
        assertEq(token721.maxSupply(), MAX_SUPPLY);
        (uint256 minted, uint256 cap) = token1155.mintStats(ID_1155);
        assertEq(minted, 4);
        assertEq(cap, MAX_SUPPLY);
    }

    function _upgrade(address token, ProxyAdmin admin, address implementation)
        private
    {
        ITransparentUpgradeableProxy proxy =
            ITransparentUpgradeableProxy(payable(token));
        assertTrue(admin.getProxyImplementation(proxy) != implementation);
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        admin.upgrade(proxy, implementation);
        vm.prank(admin.owner());
        admin.upgrade(proxy, implementation);
        assertEq(admin.getProxyImplementation(proxy), implementation);
    }
}
