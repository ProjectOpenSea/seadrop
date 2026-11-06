// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

import { ERC8451Lockable, LockMode } from "../lib/ERC8451Lockable.sol";

import { IERC6982 } from "../interfaces/IERC6982.sol";

import { IERC8451 } from "../interfaces/IERC8451.sol";

/**
 * @title  ERC721SeaDropLockable
 * @author Ryan Ghods (ralxz.eth)
 * @notice ERC721SeaDrop with lockable tokens (ERC-6982) and permanent locks
 *         (ERC-8451). It replaces ERC721SeaDropPausable and
 *         ERC721SeaDropSoulbound: deploy with `LockMode.Locked` to pause
 *         trading until the owner unlocks it, or with
 *         `LockMode.PermanentlyLocked` for tokens that can never be
 *         transferred.
 *
 *         Locks restrict holder transfers only. Minting continues while
 *         tokens are locked, and the holder or an approved operator can
 *         still burn. Approvals work as usual until the lock is permanent.
 *         After that, new approvals revert, and existing approvals can
 *         still be revoked.
 */
contract ERC721SeaDropLockable is ERC721SeaDrop, ERC8451Lockable {
    /**
     * @notice Deploy the token contract with its name, symbol, allowed
     *         SeaDrop addresses, and starting lock status.
     *
     * @param name           The name of the token.
     * @param symbol         The symbol of the token.
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     * @param lockMode       The lock status to start with: Unlocked (0),
     *                       Locked (1), or PermanentlyLocked (2).
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop,
        LockMode lockMode
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) ERC8451Lockable(lockMode) { }

    /**
     * @notice Approve or remove `operator` as an operator for the caller.
     *         Granting an approval reverts once the lock is permanent.
     *         Removing one always works.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        if (approved) {
            _revertIfPermanentlyLocked();
        }

        super.setApprovalForAll(operator, approved);
    }

    /**
     * @notice Approve `to` to transfer `tokenId`. Granting an approval
     *         reverts once the lock is permanent. Clearing one by
     *         approving the zero address always works.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        if (to != address(0)) {
            _revertIfPermanentlyLocked();
        }

        super.approve(to, tokenId);
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC6982).interfaceId
            || interfaceId == type(IERC8451).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Reverts holder transfers of locked tokens with `TokenLocked`.
     *      Mints and burns are not holder transfers and are not affected.
     *      The lock is checked before the transfer validator.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        // ERC721A transfers one token at a time, so a holder transfer only
        // needs to check `startTokenId`.
        if (from != address(0) && to != address(0)) {
            _revertIfTokenLocked(startTokenId);
        }

        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    /**
     * @dev Only the owner can update the lock.
     */
    function _authorizeLockUpdate() internal view override {
        _checkOwner();
    }

    /**
     * @dev A token exists from mint until burn.
     */
    function _lockableTokenExists(uint256 tokenId)
        internal
        view
        override
        returns (bool)
    {
        return _exists(tokenId);
    }
}
