// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1155SeaDrop } from "../ERC1155SeaDrop.sol";

import { LockMode } from "../lib/ERC8451Lockable.sol";

/**
 * @title  ERC1155SeaDropLockable
 * @author Ryan Ghods (ralxz.eth)
 * @notice ERC1155SeaDrop that picks its starting lock status at deployment
 *         and can make the lock permanent at any time. Deploy with
 *         `LockMode.Locked` to pause trading until the owner unlocks it, or
 *         with `LockMode.PermanentlyLocked` for tokens that can never be
 *         transferred.
 *
 *         ERC1155SeaDrop already implements lockable tokens (ERC-6982) and
 *         permanent locks (ERC-8451), but starts unlocked and only allows a
 *         permanent lock before the first mint. Use this contract to lock
 *         trading during a mint and make it permanent afterwards.
 */
contract ERC1155SeaDropLockable is ERC1155SeaDrop {
    /**
     * @notice Deploy the token contract.
     *
     *         ERC1155SeaDrop emits `DefaultLocked(false)` first. With a
     *         Locked or PermanentlyLocked mode, this then emits
     *         `DefaultLocked(true)`, and `PermanentlyLocked()` for a
     *         permanent lock, in the same transaction.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters. Also contains SeaDrop
     *                          implementation code.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     * @param lockMode          The lock status to start with: Unlocked (0),
     *                          Locked (1), or PermanentlyLocked (2).
     */
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name_,
        string memory symbol_,
        LockMode lockMode
    ) ERC1155SeaDrop(allowedConfigurer, allowedSeaport, name_, symbol_) {
        if (lockMode != LockMode.Unlocked) {
            _initializeLock(lockMode);
        }
    }

    /**
     * @dev The lock can become permanent at any time, including after
     *      tokens are minted.
     */
    function _checkPermanentLockAllowed() internal view override {}
}
