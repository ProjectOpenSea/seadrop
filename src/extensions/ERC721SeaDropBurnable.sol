// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721RaribleDrop } from "../ERC721RaribleDrop.sol";

/**
 * @title  ERC721RaribleDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice ERC721RaribleDropBurnable is a token contract that extends
 *         ERC721RaribleDrop to additionally provide a burn function.
 */
contract ERC721RaribleDropBurnable is ERC721RaribleDrop {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed RaribleDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedRaribleDrop
    ) ERC721RaribleDrop(name, symbol, allowedRaribleDrop) {}

    /**
     * @notice Burns `tokenId`. The caller must own `tokenId` or be an
     *         approved operator.
     *
     * @param tokenId The token id to burn.
     */
    // solhint-disable-next-line comprehensive-interface
    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }
}
