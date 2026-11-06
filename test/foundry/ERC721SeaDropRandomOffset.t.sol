// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SeaDrop721MintHelpers } from "./utils/SeaDrop721MintHelpers.sol";

import {
    ERC721SeaDropRandomOffset
} from "seadrop/extensions/ERC721SeaDropRandomOffset.sol";

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
 * @dev Port of test/ERC721SeaDropRandomOffset.spec.ts.
 *      The test contract deploys the token, so it plays the spec's `owner`.
 */
contract ERC721SeaDropRandomOffsetTest is SeaDrop721MintHelpers {
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    ERC721SeaDropRandomOffset randomOffsetToken;

    address minter = makeAddr("minter");

    function setUp() public override {
        super.setUp();
        randomOffsetToken = new ERC721SeaDropRandomOffset(
            address(configurer),
            allowedSeaport,
            "",
            ""
        );
        // Point the shared helpers (_mintTokens) at this token.
        token = randomOffsetToken;
    }

    /// @dev "Should only let the owner call setRandomOffset once the max
    ///      supply is reached"
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

    /// @dev "Should return the tokenURI correctly offset by randomOffset"
    function testTokenURIOffsetByRandomOffset() public {
        randomOffsetToken.setMaxSupply(100);

        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        randomOffsetToken.tokenURI(1);

        // Mint to the max supply.
        _mintTokens(minter, 100);

        assertEq(randomOffsetToken.tokenURI(1), "");

        randomOffsetToken.setBaseURI("http://example.com/");

        assertEq(randomOffsetToken.tokenURI(1), "http://example.com/");

        // The offset is derived from PREVRANDAO. The spec's token ids below
        // (98 - randomOffset at the lowest) only exist for offsets up to 97,
        // so the Hardhat test was flaky for offsets 98 and 99. Pin
        // PREVRANDAO so the offset is deterministic (1 gives 46).
        ERC721SeaDropRandomOffsetPrevrandaoCheat(address(vm)).prevrandao(
            bytes32(uint256(1))
        );

        vm.expectEmit(true, true, true, true, address(randomOffsetToken));
        emit BatchMetadataUpdate(1, 100);
        randomOffsetToken.setRandomOffset();

        uint256 randomOffset = randomOffsetToken.randomOffset();

        assertGt(randomOffset, 0);
        assertLe(randomOffset, 100);
        // keccak256(abi.encode(1)) % 99 + 1, confirms the pin took effect.
        assertEq(randomOffset, 46);

        uint256 startTokenId = 1;

        assertEq(
            randomOffsetToken.tokenURI(1),
            string.concat(
                "http://example.com/",
                vm.toString(((1 + randomOffset) % 100) + startTokenId)
            )
        );
        assertEq(
            randomOffsetToken.tokenURI(100),
            string.concat(
                "http://example.com/",
                vm.toString(((100 + randomOffset) % 100) + startTokenId)
            )
        );

        uint256 tokenUri2 = 101 - randomOffset;
        uint256 tokenUri1 = 100 - randomOffset;
        uint256 tokenUri100 = 99 - randomOffset;
        uint256 tokenUri99 = 98 - randomOffset;
        assertEq(randomOffsetToken.tokenURI(tokenUri2), "http://example.com/2");
        assertEq(randomOffsetToken.tokenURI(tokenUri1), "http://example.com/1");
        assertEq(
            randomOffsetToken.tokenURI(tokenUri100),
            "http://example.com/100"
        );
        assertEq(
            randomOffsetToken.tokenURI(tokenUri99),
            "http://example.com/99"
        );
    }
}
