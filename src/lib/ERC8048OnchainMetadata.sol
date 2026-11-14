// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { IERC8048Metadata } from "../interfaces/IERC8048Metadata.sol";

import {
    IERC8048TokenMetadataAuthority
} from "../interfaces/IERC8048TokenMetadataAuthority.sol";

/**
 * @title  ERC8048OnchainMetadata
 * @author Ryan Ghods (ralxz.eth)
 * @notice Onchain metadata for ERC-721 tokens under ERC-8048: string keys
 *         with bytes values, stored per token, with ERC-8048's optional
 *         Metadata Authority extension.
 *
 *         The token metadata authority and three settings decide who
 *         writes:
 *         - While `tokenMetadataAuthority()` is set, it is the only address
 *           that can write, for every token, as ERC-8048 requires. It can
 *           be an account or a policy contract that applies its own rules,
 *           such as MetadataWriterPolicy. The settings below don't apply.
 *         - While the authority is blank (the zero address), the metadata
 *           admin (the owner) can write any token's metadata, unless
 *           `ownerCannotWrite` is on.
 *         - While the authority is blank and `holderCanWrite` is on, a
 *           token's current holder can also write that token's metadata.
 *           The check reads the holder at write time, so a new holder can
 *           write right after a transfer and the old holder can't.
 *         - With `authorityLocked`, the admin can no longer change the
 *           authority or the settings. A nonzero authority still can, so a
 *           locked policy contract can hand itself on. A locked blank
 *           authority fixes the settings for good: nobody can change them
 *           or set a policy later.
 *
 *         The settings all start false, so a new collection starts with
 *         the admin as the only writer. Tokens don't have to exist yet, so
 *         the admin or the authority can write metadata before a mint.
 *
 *         The module has no key locks. A policy contract can freeze
 *         records per token, for example with a write-once rule. To freeze
 *         every record, lock a blank authority with `ownerCannotWrite` on
 *         and `holderCanWrite` off.
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
 *         return true from `supportsInterface` for IERC8048Metadata and
 *         IERC8048TokenMetadataAuthority.
 */
abstract contract ERC8048OnchainMetadata is
    IERC8048Metadata,
    IERC8048TokenMetadataAuthority
{
    /// @dev The authority and its three settings, in one slot.
    struct CollectionAuthority {
        address authority;
        bool holderCanWrite;
        bool ownerCannotWrite;
        bool authorityLocked;
    }

    /// @dev Each token's values, by key.
    mapping(uint256 => mapping(string => bytes)) private _metadata;

    /// @dev The authority and its settings.
    CollectionAuthority private _collectionAuthority;

    /// @notice Emitted when the settings are set, with the values they
    ///         now hold.
    event CollectionAuthoritySettingsUpdated(
        bool holderCanWrite,
        bool ownerCannotWrite,
        bool authorityLocked
    );

    /// @notice Revert when the caller can't write `tokenId`'s metadata.
    error MetadataWriteUnauthorized(uint256 tokenId);

    /// @notice Revert when the caller is neither the admin nor a nonzero
    ///         authority.
    error CollectionAuthorityUnauthorized();

    /// @notice Revert when the admin changes the settings after they were
    ///         locked.
    error CollectionAuthorityIsLocked();

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
     * @notice Returns the metadata authority for every token, or the zero
     *         address when none is set and the settings decide who writes.
     */
    function tokenMetadataAuthority() external view returns (address) {
        return _collectionAuthority.authority;
    }

    /**
     * @notice Returns the settings that apply while the authority is
     *         blank, and whether they are locked.
     *
     * @return holderCanWrite   Whether a token's holder can write its
     *                          metadata.
     * @return ownerCannotWrite Whether the admin is shut out of writing.
     * @return authorityLocked  Whether only a nonzero authority can change
     *                          the authority or the settings.
     */
    function collectionAuthoritySettings()
        external
        view
        returns (
            bool holderCanWrite,
            bool ownerCannotWrite,
            bool authorityLocked
        )
    {
        CollectionAuthority memory settings = _collectionAuthority;
        return (
            settings.holderCanWrite,
            settings.ownerCannotWrite,
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
     * @notice Set the authority and its settings. A nonzero authority can
     *         always call this. The admin can call it until the settings
     *         are locked, including while it writes as the blank
     *         authority. Emits `TokenMetadataAuthoritySet` when the
     *         authority changes.
     *
     * @param authority        The new authority, or the zero address to
     *                         let the settings decide who writes.
     * @param holderCanWrite   Whether a token's holder can write its
     *                         metadata while the authority is blank.
     * @param ownerCannotWrite Whether to shut the admin out of writing
     *                         while the authority is blank.
     * @param authorityLocked  Whether to stop the admin from changing
     *                         these again. With a blank authority, nobody
     *                         can change them again.
     */
    function setCollectionAuthority(
        address authority,
        bool holderCanWrite,
        bool ownerCannotWrite,
        bool authorityLocked
    ) external {
        CollectionAuthority memory current = _collectionAuthority;
        if (current.authority == address(0) || msg.sender != current.authority)
        {
            if (!_isMetadataAdmin(msg.sender)) {
                revert CollectionAuthorityUnauthorized();
            }
            if (current.authorityLocked) {
                revert CollectionAuthorityIsLocked();
            }
        }

        _collectionAuthority = CollectionAuthority(
            authority, holderCanWrite, ownerCannotWrite, authorityLocked
        );
        if (authority != current.authority) {
            emit TokenMetadataAuthoritySet(authority);
        }
        emit CollectionAuthoritySettingsUpdated(
            holderCanWrite,
            ownerCannotWrite,
            authorityLocked
        );
    }

    /**
     * @dev Returns whether `account` can write any token: the authority
     *      while one is set, otherwise the admin unless `ownerCannotWrite`
     *      is on.
     */
    function _isCollectionWriter(address account) internal view returns (bool) {
        CollectionAuthority memory settings = _collectionAuthority;
        if (settings.authority != address(0)) {
            return account == settings.authority;
        }
        return !settings.ownerCannotWrite && _isMetadataAdmin(account);
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
        if (!_isCollectionWriter(msg.sender)) {
            if (!_isHolderWriter(tokenId, msg.sender)) {
                revert MetadataWriteUnauthorized(tokenId);
            }
        }

        _metadata[tokenId][key] = value;
        emit MetadataSet(tokenId, key, key, value);
    }

    /**
     * @dev Returns whether the authority is blank, holders can write, and
     *      `account` holds `tokenId` now. A token that doesn't exist has no
     *      holder.
     */
    function _isHolderWriter(uint256 tokenId, address account)
        internal
        view
        returns (bool)
    {
        CollectionAuthority memory settings = _collectionAuthority;
        if (settings.authority != address(0) || !settings.holderCanWrite) {
            return false;
        }

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
