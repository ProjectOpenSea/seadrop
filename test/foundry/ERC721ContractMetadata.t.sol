// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721MintHelpers } from "./utils/SeaDrop721MintHelpers.sol";

import { ERC721SeaDrop } from "seadrop/ERC721SeaDrop.sol";

import {
    ISeaDropTokenContractMetadata
} from "seadrop/interfaces/ISeaDropTokenContractMetadata.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

import { ERC2981 } from "solady/src/tokens/ERC2981.sol";

import { Vm } from "forge-std/Vm.sol";

/**
 * @dev Port of test/ERC721ContractMetadata.spec.ts.
 *      The test contract deploys the token, so it plays the spec's `owner`.
 */
contract ERC721ContractMetadataTest is SeaDrop721MintHelpers {
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);
    event ContractURIUpdated(string newContractURI);
    event ProvenanceHashUpdated(bytes32 previousHash, bytes32 newHash);
    event RoyaltyInfoUpdated(address receiver, uint256 basisPoints);
    event MaxSupplyUpdated(uint256 newMaxSupply);

    function setUp() public override {
        super.setUp();
        token = new ERC721SeaDrop(
            address(configurer), allowedSeaport, "Test721", "T721"
        );
    }

    /// @dev "Should only let the owner set and get the base URI"
    function testOnlyOwnerCanSetBaseURI() public {
        assertEq(token.baseURI(), "");

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(bob);
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "");

        // It should not emit BatchMetadataUpdate when totalSupply is 0.
        vm.recordLogs();
        token.setBaseURI("http://example.com");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            assertTrue(
                logs[i].topics.length == 0
                    || logs[i].topics[0] != BatchMetadataUpdate.selector,
                "should not emit BatchMetadataUpdate"
            );
        }

        // It should emit BatchMetadataUpdate when totalSupply is above 0.
        token.setMaxSupply(1);
        _mintTokens(address(this), 1);
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, token.totalSupply());
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "http://example.com");
    }

    /// @dev "Should only let the owner set and get the contract URI"
    function testOnlyOwnerCanSetContractURI() public {
        assertEq(token.contractURI(), "");

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(bob);
        token.setContractURI("http://example.com");
        assertEq(token.contractURI(), "");

        vm.expectEmit(true, true, true, true, address(token));
        emit ContractURIUpdated("http://example.com");
        token.setContractURI("http://example.com");
        assertEq(token.contractURI(), "http://example.com");
    }

    /// @dev "Should only let the owner set and get the max supply"
    function testOnlyOwnerCanSetMaxSupply() public {
        assertEq(token.maxSupply(), 0);

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(bob);
        token.setMaxSupply(10);
        assertEq(token.maxSupply(), 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit MaxSupplyUpdated(25);
        token.setMaxSupply(25);
        assertEq(token.maxSupply(), 25);
    }

    /// @dev "Should not let the owner set the max supply over 2**64"
    function testMaxSupplyCannotExceedUint64() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.CannotExceedMaxSupplyOfUint64
                .selector,
                2 ** 70
            )
        );
        token.setMaxSupply(2 ** 70);
    }

    /// @dev "Should not let the owner set the max supply over the totalMinted"
    function testMaxSupplyCannotBeLessThanTotalMinted() public {
        token.setMaxSupply(3);
        _mintTokens(address(this), 3);
        assertEq(token.totalSupply(), 3);

        vm.expectRevert(
            abi.encodeWithSelector(
                ISeaDropTokenContractMetadata.NewMaxSupplyCannotBeLessThenTotalMinted
                    .selector,
                2,
                3
            )
        );
        token.setMaxSupply(2);
    }

    /// @dev "Should only let the owner notify update of batch token URIs"
    function testOnlyOwnerCanEmitBatchMetadataUpdate() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(bob);
        token.emitBatchMetadataUpdate(5, 10);

        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(5, 10);
        token.emitBatchMetadataUpdate(5, 10);
    }

    /// @dev "Should only let the owner update the royalties address and
    ///      basis points"
    function testOnlyOwnerCanSetDefaultRoyalty() public {
        (address receiver, uint256 amount) = token.royaltyInfo(0, 100);
        assertEq(receiver, address(0));
        assertEq(amount, 0);

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(bob);
        token.setDefaultRoyalty(address(this), 100);

        vm.expectRevert(ERC2981.RoyaltyOverflow.selector);
        token.setDefaultRoyalty(address(this), 10_001);
        vm.expectRevert(ERC2981.RoyaltyReceiverIsZeroAddress.selector);
        token.setDefaultRoyalty(address(0), 200);

        vm.expectEmit(true, true, true, true, address(token));
        emit RoyaltyInfoUpdated(bob, 100);
        token.setDefaultRoyalty(bob, 100);
        vm.expectEmit(true, true, true, true, address(token));
        emit RoyaltyInfoUpdated(bob, 500);
        token.setDefaultRoyalty(bob, 500);

        (receiver, amount) = token.royaltyInfo(0, 100);
        assertEq(receiver, bob);
        assertEq(amount, 5);
        (receiver, amount) = token.royaltyInfo(1, 100_000);
        assertEq(receiver, bob);
        assertEq(amount, 5000);

        // The interface id for EIP-2981 is 0x2a55205a.
        assertTrue(token.supportsInterface(0x2a55205a));
    }

    /// @dev "Should return the correct tokenURI based on baseURI's last
    ///      character"
    function testTokenURIDependsOnBaseURILastCharacter() public {
        token.setMaxSupply(2);
        _mintTokens(address(this), 2);

        // Revert on nonexistent token.
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        token.tokenURI(99);

        // If the baseURI is empty then the tokenURI should be empty.
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, 2);
        token.setBaseURI("");
        assertEq(token.baseURI(), "");
        assertEq(token.tokenURI(1), "");
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        token.tokenURI(15);

        // If the baseURI ends with "/" then the tokenURI should be
        // baseURI + tokenId.
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, 2);
        token.setBaseURI("http://example.com/");
        assertEq(token.baseURI(), "http://example.com/");
        assertEq(token.tokenURI(1), "http://example.com/1");
        assertEq(token.tokenURI(2), "http://example.com/2");

        // If the baseURI does not end with "/" then the tokenURI should just
        // be baseURI.
        vm.expectEmit(true, true, true, true, address(token));
        emit BatchMetadataUpdate(1, 2);
        token.setBaseURI("http://example.com");
        assertEq(token.baseURI(), "http://example.com");
        assertEq(token.tokenURI(1), "http://example.com");
        assertEq(token.tokenURI(2), "http://example.com");
    }

    /// @dev "Should only let the owner set the provenance hash"
    function testOnlyOwnerCanSetProvenanceHash() public {
        assertEq(token.provenanceHash(), bytes32(0));

        bytes32 defaultProvenanceHash = bytes32(0);
        bytes32 firstProvenanceHash = bytes32(
            0x1111111111111111111111111111111111111111111111111111111111111111
        );
        bytes32 secondProvenanceHash = bytes32(
            0x2222222222222222222222222222222222222222222222222222222222222222
        );

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(bob);
        token.setProvenanceHash(firstProvenanceHash);

        vm.expectEmit(true, true, true, true, address(token));
        emit ProvenanceHashUpdated(defaultProvenanceHash, firstProvenanceHash);
        token.setProvenanceHash(firstProvenanceHash);

        // The provenance hash should not be updatable after the first token
        // has minted.
        token.setMaxSupply(1);
        _mintTokens(address(this), 1);

        vm.expectRevert(
            ISeaDropTokenContractMetadata.ProvenanceHashCannotBeSetAfterMintStarted
                .selector
        );
        token.setProvenanceHash(secondProvenanceHash);

        assertEq(token.provenanceHash(), firstProvenanceHash);
    }

    /// @dev "Should revert on unsupported function selector"
    function testRevertsOnUnsupportedFunctionSelector() public {
        (bool success, bytes memory returnData) =
            address(token).call{ gas: 50_000 }(hex"12345678");
        assertFalse(success);
        assertEq(
            returnData,
            abi.encodeWithSelector(
                UnsupportedFunctionSelector.selector, bytes4(0x12345678)
            )
        );
    }
}
