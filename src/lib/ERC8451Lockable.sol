// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { IERC6982 } from "../interfaces/IERC6982.sol";

import { IERC8451 } from "../interfaces/IERC8451.sol";

import {
    EnumerableSet
} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

/**
 * @notice The lock status a token contract starts with at deployment.
 *
 *         Unlocked:          Tokens are transferable. The owner can lock
 *                            them later.
 *         Locked:            Holder transfers revert. The owner can unlock,
 *                            lock again, or make the lock permanent.
 *         PermanentlyLocked: Holder transfers always revert, and the lock
 *                            can never be lifted.
 */
enum LockMode {
    Unlocked,
    Locked,
    PermanentlyLocked
}

/**
 * @title  ERC8451Lockable
 * @author Ryan Ghods (ralxz.eth)
 * @notice Lock state for ERC-6982 lockable tokens with the ERC-8451
 *         permanent lock extension. Locks restrict holder transfers only:
 *         mints and burns continue while tokens are locked.
 *
 *         The token contract that inherits this must call
 *         `_revertIfTokenLocked` for every holder transfer, decide who can
 *         update the lock in `_authorizeLockUpdate`, define when a token
 *         exists in `_lockableTokenExists`, and return true from
 *         `supportsInterface` for IERC6982 and IERC8451. It can limit when
 *         the lock may become permanent in `_checkPermanentLockAllowed`.
 *         It should call `_revertIfTemporarilyLocked` when its owner gives
 *         up ownership.
 */
abstract contract ERC8451Lockable is IERC6982, IERC8451 {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @dev A token's own lock status, set by a `Locked` event, which
    ///      overrides the default lock status.
    enum TokenLockOverride {
        None,
        Locked,
        Unlocked
    }

    /// @dev The default lock status of every token (ERC-6982).
    bool private _defaultLocked;

    /// @dev Whether every token is permanently locked (ERC-8451).
    bool private _permanentlyLocked;

    /// @dev Whether any token has its own lock status. Until one does,
    ///      transfer checks skip the per-token lookup.
    bool private _hasTokenLockOverrides;

    /// @dev How many tokens have their own lock status set to locked. With
    ///      the default lock status, it tells whether a temporary lock is
    ///      in place. It shares the flags' storage slot.
    uint64 private _lockedTokenCount;

    /// @dev Lock status overrides for single tokens.
    mapping(uint256 => TokenLockOverride) private _tokenLockOverrides;

    /// @dev Token ids whose most recent `Locked` event unlocked them.
    ///      `lockPermanently` locks each of them again before the lock
    ///      becomes permanent, as ERC-8451 requires.
    EnumerableSet.UintSet private _unlockedTokenIds;

    /// @notice Revert when updating the lock after it became permanent.
    error LockIsPermanent();

    /// @notice Revert when querying the lock status of a token that does
    ///         not exist.
    error LockQueryForNonexistentToken();

    /// @notice Revert when giving up ownership while a temporary lock is in
    ///         place, since no one could lift it afterwards.
    error CannotRenounceOwnershipWhileLocked();

    /**
     * @notice Set the lock status every token starts with. Emits
     *         `DefaultLocked`, which ERC-6982 requires at deployment, and
     *         `PermanentlyLocked` if the lock is permanent from the start.
     *
     * @param lockMode The lock status to start with.
     */
    constructor(LockMode lockMode) {
        bool isLocked = lockMode != LockMode.Unlocked;
        _defaultLocked = isLocked;
        emit DefaultLocked(isLocked);

        if (lockMode == LockMode.PermanentlyLocked) {
            _permanentlyLocked = true;
            emit PermanentlyLocked();
        }
    }

    /**
     * @notice Set the default lock status of every token that does not
     *         have its own lock status. Reverts once the lock is permanent.
     *
     * @param isLocked Whether tokens are locked by default.
     */
    function setDefaultLocked(bool isLocked) external {
        _authorizeLockUpdate();
        _revertIfPermanentlyLocked();

        _defaultLocked = isLocked;
        emit DefaultLocked(isLocked);
    }

    /**
     * @notice Set the lock status of single tokens, overriding the default
     *         lock status. Token ids that do not exist yet can be set too.
     *         Reverts once the lock is permanent.
     *
     *         Every token unlocked here is locked again, with a `Locked`
     *         event, when the lock becomes permanent. To spread that cost
     *         over several transactions, lock them again here first.
     *
     * @param tokenIds The token ids to update.
     * @param isLocked Whether the tokens are locked.
     */
    function setTokensLocked(uint256[] calldata tokenIds, bool isLocked)
        external
    {
        _authorizeLockUpdate();
        _revertIfPermanentlyLocked();

        TokenLockOverride lockOverride =
            isLocked ? TokenLockOverride.Locked : TokenLockOverride.Unlocked;

        // Put the length on the stack for more efficient access.
        uint256 tokenIdsLength = tokenIds.length;

        // Count locked tokens on the stack and write the total once.
        uint64 lockedTokenCount = _lockedTokenCount;

        for (uint256 i = 0; i < tokenIdsLength;) {
            uint256 tokenId = tokenIds[i];

            // Skip the writes if the token already has this lock status.
            TokenLockOverride previous = _tokenLockOverrides[tokenId];
            if (previous != lockOverride) {
                _tokenLockOverrides[tokenId] = lockOverride;

                // Track unlocked tokens so they can be locked again before
                // the lock becomes permanent, and count locked ones. The
                // count can't wrap: it only drops for a token it counted.
                unchecked {
                    if (isLocked) {
                        if (previous == TokenLockOverride.Unlocked) {
                            _unlockedTokenIds.remove(tokenId);
                        }
                        ++lockedTokenCount;
                    } else {
                        _unlockedTokenIds.add(tokenId);
                        if (previous == TokenLockOverride.Locked) {
                            --lockedTokenCount;
                        }
                    }
                }
            }

            emit Locked(tokenId, isLocked);

            unchecked {
                ++i;
            }
        }

        _lockedTokenCount = lockedTokenCount;

        if (tokenIdsLength != 0 && !_hasTokenLockOverrides) {
            _hasTokenLockOverrides = true;
        }
    }

    /**
     * @notice Lock every token permanently. Holder transfers will always
     *         revert, and the lock can never be lifted.
     *
     *         Before emitting `PermanentlyLocked`, this locks tokens by
     *         default if they are not already, and emits `Locked(id, true)`
     *         for every token id unlocked with `setTokensLocked`, whether
     *         or not that token still exists.
     */
    function lockPermanently() external {
        _authorizeLockUpdate();
        _revertIfPermanentlyLocked();
        _checkPermanentLockAllowed();

        // ERC-8451 requires `defaultLocked()` to return true before
        // `PermanentlyLocked` is emitted.
        if (!_defaultLocked) {
            _defaultLocked = true;
            emit DefaultLocked(true);
        }

        // ERC-8451 requires a `Locked(id, true)` for every token id whose
        // most recent `Locked` event unlocked it. The set and the overrides
        // are left in place, since `_isTokenLocked` returns true for every
        // token once the lock is permanent.
        uint256 unlockedLength = _unlockedTokenIds.length();
        for (uint256 i = 0; i < unlockedLength;) {
            emit Locked(_unlockedTokenIds.at(i), true);

            unchecked {
                ++i;
            }
        }

        _permanentlyLocked = true;
        emit PermanentlyLocked();
    }

    /**
     * @notice Returns the default lock status of every token that does not
     *         have its own lock status.
     */
    function defaultLocked() external view returns (bool) {
        return _defaultLocked;
    }

    /**
     * @notice Returns whether every token is permanently locked.
     */
    function permanentlyLocked() public view returns (bool) {
        return _permanentlyLocked;
    }

    /**
     * @notice Returns the lock status of a token. Reverts if the token
     *         does not exist.
     *
     * @param tokenId The token id.
     */
    function locked(uint256 tokenId) external view returns (bool) {
        if (!_lockableTokenExists(tokenId)) {
            revert LockQueryForNonexistentToken();
        }

        return _isTokenLocked(tokenId);
    }

    /**
     * @dev Reverts with `TokenLocked` if the token is locked. The token
     *      contract must call this for every holder transfer, where both
     *      the sender and the recipient are not the zero address.
     *
     * @param tokenId The token id.
     */
    function _revertIfTokenLocked(uint256 tokenId) internal view {
        if (_isTokenLocked(tokenId)) {
            revert TokenLocked(tokenId);
        }
    }

    /**
     * @dev Reverts with `LockIsPermanent` if every token is permanently
     *      locked.
     */
    function _revertIfPermanentlyLocked() internal view {
        if (_permanentlyLocked) {
            revert LockIsPermanent();
        }
    }

    /**
     * @dev Reverts with `CannotRenounceOwnershipWhileLocked` while a
     *      temporary lock is in place: tokens are locked by default, or a
     *      token has its own lock status set to locked, and the lock is not
     *      permanent. The token contract calls this when its owner gives up
     *      ownership, so a lock that no one could lift never outlives them.
     *      The owner can unlock first, or make the lock permanent.
     */
    function _revertIfTemporarilyLocked() internal view {
        if (!_permanentlyLocked && (_defaultLocked || _lockedTokenCount != 0)) {
            revert CannotRenounceOwnershipWhileLocked();
        }
    }

    /**
     * @dev Returns the lock status of a token, without checking that it
     *      exists.
     *
     * @param tokenId The token id.
     */
    function _isTokenLocked(uint256 tokenId) internal view returns (bool) {
        if (_permanentlyLocked) {
            return true;
        }

        if (_hasTokenLockOverrides) {
            TokenLockOverride lockOverride = _tokenLockOverrides[tokenId];
            if (lockOverride != TokenLockOverride.None) {
                return lockOverride == TokenLockOverride.Locked;
            }
        }

        return _defaultLocked;
    }

    /**
     * @dev Reverts if the caller cannot update the lock.
     */
    function _authorizeLockUpdate() internal view virtual;

    /**
     * @dev Reverts if the lock cannot become permanent now. Allows it at
     *      any time by default. A contract that inherits this can limit it,
     *      for example to before the first mint.
     */
    function _checkPermanentLockAllowed() internal view virtual { }

    /**
     * @dev Returns whether a token exists, for `locked`.
     *
     * @param tokenId The token id.
     */
    function _lockableTokenExists(uint256 tokenId)
        internal
        view
        virtual
        returns (bool);
}
