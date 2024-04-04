// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

/**
 * @title  ERC721SeaDropSoulbound
 * @notice A token contract that extends ERC721SeaDrop to be soulbound,
 *         meaning it cannot be transferred after minting.
 */
contract ERC721SeaDropSoulbound is ERC721SeaDrop {
    /// @notice Revert on approvals and transfers since the token is soulbound.
    error SoulboundNotTransferable();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {}

    /**
     * @notice This token is soulbound, so approvals cannot be set.
     */
    function setApprovalForAll(
        address, /* operator */
        bool /* approved */
    ) public virtual override {
        revert SoulboundNotTransferable();
    }

    /**
     * @notice This token is soulbound, so approvals cannot be set.
     */
    function approve(
        address, /* to */
        uint256 /* tokenId */
    ) public virtual override {
        revert SoulboundNotTransferable();
    }

    /**
     * @notice This token is soulbound, so transfers are not allowed.
     */
    function _beforeTokenTransfers(
        address from,
        address, /* to */
        uint256, /* startTokenId */
        uint256 /* quantity */
    ) internal virtual override {
        if (from != address(0)) {
            revert SoulboundNotTransferable();
        }
    }
}
