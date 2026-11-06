// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC6982 } from "../interfaces/IERC6982.sol";

import { IERC8451 } from "../interfaces/IERC8451.sol";

import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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
 *         `_initializeLock` once at deployment (from its constructor, or
 *         from its initializer for clones), call `_revertIfTokenLocked` for
 *         every holder transfer, decide who can update the lock in
 *         `_authorizeLockUpdate`, define when a token exists in
 *         `_lockableTokenExists`, and return true from `supportsInterface`
 *         for IERC6982 and IERC8451. It can limit when the lock may become
 *         permanent in `_checkPermanentLockAllowed`.
 *
 *         Declare this right after `TokenTransferValidator` in the
 *         inheritance list so its flags share the transfer validator's
 *         storage slot, which holder transfers already read.
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

    /// @notice Revert when making the lock permanent after tokens were
    ///         minted, in contracts that only allow it before.
    error CannotLockPermanentlyAfterMint();

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
    function setTokensLocked(
        uint256[] calldata tokenIds,
        bool isLocked
    ) external {
        _authorizeLockUpdate();
        _revertIfPermanentlyLocked();

        TokenLockOverride lockOverride = isLocked
            ? TokenLockOverride.Locked
            : TokenLockOverride.Unlocked;

        // Put the length on the stack for more efficient access.
        uint256 tokenIdsLength = tokenIds.length;

        for (uint256 i = 0; i < tokenIdsLength; ) {
            uint256 tokenId = tokenIds[i];

            _tokenLockOverrides[tokenId] = lockOverride;

            // Track unlocked tokens so they can be locked again before
            // the lock becomes permanent.
            if (isLocked) {
                _unlockedTokenIds.remove(tokenId);
            } else {
                _unlockedTokenIds.add(tokenId);
            }

            emit Locked(tokenId, isLocked);

            unchecked {
                ++i;
            }
        }

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

        _lockPermanently();
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
    function permanentlyLocked() external view returns (bool) {
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
     * @dev Set the lock status every token starts with. Emits
     *      `DefaultLocked`, which ERC-6982 requires at deployment, and
     *      `PermanentlyLocked` if the lock is permanent from the start.
     *      Reverts once the lock is permanent.
     *
     * @param lockMode The lock status to start with.
     */
    function _initializeLock(LockMode lockMode) internal {
        _revertIfPermanentlyLocked();

        bool isLocked = lockMode != LockMode.Unlocked;
        _defaultLocked = isLocked;
        emit DefaultLocked(isLocked);

        if (lockMode == LockMode.PermanentlyLocked) {
            _lockPermanently();
        }
    }

    /**
     * @dev Make the lock permanent, after emitting the events ERC-8451
     *      requires first. Callers check who is calling and that the lock
     *      is not already permanent.
     */
    function _lockPermanently() internal {
        // ERC-8451 requires `defaultLocked()` to return true before
        // `PermanentlyLocked` is emitted.
        if (!_defaultLocked) {
            _defaultLocked = true;
            emit DefaultLocked(true);
        }

        // ERC-8451 requires a `Locked(id, true)` for every token id whose
        // most recent `Locked` event unlocked it. The set is left in place
        // since `_isTokenLocked` ignores it once the lock is permanent.
        uint256 unlockedLength = _unlockedTokenIds.length();
        for (uint256 i = 0; i < unlockedLength; ) {
            emit Locked(_unlockedTokenIds.at(i), true);

            unchecked {
                ++i;
            }
        }

        _permanentlyLocked = true;
        emit PermanentlyLocked();
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
     * @dev Reverts if the lock cannot become permanent now. Allows it by
     *      default.
     */
    function _checkPermanentLockAllowed() internal view virtual {}

    /**
     * @dev Returns whether a token exists, for `locked`.
     *
     * @param tokenId The token id.
     */
    function _lockableTokenExists(
        uint256 tokenId
    ) internal view virtual returns (bool);
}
