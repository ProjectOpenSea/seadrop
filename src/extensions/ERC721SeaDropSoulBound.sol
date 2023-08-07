// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

/**
 * @title  ERC721SeaDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice ERC721SeaDropSoulbound is a token contract that extends
 *         ERC721SeaDrop to prevent minted tokens from being transferred after mint.
 */
 
error SoulboundTransferNotAllowed() 

contract ERC721SeaDropSoulbound is ERC721SeaDrop {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {}

    function transferFrom(
        address from,
        address,
        uint256
    ) public override {
        revert SoulboundTransferNotAllowed();
    }

    function safeTransferFrom(
        address from,
        address,
        uint256
    ) public override {
        revert SoulboundTransferNotAllowed();
    }

}
