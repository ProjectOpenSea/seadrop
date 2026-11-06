// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop1155Test } from "./utils/SeaDrop1155Test.sol";

import {
    ERC1155SeaDropWithBatchMint
} from "seadrop/test/ERC1155SeaDropWithBatchMint.sol";

import {
    IERC1155ContractMetadata
} from "seadrop/interfaces/IERC1155ContractMetadata.sol";

import {
    ISeaDropTokenContractMetadata
} from "seadrop/interfaces/ISeaDropTokenContractMetadata.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import { ERC2981 } from "solady/src/tokens/ERC2981.sol";

/// @dev Owner-only metadata, supply, royalty and provenance settings.
contract ERC1155ContractMetadataTest is SeaDrop1155Test {
    // Events declared locally so they can be emitted for vm.expectEmit.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event ContractURIUpdated(string newContractURI);
    event ProvenanceHashUpdated(bytes32 previousHash, bytes32 newHash);
    event RoyaltyInfoUpdated(address receiver, uint256 basisPoints);
    event MaxSupplyUpdated(uint256 tokenId, uint256 newMaxSupply);
    event URI(string value, uint256 indexed id);

    /// @dev The token owner (the deployer).
    address owner;

    function setUp() public override {
        super.setUp();
        token = _deployToken();
        owner = address(this);
        // `bob` (from SeaDropTest) is a non-owner.
    }

    function testNameAndSymbol() public view {
        assertEq(token.name(), "Test1155");
        assertEq(token.symbol(), "T1155");
    }

    function testOnlyOwnerCanSetBaseURI() public {
        assertEq(token.baseURI(), "");

        vm.prank(bob);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "");

        // It should emit BatchMetadataUpdate.
        token.setMaxSupply(1, 1);
        _mintTokens(owner, 1, 1);
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(0, type(uint256).max);
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "http://example.com");
    }

    function testOnlyOwnerCanSetContractURI() public {
        assertEq(token.contractURI(), "");

        vm.prank(bob);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setContractURI("http://example.com");
        assertEq(token.contractURI(), "");

        vm.expectEmit(true, true, true, true, address(token));
        emit ContractURIUpdated("http://example.com");
        token.setContractURI("http://example.com");
        assertEq(token.contractURI(), "http://example.com");
    }

    function testOnlyOwnerCanSetMaxSupply() public {
        for (uint256 tokenId = 0; tokenId < 3; tokenId++) {
            assertEq(token.maxSupply(tokenId), 0);

            vm.prank(bob);
            vm.expectRevert(Ownable.Unauthorized.selector);
            token.setMaxSupply(0, 10);
            assertEq(token.maxSupply(tokenId), 0);

            vm.expectEmit(true, true, true, true, address(token));
            emit MaxSupplyUpdated(tokenId, 25);
            token.setMaxSupply(tokenId, 25);
            assertEq(token.maxSupply(tokenId), 25);
        }
    }

    function testCannotSetMaxSupplyOverUint64() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.CannotExceedMaxSupplyOfUint64
                .selector,
                2 ** 70
            )
        );
        token.setMaxSupply(0, 2 ** 70);
    }

    function testCannotSetMaxSupplyUnderTotalMinted() public {
        token.setMaxSupply(1, 3);
        _mintTokens(owner, 1, 3);
        assertEq(token.totalSupply(1), 3);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.NewMaxSupplyCannotBeLessThenTotalMinted
                    .selector,
                2,
                3
            )
        );
        token.setMaxSupply(1, 2);
    }

    function testOnlyOwnerCanEmitBatchMetadataUpdate() public {
        vm.prank(bob);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.emitBatchMetadataUpdate(5, 10);

        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(5, 10);
        token.emitBatchMetadataUpdate(5, 10);

        // Should emit the ERC-1155 URI event if only one token id.
        vm.expectEmit(true, true, true, true, address(token));
        emit URI("", 0);
        token.emitBatchMetadataUpdate(0, 0);
        vm.expectEmit(true, true, true, true, address(token));
        emit URI("", 7);
        token.emitBatchMetadataUpdate(7, 7);
    }

    function testOnlyOwnerCanSetRoyalties() public {
        (address receiver, uint256 royaltyAmount) = token.royaltyInfo(0, 100);
        assertEq(receiver, address(0));
        assertEq(royaltyAmount, 0);

        vm.prank(bob);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setDefaultRoyalty(owner, 100);

        vm.expectRevert(ERC2981.RoyaltyOverflow.selector);
        token.setDefaultRoyalty(owner, 10_001);
        vm.expectRevert(ERC2981.RoyaltyReceiverIsZeroAddress.selector);
        token.setDefaultRoyalty(address(0), 200);

        vm.expectEmit(true, true, true, true, address(token));
        emit RoyaltyInfoUpdated(bob, 100);
        token.setDefaultRoyalty(bob, 100);
        vm.expectEmit(true, true, true, true, address(token));
        emit RoyaltyInfoUpdated(bob, 500);
        token.setDefaultRoyalty(bob, 500);

        (receiver, royaltyAmount) = token.royaltyInfo(0, 100);
        assertEq(receiver, bob);
        assertEq(royaltyAmount, 5);
        (receiver, royaltyAmount) = token.royaltyInfo(1, 100_000);
        assertEq(receiver, bob);
        assertEq(royaltyAmount, 5000);

        // Interface id for EIP-2981 is 0x2a55205a.
        assertTrue(token.supportsInterface(0x2a55205a));
    }

    function testOnlyOwnerCanSetProvenanceHash() public {
        assertEq(token.provenanceHash(), bytes32(0));

        bytes32 defaultProvenanceHash = bytes32(0);
        bytes32 firstProvenanceHash = bytes32(
            0x1111111111111111111111111111111111111111111111111111111111111111
        );
        bytes32 secondProvenanceHash = bytes32(
            0x2222222222222222222222222222222222222222222222222222222222222222
        );

        vm.prank(bob);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setProvenanceHash(firstProvenanceHash);

        vm.expectEmit(true, true, true, true, address(token));
        emit ProvenanceHashUpdated(defaultProvenanceHash, firstProvenanceHash);
        token.setProvenanceHash(firstProvenanceHash);

        // Provenance hash should not be updatable after it has already
        // been set.
        vm.expectRevert(
            ISeaDropTokenContractMetadata.ProvenanceHashCannotBeSetAfterAlreadyBeingSet
                .selector
        );
        token.setProvenanceHash(secondProvenanceHash);

        assertEq(token.provenanceHash(), firstProvenanceHash);
    }

    function testIncrementsCountsOnBatchMint() public {
        // Deploy a token exposing batchMint, with a zero configurer.
        ERC1155SeaDropWithBatchMint batchToken = new ERC1155SeaDropWithBatchMint(
            address(0), address(consideration), "Test1155", "T1155"
        );
        batchToken.setMaxSupply(0, 1);
        batchToken.setMaxSupply(1, 1);

        assertEq(batchToken.totalMinted(0), 0);
        assertEq(batchToken.totalMinted(1), 0);

        batchToken.batchMint(owner, _uints(0, 1), _uints(1, 1), "");

        assertEq(batchToken.totalMinted(0), 1);
        assertEq(batchToken.totalMinted(1), 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155ContractMetadata.MintExceedsMaxSupply.selector, 2, 1
            )
        );
        batchToken.batchMint(owner, _uints(0, 1), _uints(1, 1), "");

        assertEq(batchToken.totalMinted(0), 1);
        assertEq(batchToken.totalMinted(1), 1);
    }
}
