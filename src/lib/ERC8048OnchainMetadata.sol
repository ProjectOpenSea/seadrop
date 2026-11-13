// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { IERC8048Metadata } from "../interfaces/IERC8048Metadata.sol";

/**
 * @title  ERC8048OnchainMetadata
 * @author Ryan Ghods (ralxz.eth)
 * @notice Onchain metadata for ERC-721 tokens under ERC-8048: string keys
 *         with bytes values, stored per token.
 *
 *         One collection authority decides who writes, with two settings:
 *         - The collection authority can write any token's metadata. While
 *           it is blank (the zero address), the metadata admin (the owner)
 *           is the authority. The authority can be a policy contract that
 *           applies its own rules, such as MetadataWriterPolicy.
 *         - With `holderCanWrite`, a token's current holder can also write
 *           that token's metadata. The check reads the holder at write
 *           time, so a new holder can write right after a transfer and the
 *           old holder can't.
 *         - With `authorityLocked`, the admin can no longer change the
 *           settings. The current authority still can, so a locked policy
 *           contract can hand itself on. A blank authority can't be
 *           locked.
 *
 *         Both settings start false, so a new collection starts with the
 *         admin controlling everything. Tokens don't have to exist yet, so
 *         the authority can write metadata before a mint.
 *
 *         The module has no key locks. A collection authority that is a
 *         policy contract can freeze records per token, for example with a
 *         write-once rule, and a collection that wants every record frozen
 *         can lock the authority to an address nobody controls, such as
 *         0x000000000000000000000000000000000000dEaD, with `holderCanWrite`
 *         false.
 *
 *         Each write emits `MetadataSet` and calls `_emitMetadataUpdate`
 *         once per token, where the token contract emits ERC-4906
 *         `MetadataUpdate` for a token that exists, since marketplaces
 *         refresh tokens on ERC-4906 events. Records written before a mint
 *         are picked up when the token mints. The event is left to the
 *         token contract so this can sit next to an ERC-4906
 *         implementation that already declares it.
 *
 *         The token contract that inherits this must decide who the admin
 *         is in `_isMetadataAdmin`, name a token's holder in
 *         `_metadataHolderOf`, emit ERC-4906 in `_emitMetadataUpdate`, and
 *         return true from `supportsInterface` for IERC8048Metadata.
 */
abstract contract ERC8048OnchainMetadata is IERC8048Metadata {
    /// @dev The collection authority and its two settings, in one slot.
    struct CollectionAuthority {
        address authority;
        bool holderCanWrite;
        bool authorityLocked;
    }

    /// @dev Each token's values, by key.
    mapping(uint256 => mapping(string => bytes)) private _metadata;

    /// @dev The collection authority and its settings.
    CollectionAuthority private _collectionAuthority;

    /// @notice Emitted when the collection authority or its settings
    ///         change. `authority` is the zero address when blank.
    event CollectionAuthorityUpdated(
        address indexed authority,
        bool holderCanWrite,
        bool authorityLocked
    );

    /// @notice Revert when the caller can't write `tokenId`'s metadata.
    error MetadataWriteUnauthorized(uint256 tokenId);

    /// @notice Revert when the caller is neither the admin nor the
    ///         collection authority.
    error CollectionAuthorityUnauthorized();

    /// @notice Revert when the admin changes the settings after the
    ///         authority was locked.
    error CollectionAuthorityIsLocked();

    /// @notice Revert when locking a blank collection authority.
    error CannotLockBlankAuthority();

    /// @notice Revert when a batch's arrays differ in length.
    error MetadataBatchLengthMismatch();

    /**
     * @notice Returns the value of `key` for `tokenId`, or empty bytes when
     *         none is set.
     */
    function metadata(uint256 tokenId, string calldata key)
        external
        view
        returns (bytes memory)
    {
        return _metadata[tokenId][key];
    }

    /**
     * @notice Returns the collection authority and its settings.
     *
     * @return authority       The authority, or the zero address when blank,
     *                         which means the admin.
     * @return holderCanWrite  Whether a token's holder can write its
     *                         metadata.
     * @return authorityLocked Whether the admin can no longer change these.
     */
    function collectionAuthority()
        external
        view
        returns (address authority, bool holderCanWrite, bool authorityLocked)
    {
        CollectionAuthority memory settings = _collectionAuthority;
        return (
            settings.authority,
            settings.holderCanWrite,
            settings.authorityLocked
        );
    }

    /**
     * @notice Set `tokenId`'s value for `key`. An empty value clears it.
     *
     * @param tokenId The token id.
     * @param key     The key.
     * @param value   The value.
     */
    function setMetadata(
        uint256 tokenId,
        string calldata key,
        bytes calldata value
    ) external {
        _setMetadata(tokenId, key, value);
        _emitMetadataUpdate(tokenId);
    }

    /**
     * @notice Set `values[i]` for `keys[i]` on `tokenIds[i]`, each as
     *         `setMetadata` would. Any entry that fails reverts the batch.
     *         Consecutive entries for the same token emit one
     *         `MetadataUpdate`.
     *
     * @param tokenIds The token ids.
     * @param keys     The keys.
     * @param values   The values.
     */
    function setMetadataBatch(
        uint256[] calldata tokenIds,
        string[] calldata keys,
        bytes[] calldata values
    ) external {
        uint256 length = tokenIds.length;
        if (keys.length != length || values.length != length) {
            revert MetadataBatchLengthMismatch();
        }

        for (uint256 i = 0; i < length;) {
            uint256 tokenId = tokenIds[i];
            _setMetadata(tokenId, keys[i], values[i]);

            unchecked {
                ++i;
            }

            if (i == length || tokenIds[i] != tokenId) {
                _emitMetadataUpdate(tokenId);
            }
        }
    }

    /**
     * @notice Set the collection authority and its settings. The admin can
     *         call this until the authority is locked. The current
     *         authority can always call it.
     *
     * @param authority       The new authority, or the zero address for
     *                        the admin.
     * @param holderCanWrite  Whether a token's holder can write its
     *                        metadata.
     * @param authorityLocked Whether to stop the admin from changing these
     *                        again.
     */
    function setCollectionAuthority(
        address authority,
        bool holderCanWrite,
        bool authorityLocked
    ) external {
        if (!_isCollectionAuthority(msg.sender)) {
            if (!_isMetadataAdmin(msg.sender)) {
                revert CollectionAuthorityUnauthorized();
            }
            if (_collectionAuthority.authorityLocked) {
                revert CollectionAuthorityIsLocked();
            }
        }

        if (authorityLocked && authority == address(0)) {
            revert CannotLockBlankAuthority();
        }

        _collectionAuthority =
            CollectionAuthority(authority, holderCanWrite, authorityLocked);
        emit CollectionAuthorityUpdated(
            authority,
            holderCanWrite,
            authorityLocked
        );
    }

    /**
     * @dev Returns whether `account` is the collection authority, which is
     *      the admin while the authority is blank.
     */
    function _isCollectionAuthority(address account)
        internal
        view
        returns (bool)
    {
        address authority = _collectionAuthority.authority;
        if (authority == address(0)) return _isMetadataAdmin(account);
        return account == authority;
    }

    /**
     * @dev Store `value` for `key` on `tokenId` after checking the caller
     *      and emit `MetadataSet`.
     */
    function _setMetadata(
        uint256 tokenId,
        string calldata key,
        bytes calldata value
    ) internal {
        if (!_isCollectionAuthority(msg.sender)) {
            if (!_isHolderWriter(tokenId, msg.sender)) {
                revert MetadataWriteUnauthorized(tokenId);
            }
        }

        _metadata[tokenId][key] = value;
        emit MetadataSet(tokenId, key, key, value);
    }

    /**
     * @dev Returns whether holders can write and `account` holds `tokenId`
     *      now. A token that doesn't exist has no holder.
     */
    function _isHolderWriter(uint256 tokenId, address account)
        internal
        view
        returns (bool)
    {
        if (!_collectionAuthority.holderCanWrite) return false;

        address holder = _metadataHolderOf(tokenId);
        return holder != address(0) && account == holder;
    }

    /**
     * @dev Returns whether `account` is the metadata admin.
     */
    function _isMetadataAdmin(address account)
        internal
        view
        virtual
        returns (bool);

    /**
     * @dev Called after `tokenId`'s metadata changes. Emit ERC-4906
     *      `MetadataUpdate` here if the token exists.
     */
    function _emitMetadataUpdate(uint256 tokenId) internal virtual;

    /**
     * @dev Returns `tokenId`'s holder, or the zero address when the token
     *      does not exist.
     */
    function _metadataHolderOf(uint256 tokenId)
        internal
        view
        virtual
        returns (address);
}
