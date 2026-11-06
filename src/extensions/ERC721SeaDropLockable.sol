// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

import { LockMode } from "../lib/ERC8451Lockable.sol";

/**
 * @title  ERC721SeaDropLockable
 * @author Ryan Ghods (ralxz.eth)
 * @notice ERC721SeaDrop that picks its starting lock status at deployment
 *         and can make the lock permanent at any time. Deploy with
 *         `LockMode.Locked` to pause trading until the owner unlocks it, or
 *         with `LockMode.PermanentlyLocked` for tokens that can never be
 *         transferred.
 *
 *         ERC721SeaDrop already implements lockable tokens (ERC-6982) and
 *         permanent locks (ERC-8451), but starts unlocked and only allows a
 *         permanent lock before the first mint. Use this contract to lock
 *         trading during a mint and make it permanent afterwards.
 */
contract ERC721SeaDropLockable is ERC721SeaDrop {
    /**
     * @notice Deploy the token contract.
     *
     *         ERC721SeaDrop emits `DefaultLocked(false)` first. With a
     *         Locked or PermanentlyLocked mode, this then emits
     *         `DefaultLocked(true)`, and `PermanentlyLocked()` for a
     *         permanent lock, in the same transaction.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters. Also contains SeaDrop
     *                          implementation code.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name              The name of the token.
     * @param symbol            The symbol of the token.
     * @param lockMode          The lock status to start with: Unlocked (0),
     *                          Locked (1), or PermanentlyLocked (2).
     */
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name,
        string memory symbol,
        LockMode lockMode
    ) ERC721SeaDrop(allowedConfigurer, allowedSeaport, name, symbol) {
        if (lockMode != LockMode.Unlocked) {
            _initializeLock(lockMode);
        }
    }

    /**
     * @dev The lock can become permanent at any time, including after
     *      tokens are minted. A contract that inherits this can override it
     *      to limit that again.
     */
    function _checkPermanentLockAllowed() internal view virtual override { }
}
