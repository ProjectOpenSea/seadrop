// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Vm } from "forge-std/Vm.sol";

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    ISeaDropTokenContractMetadata
} from "seadrop/interfaces/ISeaDropTokenContractMetadata.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

contract ERC721ContractMetadataTest is TestHelper {
    address minter = makeAddr("minter");

    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event ContractURIUpdated(string newContractURI);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event RoyaltyInfoUpdated(address receiver, uint256 bps);

    function setUp() public {
        // Deploy the ERC721SeaDrop token. The test contract is the owner.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        token = _newToken("", "", allowedSeaDrop);

        token.setMaxSupply(5);
    }

    /// @dev Mint `quantity` tokens to the owner (this contract) as SeaDrop.
    function _mintToOwner(uint256 quantity) internal {
        vm.prank(address(seadrop));
        token.mintSeaDrop(address(this), quantity);
    }

    function testSetBaseURI_onlyOwner() public {
        assertEq(token.baseURI(), "");

        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "");

        // It should not emit BatchMetadataUpdate when totalSupply is 0.
        vm.recordLogs();
        token.setBaseURI("http://example.com");
        _assertNotEmitted(address(token), BatchMetadataUpdate.selector);

        // It should emit BatchMetadataUpdate when totalSupply is
        // greater than 0.
        _mintToOwner(2);
        uint256 totalSupply = token.totalSupply();
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, totalSupply);
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "http://example.com");
    }

    function testSetContractURI_onlyOwner() public {
        assertEq(token.contractURI(), "");

        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.setContractURI("http://example.com");
        assertEq(token.contractURI(), "");

        vm.expectEmit(true, true, true, true, address(token));
        emit ContractURIUpdated("http://example.com");
        token.setContractURI("http://example.com");
        assertEq(token.contractURI(), "http://example.com");
    }

    function testSetMaxSupply_onlyOwner() public {
        assertEq(token.maxSupply(), 5);

        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.setMaxSupply(10);
        assertEq(token.maxSupply(), 5);

        vm.expectEmit(true, true, true, true, address(token));
        emit MaxSupplyUpdated(25);
        token.setMaxSupply(25);
        assertEq(token.maxSupply(), 25);
    }

    function testSetMaxSupply_cannotExceedUint64() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.CannotExceedMaxSupplyOfUint64
                .selector,
                2 ** 70
            )
        );
        token.setMaxSupply(2 ** 70);
    }

    function testSetMaxSupply_cannotBeLessThanTotalMinted() public {
        token.setMaxSupply(25);
        _mintToOwner(2);

        assertEq(token.maxSupply(), 25);
        assertEq(token.totalSupply(), 2);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.NewMaxSupplyCannotBeLessThenTotalMinted
                    .selector,
                1,
                2
            )
        );
        token.setMaxSupply(1);
    }

    function testEmitBatchMetadataUpdate_onlyOwner() public {
        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.emitBatchMetadataUpdate(5, 10);

        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(5, 10);
        token.emitBatchMetadataUpdate(5, 10);
    }

    function testSetRoyaltyInfo_onlyOwner() public {
        assertEq(token.royaltyAddress(), address(0));
        assertEq(token.royaltyBasisPoints(), 0);

        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        token.setRoyaltyInfo(
            ISeaDropTokenContractMetadata.RoyaltyInfo(address(this), 100)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.InvalidRoyaltyBasisPoints
                .selector,
                10_001
            )
        );
        token.setRoyaltyInfo(
            ISeaDropTokenContractMetadata.RoyaltyInfo(address(this), 10_001)
        );

        vm.expectRevert(
            ISeaDropTokenContractMetadata.RoyaltyAddressCannotBeZeroAddress
                .selector
        );
        token.setRoyaltyInfo(
            ISeaDropTokenContractMetadata.RoyaltyInfo(address(0), 200)
        );

        vm.expectEmit(true, true, true, true, address(token));
        emit RoyaltyInfoUpdated(minter, 100);
        token.setRoyaltyInfo(
            ISeaDropTokenContractMetadata.RoyaltyInfo(minter, 100)
        );

        // 5%
        vm.expectEmit(true, true, true, true, address(token));
        emit RoyaltyInfoUpdated(minter, 500);
        token.setRoyaltyInfo(
            ISeaDropTokenContractMetadata.RoyaltyInfo(minter, 500)
        );

        assertEq(token.royaltyAddress(), minter);
        assertEq(token.royaltyBasisPoints(), 500);

        (address receiver, uint256 royaltyAmount) =
            token.royaltyInfo(1, 100_000);
        assertEq(receiver, minter);
        assertEq(royaltyAmount, 5000);

        // 0x2a55205a is the interface id for EIP-2981.
        assertTrue(token.supportsInterface(0x2a55205a));
    }

    function testTokenURI_dependsOnBaseURILastCharacter() public {
        // State left by the earlier cases: two tokens minted and the base URI
        // set without a trailing slash.
        _mintToOwner(2);
        token.setBaseURI("http://example.com");

        // Revert on nonexistent token.
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        token.tokenURI(100000);

        // If the baseURI is empty then the tokenURI should be empty.
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, 2);
        token.setBaseURI("");
        assertEq(token.baseURI(), "");
        assertEq(token.tokenURI(1), "");

        // If the baseURI ends with "/" then the tokenURI should be
        // baseURI + tokenId.
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, 2);
        token.setBaseURI("http://example.com/");
        assertEq(token.baseURI(), "http://example.com/");
        assertEq(token.tokenURI(1), "http://example.com/1");
        assertEq(token.tokenURI(2), "http://example.com/2");

        // If the baseURI does not end with "/" then the tokenURI should
        // just be baseURI.
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, 2);
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "http://example.com");
        assertEq(token.tokenURI(1), "http://example.com");
        assertEq(token.tokenURI(2), "http://example.com");
    }

    /// @dev Assert that no log with `topic0` was emitted by `emitter` since
    ///      `vm.recordLogs()` was called.
    function _assertNotEmitted(address emitter, bytes32 topic0) internal view {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            bool matches = logs[i].emitter == emitter
                && logs[i].topics.length != 0 && logs[i].topics[0] == topic0;
            assertFalse(matches, "unexpected event emitted");
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        public
        pure
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}
