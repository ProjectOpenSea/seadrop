// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721PartnerRaribleDrop } from "../ERC721PartnerRaribleDrop.sol";

/**
 * @title  ERC721PartnerRaribleDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerRaribleDropBurnable is a token contract that extends
 *         ERC721PartnerRaribleDrop to additionally provide a burn function.
 */
contract ERC721PartnerRaribleDropBurnable is ERC721PartnerRaribleDrop {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed RaribleDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedRaribleDrop
    ) ERC721PartnerRaribleDrop(name, symbol, administrator, allowedRaribleDrop) {}

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
