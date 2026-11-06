// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721Test } from "./utils/SeaDrop721Test.sol";

import {
    ERC721SeaDropRandomOffset
} from "seadrop/extensions/ERC721SeaDropRandomOffset.sol";

import { MultiConfigureStruct } from "seadrop/lib/ERC721SeaDropStructs.sol";

import { IERC721A } from "ERC721A/IERC721A.sol";

import { Ownable } from "solady/src/auth/Ownable.sol";

/**
 * @dev The pinned forge-std Vm interface predates the prevrandao cheatcode,
 *      which the forge binary supports.
 */
interface ERC721SeaDropRandomOffsetPrevrandaoCheat {
    function prevrandao(bytes32 newPrevrandao) external;
}

/**
 * @dev The random offset reveal. The test contract deploys the token, so it
 *      is the owner.
 */
contract ERC721SeaDropRandomOffsetTest is SeaDrop721Test {
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    ERC721SeaDropRandomOffset randomOffsetToken;

    address minter = makeAddr("minter");

    function setUp() public override {
        super.setUp();
        randomOffsetToken = new ERC721SeaDropRandomOffset(
            address(configurer), allowedSeaport, "", ""
        );
        // Point the shared helpers (_mintTokens) at this token.
        token = randomOffsetToken;
    }

    /// @dev Should only let the owner call setRandomOffset once the max
    ///      supply is reached.
    function testOnlyOwnerCanSetRandomOffsetOnceFullyMinted() public {
        randomOffsetToken.setMaxSupply(100);

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(minter);
        randomOffsetToken.setRandomOffset();

        vm.expectRevert(ERC721SeaDropRandomOffset.NotFullyMinted.selector);
        randomOffsetToken.setRandomOffset();

        // Mint to the max supply.
        _mintTokens(minter, 100);

        assertEq(randomOffsetToken.randomOffset(), 0);

        randomOffsetToken.setRandomOffset();

        vm.expectRevert(ERC721SeaDropRandomOffset.AlreadyRevealed.selector);
        randomOffsetToken.setRandomOffset();

        assertTrue(randomOffsetToken.randomOffset() != 0);
    }

    /// @dev Should return the tokenURI correctly offset by randomOffset.
    function testTokenURIOffsetByRandomOffset() public {
        randomOffsetToken.setMaxSupply(100);

        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        randomOffsetToken.tokenURI(1);

        // Mint to the max supply.
        _mintTokens(minter, 100);

        assertEq(randomOffsetToken.tokenURI(1), "");

        randomOffsetToken.setBaseURI("http://example.com/");

        assertEq(randomOffsetToken.tokenURI(1), "http://example.com/");

        // Pin PREVRANDAO so the offset is deterministic.
        _setPrevrandao(1);

        vm.expectEmit(true, true, true, true, address(randomOffsetToken));
        emit BatchMetadataUpdate(1, 100);
        randomOffsetToken.setRandomOffset();

        // keccak256(abi.encode(1)) % 99 + 1, confirms the pin took effect.
        uint256 randomOffset = randomOffsetToken.randomOffset();
        assertEq(randomOffset, 46);

        // Token t shows the metadata `randomOffset` positions after it,
        // wrapping at the max supply.
        assertEq(randomOffsetToken.tokenURI(1), "http://example.com/47");
        assertEq(randomOffsetToken.tokenURI(54), "http://example.com/100");
        assertEq(randomOffsetToken.tokenURI(55), "http://example.com/1");
        assertEq(randomOffsetToken.tokenURI(100), "http://example.com/46");
        _assertRevealIsDerangement(100, randomOffset);
    }

    function _setPrevrandao(uint256 prevrandao) internal {
        ERC721SeaDropRandomOffsetPrevrandaoCheat(address(vm))
            .prevrandao(bytes32(prevrandao));
    }

    /// @dev Mint the whole supply and reveal with `prevrandao`.
    function _mintAndReveal(uint256 maxSupply, uint256 prevrandao) internal {
        randomOffsetToken.setMaxSupply(maxSupply);
        _mintTokens(minter, maxSupply);
        randomOffsetToken.setBaseURI("http://example.com/");
        _setPrevrandao(prevrandao);
        randomOffsetToken.setRandomOffset();
    }

    /// @dev The revealed token URIs are a rotation of 1..maxSupply by
    ///      `randomOffset` in which no token keeps its own metadata.
    function _assertRevealIsDerangement(uint256 maxSupply, uint256 randomOffset)
        internal
        view
    {
        for (uint256 tokenId = 1; tokenId <= maxSupply; tokenId++) {
            uint256 metadataId = ((tokenId - 1 + randomOffset) % maxSupply) + 1;
            assertTrue(metadataId != tokenId, "token kept its own metadata");
            assertEq(
                randomOffsetToken.tokenURI(tokenId),
                string.concat("http://example.com/", vm.toString(metadataId))
            );
        }
    }

    /// @dev The token URIs wrap at the max supply, so changing it after the
    ///      reveal (directly or through the configurer) would reshuffle
    ///      them; it reverts instead. Before the reveal it can change.
    function testCannotChangeMaxSupplyAfterReveal() public {
        randomOffsetToken.setMaxSupply(9);
        randomOffsetToken.setMaxSupply(10);
        _mintAndReveal(10, 1);
        uint256 randomOffset = randomOffsetToken.randomOffset();

        vm.expectRevert(ERC721SeaDropRandomOffset.AlreadyRevealed.selector);
        randomOffsetToken.setMaxSupply(11);
        vm.expectRevert(ERC721SeaDropRandomOffset.AlreadyRevealed.selector);
        randomOffsetToken.setMaxSupply(10);

        MultiConfigureStruct memory config;
        config.maxSupply = 11;
        vm.expectRevert(ERC721SeaDropRandomOffset.AlreadyRevealed.selector);
        configurer.multiConfigure(address(randomOffsetToken), config);

        assertEq(randomOffsetToken.maxSupply(), 10);
        _assertRevealIsDerangement(10, randomOffset);
    }

    /// @dev Revealing before any max supply is set would lock the offset,
    ///      so it reverts as not fully minted.
    function testCannotRevealZeroMaxSupply() public {
        assertEq(randomOffsetToken.maxSupply(), 0);
        vm.expectRevert(ERC721SeaDropRandomOffset.NotFullyMinted.selector);
        randomOffsetToken.setRandomOffset();
        assertEq(randomOffsetToken.revealed(), 1);
    }

    /// @dev A single token has only the identity shift: the reveal sets no
    ///      offset instead of dividing by zero.
    function testRevealWithMaxSupplyOne(uint256 prevrandao) public {
        _mintAndReveal(1, prevrandao);
        assertEq(randomOffsetToken.revealed(), 2);
        assertEq(randomOffsetToken.randomOffset(), 0);
        assertEq(randomOffsetToken.tokenURI(1), "http://example.com/1");
    }

    /// @dev Two tokens always swap.
    function testRevealWithMaxSupplyTwo(uint256 prevrandao) public {
        _mintAndReveal(2, prevrandao);
        assertEq(randomOffsetToken.randomOffset(), 1);
        assertEq(randomOffsetToken.tokenURI(1), "http://example.com/2");
        assertEq(randomOffsetToken.tokenURI(2), "http://example.com/1");
    }

    /// @dev The offset is keccak256(prevrandao) mod (maxSupply - 1), plus 1:
    ///      every shift from 1 to maxSupply - 1 and never the identity.
    function testFuzzRevealOffsetRange(uint256 maxSupply, uint256 prevrandao)
        public
    {
        maxSupply = bound(maxSupply, 2, 40);
        _mintAndReveal(maxSupply, prevrandao);

        uint256 randomOffset = randomOffsetToken.randomOffset();
        assertEq(
            randomOffset,
            (uint256(keccak256(abi.encode(prevrandao))) % (maxSupply - 1)) + 1
        );
        assertGe(randomOffset, 1);
        assertLe(randomOffset, maxSupply - 1);
        _assertRevealIsDerangement(maxSupply, randomOffset);
    }

    /// @dev Both ends of the offset range are reachable: maxSupply - 1 (the
    ///      shift that used to leave every token unshuffled) and 1 (the
    ///      shift that used to be unreachable).
    function testRevealOffsetRangeEnds() public {
        uint256 maxSupply = 5;
        uint256 lowSeed;
        uint256 highSeed;
        for (uint256 seed = 0; lowSeed == 0 || highSeed == 0; seed++) {
            uint256 r = uint256(keccak256(abi.encode(seed))) % (maxSupply - 1);
            if (r == 0 && lowSeed == 0) lowSeed = seed;
            if (r == maxSupply - 2 && highSeed == 0) highSeed = seed;
        }

        uint256 snapshot = vm.snapshotState();
        _mintAndReveal(maxSupply, lowSeed);
        assertEq(randomOffsetToken.randomOffset(), 1);
        _assertRevealIsDerangement(maxSupply, 1);

        vm.revertToState(snapshot);
        _mintAndReveal(maxSupply, highSeed);
        assertEq(randomOffsetToken.randomOffset(), maxSupply - 1);
        _assertRevealIsDerangement(maxSupply, maxSupply - 1);
    }
}
