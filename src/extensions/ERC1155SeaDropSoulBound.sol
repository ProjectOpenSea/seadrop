// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

/**
 * @title  ERC721SeaDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice ERC1155SeaDropSoulbound is a token contract that extends
 *         ERC1155SeaDrop to prevent minted tokens from being transferred after mint.
 */
 
error SoulboundTransferNotAllowed() 

contract ERC1155SeaDropSoulbound is ERC1155SeaDrop {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    constructor(
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport,
        string memory name,
        string memory symbol
    ) ERC1155SeaDrop(allowedConfigurer, allowedConduit, allowedSeaport, name, symbol) {}

    function transferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public override {
        revert SoulboundTransferNotAllowed();
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public override {
        revert SoulboundTransferNotAllowed();
    }

    function safeBatchTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public virtual override{
        revert SoulboundTransferNotAllowed();
    }

}
