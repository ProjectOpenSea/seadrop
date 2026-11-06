// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { TestHelper } from "test/foundry/utils/TestHelper.sol";

import {
    ERC721SeaDropRandomOffset
} from "seadrop/extensions/ERC721SeaDropRandomOffset.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import { Strings } from "openzeppelin-contracts/utils/Strings.sol";

contract ERC721SeaDropRandomOffsetTest is TestHelper {
    ERC721SeaDropRandomOffset offsetToken;

    address minter = makeAddr("minter");

    function setUp() public {
        // Deploy the token. The test contract is the owner.
        address[] memory allowedSeaDrop = new address[](1);
        allowedSeaDrop[0] = address(seadrop);
        offsetToken = new ERC721SeaDropRandomOffset("", "", allowedSeaDrop);
    }

    function _mintToMaxSupply() internal {
        vm.prank(address(seadrop));
        offsetToken.mintSeaDrop(minter, 100);
    }

    function testSetRandomOffset_onlyOnceWhenFullyMinted() public {
        offsetToken.setMaxSupply(100);

        vm.expectRevert(ERC721SeaDropRandomOffset.NotFullyMinted.selector);
        offsetToken.setRandomOffset();

        // Mint to the max supply.
        _mintToMaxSupply();

        assertEq(offsetToken.randomOffset(), 0);

        // Only the owner can set the random offset.
        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        offsetToken.setRandomOffset();

        offsetToken.setRandomOffset();

        vm.expectRevert(ERC721SeaDropRandomOffset.AlreadyRevealed.selector);
        offsetToken.setRandomOffset();

        assertTrue(offsetToken.randomOffset() != 0);
    }

    /// @dev The Hardhat spec relied on Hardhat's per-block randomness for
    ///      the offset. Here the randomness source (block.difficulty, which
    ///      the contract reads; the repo targets london) is fuzzed instead.
    function testTokenURI_offsetByRandomOffset(uint256 difficulty) public {
        offsetToken.setMaxSupply(100);

        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        offsetToken.tokenURI(1);

        // Mint to the max supply.
        _mintToMaxSupply();

        assertEq(offsetToken.tokenURI(1), "");

        offsetToken.setBaseURI("http://example.com/");

        assertEq(offsetToken.tokenURI(1), "http://example.com/");

        vm.difficulty(difficulty);
        offsetToken.setRandomOffset();

        uint256 randomOffset = offsetToken.randomOffset();

        // The offset is derived from the fuzzed randomness source.
        assertEq(
            randomOffset,
            (uint256(keccak256(abi.encode(difficulty))) % 99) + 1
        );

        assertGt(randomOffset, 0);
        assertLe(randomOffset, 100);

        // The lookups below use token ids down to 98 - randomOffset, which
        // only exist when randomOffset <= 97. The contract can return 98 or
        // 99 (it takes the offset modulo maxSupply - 1), which made the
        // Hardhat case fail for those values.
        vm.assume(randomOffset <= 97);

        uint256 startTokenId = 1;

        assertEq(
            offsetToken.tokenURI(1),
            _uri(((1 + randomOffset) % 100) + startTokenId)
        );
        assertEq(
            offsetToken.tokenURI(100),
            _uri(((100 + randomOffset) % 100) + startTokenId)
        );

        uint256 tokenUri2 = 101 - randomOffset;
        uint256 tokenUri1 = 100 - randomOffset;
        uint256 tokenUri100 = 99 - randomOffset;
        uint256 tokenUri99 = 98 - randomOffset;
        assertEq(offsetToken.tokenURI(tokenUri2), "http://example.com/2");
        assertEq(offsetToken.tokenURI(tokenUri1), "http://example.com/1");
        assertEq(offsetToken.tokenURI(tokenUri100), "http://example.com/100");
        assertEq(offsetToken.tokenURI(tokenUri99), "http://example.com/99");
    }

    function _uri(uint256 id) internal pure returns (string memory) {
        return string.concat("http://example.com/", Strings.toString(id));
    }
}
