// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { SeaDropV3TestHelper } from "./utils/SeaDropV3TestHelper.sol";

import { ISeaDropTokenV3 } from "seadrop/v3/interfaces/ISeaDropTokenV3.sol";

import { SeaDropTokenV3Base } from "seadrop/v3/SeaDropTokenV3Base.sol";

import { ERC721SeaDropV3 } from "seadrop/v3/ERC721SeaDropV3.sol";

import { ERC1155SeaDropV3 } from "seadrop/v3/ERC1155SeaDropV3.sol";

import { SeaDropTokenFactory } from "seadrop/v3/SeaDropTokenFactory.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

contract SeaDropTokensV3Test is SeaDropV3TestHelper {
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event ContractURIUpdated();
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function test_ERC721_setBaseURI_emits4906BeforeFirstMint() public {
        assertEq(token721.totalSupply(), 0);

        vm.expectEmit(address(token721));
        emit BatchMetadataUpdate(0, type(uint256).max);
        token721.setBaseURI("ipfs://base/");

        minter.ownerMint(address(token721), 0, alice, 1);
        assertEq(token721.tokenURI(1), "ipfs://base/1");
    }

    function test_ERC721_setContractURI_emits7572() public {
        vm.expectEmit(address(token721));
        emit ContractURIUpdated();
        token721.setContractURI("ipfs://contract");
        assertEq(token721.contractURI(), "ipfs://contract");
    }

    function test_ERC1155_setURI_emits4906() public {
        vm.expectEmit(address(token1155));
        emit BatchMetadataUpdate(0, type(uint256).max);
        token1155.setURI("ipfs://{id}");
        assertEq(token1155.uri(ID_1155), "ipfs://{id}");
    }

    function test_ERC1155_setContractURI_emits7572() public {
        vm.expectEmit(address(token1155));
        emit ContractURIUpdated();
        token1155.setContractURI("ipfs://contract");
        assertEq(token1155.contractURI(), "ipfs://contract");
    }

    function test_supportsInterface() public view {
        bytes4 v3 = type(ISeaDropTokenV3).interfaceId;
        assertTrue(token721.supportsInterface(v3));
        assertTrue(token721.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(token721.supportsInterface(0x49064906)); // ERC-4906
        assertTrue(token1155.supportsInterface(v3));
        assertTrue(token1155.supportsInterface(0xd9b67a26)); // ERC-1155
        // ERC-4906 extends ERC-721, so the ERC-1155 token doesn't claim it
        assertFalse(token1155.supportsInterface(0x49064906));
        assertFalse(token721.supportsInterface(0xffffffff));
    }

    function test_revert_mintSeaDrop_notAllowedMinter() public {
        bytes memory err = abi.encodeWithSelector(
            SeaDropTokenV3Base.OnlyAllowedMinter.selector, alice
        );
        vm.startPrank(alice);
        vm.expectRevert(err);
        token721.mintSeaDrop(alice, 0, 1);
        vm.expectRevert(err);
        token1155.mintSeaDrop(alice, ID_1155, 1);
        vm.stopPrank();
    }

    function test_setAllowedMinter() public {
        token721.setAllowedMinter(address(minter), false);
        assertFalse(token721.allowedMinters(address(minter)));

        vm.expectRevert(
            abi.encodeWithSelector(
                SeaDropTokenV3Base.OnlyAllowedMinter.selector, address(minter)
            )
        );
        minter.ownerMint(address(token721), 0, alice, 1);
    }

    function test_mintStats() public {
        minter.ownerMint(address(token721), 0, alice, 3);
        (uint256 totalMinted, uint256 maxSupply) = token721.mintStats(42);
        assertEq(totalMinted, 3);
        assertEq(maxSupply, MAX_SUPPLY);

        minter.ownerMint(address(token1155), ID_1155, alice, 4);
        (totalMinted, maxSupply) = token1155.mintStats(ID_1155);
        assertEq(totalMinted, 4);
        assertEq(maxSupply, MAX_SUPPLY);
        (totalMinted, maxSupply) = token1155.mintStats(ID_1155 + 1);
        assertEq(totalMinted, 0);
        assertEq(maxSupply, 0);
    }

    function test_revert_setMaxSupply_belowMinted() public {
        minter.ownerMint(address(token721), 0, alice, 3);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC721SeaDropV3.MaxSupplyBelowTotalMinted.selector, 2, 3
            )
        );
        token721.setMaxSupply(2);

        minter.ownerMint(address(token1155), ID_1155, alice, 3);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155SeaDropV3.MaxSupplyBelowTotalMinted.selector, 2, 3
            )
        );
        token1155.setMaxSupply(ID_1155, 2);
    }

    function test_revert_ownerOnlySetters() public {
        vm.startPrank(alice);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token721.setMaxSupply(1);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token721.setBaseURI("");
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token721.setContractURI("");
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token721.setAllowedMinter(alice, true);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token1155.setMaxSupply(1, 1);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token1155.setURI("");
        vm.stopPrank();
    }

    function test_renounceCancelsPendingOwner() public {
        token721.transferOwnership(alice);
        token721.renounceOwnership();

        vm.prank(alice);
        vm.expectRevert(TwoStepOwnable.NotNextOwner.selector);
        token721.acceptOwnership();
        assertEq(token721.owner(), address(0));
    }

    function test_ERC721_conduitIsPreapprovedUntilRevoked() public {
        minter.ownerMint(address(token721), 0, alice, 1);
        assertEq(token721.preapprovedConduit(), CONDUIT);
        assertTrue(token721.isApprovedForAll(alice, CONDUIT));
        assertFalse(token721.isApprovedForAll(alice, bob));

        // The conduit moves alice's token without her approving it
        vm.prank(CONDUIT);
        token721.transferFrom(alice, bob, 1);
        assertEq(token721.ownerOf(1), bob);

        // Bob revokes the preapproval, and the conduit can't move it
        vm.expectEmit(address(token721));
        emit ApprovalForAll(bob, CONDUIT, false);
        vm.prank(bob);
        token721.setApprovalForAll(CONDUIT, false);
        assertFalse(token721.isApprovedForAll(bob, CONDUIT));
        vm.expectRevert();
        vm.prank(CONDUIT);
        token721.transferFrom(bob, alice, 1);

        // Restoring it works the same way
        vm.prank(bob);
        token721.setApprovalForAll(CONDUIT, true);
        assertTrue(token721.isApprovedForAll(bob, CONDUIT));
        vm.prank(CONDUIT);
        token721.transferFrom(bob, alice, 1);
        assertEq(token721.ownerOf(1), alice);
    }

    function test_ERC1155_conduitIsPreapprovedUntilRevoked() public {
        minter.ownerMint(address(token1155), ID_1155, alice, 3);
        assertEq(token1155.preapprovedConduit(), CONDUIT);
        assertTrue(token1155.isApprovedForAll(alice, CONDUIT));
        assertFalse(token1155.isApprovedForAll(alice, bob));

        vm.prank(CONDUIT);
        token1155.safeTransferFrom(alice, bob, ID_1155, 2, "");
        assertEq(token1155.balanceOf(bob, ID_1155), 2);

        vm.expectEmit(address(token1155));
        emit ApprovalForAll(alice, CONDUIT, false);
        vm.prank(alice);
        token1155.setApprovalForAll(CONDUIT, false);
        assertFalse(token1155.isApprovedForAll(alice, CONDUIT));
        vm.expectRevert();
        vm.prank(CONDUIT);
        token1155.safeTransferFrom(alice, bob, ID_1155, 1, "");

        // Batch transfers check the same approval
        vm.prank(alice);
        token1155.setApprovalForAll(CONDUIT, true);
        uint256[] memory ids = new uint256[](1);
        ids[0] = ID_1155;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        vm.prank(CONDUIT);
        token1155.safeBatchTransferFrom(alice, bob, ids, amounts, "");
        assertEq(token1155.balanceOf(bob, ID_1155), 3);
    }

    function test_noConduitPreapprovesNothing() public {
        SeaDropTokenFactory noConduitFactory =
            new SeaDropTokenFactory(address(minter), address(0));
        minter.setTokenFactory(address(noConduitFactory), true);
        ERC721SeaDropV3 token = ERC721SeaDropV3(
            noConduitFactory.createERC721("Test", "TEST", bytes32(0))
        );
        assertEq(token.preapprovedConduit(), address(0));
        assertFalse(token.isApprovedForAll(alice, address(0)));
        assertFalse(token.isApprovedForAll(alice, CONDUIT));

        ERC1155SeaDropV3 token1155NoConduit =
            ERC1155SeaDropV3(noConduitFactory.createERC1155(bytes32(0)));
        assertFalse(token1155NoConduit.isApprovedForAll(alice, address(0)));
        assertFalse(token1155NoConduit.isApprovedForAll(alice, CONDUIT));
    }

    function test_otherOperatorsUseTheStandardApproval() public {
        vm.prank(alice);
        token721.setApprovalForAll(bob, true);
        assertTrue(token721.isApprovedForAll(alice, bob));
        vm.prank(alice);
        token1155.setApprovalForAll(bob, true);
        assertTrue(token1155.isApprovedForAll(alice, bob));
        // Revoking the conduit leaves other approvals alone
        vm.prank(alice);
        token721.setApprovalForAll(CONDUIT, false);
        assertTrue(token721.isApprovedForAll(alice, bob));
    }
}
