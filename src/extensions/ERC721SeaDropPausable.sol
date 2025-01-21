// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

/**
 * @title  ERC721SeaDropPausable
 * @notice A token contract that extends ERC721SeaDrop to be able to
 *         pause token transfers. By default on deployment transfers are paused,
 *         and the owner of the token contract can pause or unpause.
 */
contract ERC721SeaDropPausable is ERC721SeaDrop {
    /// @notice Revert when transfers are paused.
    error TransfersPaused();

    /// @notice Emit an event when transfers are paused or unpaused.
    event TransfersPausedChanged(bool paused);

    /// @notice Boolean if transfers are paused.
    bool public transfersPaused = true;

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {
        emit TransfersPausedChanged(transfersPaused);
    }

    function updateTransfersPaused(bool paused) external onlyOwner {
        transfersPaused = paused;
        emit TransfersPausedChanged(paused);
    }

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        if (transfersPaused) {
            revert TransfersPaused();
        }
        super.setApprovalForAll(operator, approved);
    }

    function approve(address to, uint256 tokenId) public virtual override {
        if (transfersPaused) {
            revert TransfersPaused();
        }
        super.approve(to, tokenId);
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        if (from != address(0) && transfersPaused) {
            revert TransfersPaused();
        }
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
