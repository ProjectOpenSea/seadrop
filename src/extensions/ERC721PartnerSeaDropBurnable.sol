// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721PartnerSeaDrop } from "../ERC721PartnerSeaDrop.sol";

/**
 * @title  ERC721PartnerSeaDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerSeaDropBurnable is a token contract that extends
 *         ERC721PartnerSeaDrop to additionally provide a burn function.
 */
contract ERC721PartnerSeaDropBurnable is ERC721PartnerSeaDrop {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) ERC721PartnerSeaDrop(name, symbol, administrator, allowedSeaDrop) {}

    /**
     * @notice Burns `tokenId`. The caller must own `tokenId` or be an
     *         approved operator.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }
}
