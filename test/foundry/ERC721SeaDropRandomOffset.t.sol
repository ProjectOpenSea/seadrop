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
        if (_upgradeable()) {
            // Same ABI apart from revealed(), which these tests don't call.
            offsetToken = ERC721SeaDropRandomOffset(
                _deployUpgradeable(
                    "ERC721SeaDropRandomOffsetUpgradeable",
                    "",
                    "",
                    allowedSeaDrop
                )
            );
        } else {
            offsetToken = new ERC721SeaDropRandomOffset("", "", allowedSeaDrop);
        }
    }

    function _mintToMaxSupply() internal {
        uint256 maxSupply = offsetToken.maxSupply();
        vm.prank(address(seadrop));
        offsetToken.mintSeaDrop(minter, maxSupply);
    }

    /// @dev Whether the token reports itself revealed. revealed() returns
    ///      1 or 2 on ERC721SeaDropRandomOffset, and a bool on the
    ///      upgradeable token.
    function _revealed() internal view returns (bool) {
        return offsetToken.revealed() == (_upgradeable() ? 1 : 2);
    }

    /// @dev Mint `maxSupply` tokens and reveal them with `difficulty` as the
    ///      randomness source.
    function _reveal(uint256 maxSupply, uint256 difficulty) internal {
        offsetToken.setMaxSupply(maxSupply);
        offsetToken.setBaseURI("http://example.com/");
        _mintToMaxSupply();
        vm.difficulty(difficulty);
        offsetToken.setRandomOffset();
    }

    /// @dev The token that shows metadata id `metadataId` after a reveal
    ///      with `randomOffset`, the inverse of tokenURI's mapping.
    function _tokenWithMetadata(
        uint256 metadataId,
        uint256 randomOffset,
        uint256 maxSupply
    ) internal pure returns (uint256) {
        uint256 tokenId =
            (metadataId - 1 + maxSupply - randomOffset) % maxSupply;
        return tokenId == 0 ? maxSupply : tokenId;
    }

    function testSetRandomOffset_onlyOnceWhenFullyMinted() public {
        offsetToken.setMaxSupply(100);

        vm.expectRevert(ERC721SeaDropRandomOffset.NotFullyMinted.selector);
        offsetToken.setRandomOffset();

        // Mint to the max supply.
        _mintToMaxSupply();

        assertEq(offsetToken.randomOffset(), 0);
        assertFalse(_revealed());

        // Only the owner can set the random offset.
        vm.prank(minter);
        vm.expectRevert(TwoStepOwnable.OnlyOwner.selector);
        offsetToken.setRandomOffset();

        offsetToken.setRandomOffset();
        assertTrue(_revealed());

        vm.expectRevert(ERC721SeaDropRandomOffset.AlreadyRevealed.selector);
        offsetToken.setRandomOffset();
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

        // The offset is derived from the fuzzed randomness source, uniformly
        // over the 99 shifts that move every token.
        assertEq(randomOffset, uint256(keccak256(abi.encode(difficulty))) % 99);
        assertLe(randomOffset, 98);

        uint256 startTokenId = 1;

        assertEq(
            offsetToken.tokenURI(1),
            _uri(((1 + randomOffset) % 100) + startTokenId)
        );
        assertEq(
            offsetToken.tokenURI(100),
            _uri(((100 + randomOffset) % 100) + startTokenId)
        );

        assertEq(
            offsetToken.tokenURI(_tokenWithMetadata(2, randomOffset, 100)),
            "http://example.com/2"
        );
        assertEq(
            offsetToken.tokenURI(_tokenWithMetadata(1, randomOffset, 100)),
            "http://example.com/1"
        );
        assertEq(
            offsetToken.tokenURI(_tokenWithMetadata(100, randomOffset, 100)),
            "http://example.com/100"
        );
        assertEq(
            offsetToken.tokenURI(_tokenWithMetadata(99, randomOffset, 100)),
            "http://example.com/99"
        );
    }

    /// @dev For any supply above one, the offset is uniform over the
    ///      maxSupply - 1 shifts that move every token, so no token keeps
    ///      its own metadata. tokenURI shifts every token by the same
    ///      amount, so checking token 1 covers them all. The old offset,
    ///      (random % (maxSupply - 1)) + 1, could be maxSupply - 1, which
    ///      left every token on its own metadata.
    function testSetRandomOffset_shufflesEveryToken(
        uint256 difficulty,
        uint256 maxSupply
    ) public {
        maxSupply = bound(maxSupply, 2, 200);
        _reveal(maxSupply, difficulty);

        uint256 randomOffset = offsetToken.randomOffset();
        assertEq(
            randomOffset,
            uint256(keccak256(abi.encode(difficulty))) % (maxSupply - 1)
        );
        assertEq(offsetToken.tokenURI(1), _uri(randomOffset + 2));
        assertTrue(
            keccak256(bytes(offsetToken.tokenURI(1)))
                != keccak256(bytes(_uri(1)))
        );
    }

    /// @dev With two tokens the only shift that moves them is a swap. The
    ///      old offset was always 1, which left both on their own metadata.
    function testSetRandomOffset_swapsTwoTokens(uint256 difficulty) public {
        _reveal(2, difficulty);

        assertEq(offsetToken.randomOffset(), 0);
        assertEq(offsetToken.tokenURI(1), _uri(2));
        assertEq(offsetToken.tokenURI(2), _uri(1));
    }

    /// @dev A single token reveals onto its own metadata. The old offset
    ///      divided by maxSupply - 1 and panicked.
    function testSetRandomOffset_oneToken() public {
        _reveal(1, 0);

        assertTrue(_revealed());
        assertEq(offsetToken.randomOffset(), 0);
        assertEq(offsetToken.tokenURI(1), _uri(1));

        vm.expectRevert(ERC721SeaDropRandomOffset.AlreadyRevealed.selector);
        offsetToken.setRandomOffset();
    }

    /// @dev With no supply there is nothing to reveal. The old offset
    ///      underflowed on maxSupply - 1 and panicked.
    function testSetRandomOffset_revertsWithoutSupply() public {
        assertEq(offsetToken.maxSupply(), 0);

        vm.expectRevert(ERC721SeaDropRandomOffset.NotFullyMinted.selector);
        offsetToken.setRandomOffset();
        assertFalse(_revealed());
    }

    function _uri(uint256 id) internal pure returns (string memory) {
        return string.concat("http://example.com/", Strings.toString(id));
    }
}
