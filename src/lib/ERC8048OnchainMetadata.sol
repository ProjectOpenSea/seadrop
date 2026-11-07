// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { IERC8048Metadata } from "../interfaces/IERC8048Metadata.sol";

import {
    IERC8048MetadataAuthority
} from "../interfaces/IERC8048MetadataAuthority.sol";

/**
 * @title  ERC8048OnchainMetadata
 * @author Ryan Ghods (ralxz.eth)
 * @notice Onchain metadata for ERC-721 tokens under ERC-8048: string keys
 *         with bytes values, stored per token, with ERC-8048's Metadata
 *         Authority extension.
 *
 *         Who can write a token's metadata:
 *         - While the token has no metadata authority, the contract's
 *           metadata admin (the owner) and the metadata writers the admin
 *           allows. A writer can write metadata and nothing else, so a hot
 *           wallet can run a metadata job. Tokens don't have to exist yet,
 *           so metadata can be in place before a mint.
 *         - While the token has a metadata authority, only that authority.
 *
 *         The token's holder can set, change, or clear its metadata
 *         authority at any time, and the current authority can hand it to
 *         another address or clear it. The admin can't set one. A holder
 *         sets themself, or an agent's wallet, as the authority to take
 *         over their token's records.
 *
 *         The admin can lock a key for good. After that, nobody can write
 *         that key for any token, authorities included.
 *
 *         Each write emits `MetadataSet`, and ERC-4906 `MetadataUpdate`
 *         for a token that exists, since marketplaces refresh tokens on
 *         ERC-4906 events. Records written before a mint are picked up
 *         when the token mints.
 *
 *         The token contract that inherits this must decide who the admin
 *         is in `_isMetadataAdmin`, say whether a token exists in
 *         `_metadataTokenExists`, name a token's holder in
 *         `_metadataHolderOf`, call `_clearMetadataAuthority` when a token
 *         is transferred or burned, and return true from
 *         `supportsInterface` for IERC8048Metadata and
 *         IERC8048MetadataAuthority.
 */
abstract contract ERC8048OnchainMetadata is
    IERC8048Metadata,
    IERC8048MetadataAuthority
{
    /// @dev Each token's values, by key.
    mapping(uint256 => mapping(string => bytes)) private _metadata;

    /// @dev Each token's metadata authority, or the zero address.
    mapping(uint256 => address) private _metadataAuthorities;

    /// @dev The accounts the admin allows to write metadata.
    mapping(address => bool) private _metadataWriters;

    /// @dev The locked keys, by the hash of the key.
    mapping(bytes32 => bool) private _lockedMetadataKeys;

    /// @notice Emitted when a token's metadata changes (ERC-4906).
    event MetadataUpdate(uint256 _tokenId);

    /// @notice Emitted when the admin allows or removes a metadata writer.
    event MetadataWriterUpdated(address indexed writer, bool allowed);

    /// @notice Emitted when the admin locks `key` for good.
    event MetadataKeyLocked(string indexed indexedKey, string key);

    /// @notice Revert when the caller can't write `tokenId`'s metadata.
    error MetadataWriteUnauthorized(uint256 tokenId);

    /// @notice Revert when the caller can't set `tokenId`'s metadata
    ///         authority.
    error MetadataAuthorityUnauthorized(uint256 tokenId);

    /// @notice Revert when the caller is not the metadata admin.
    error MetadataAdminOnly();

    /// @notice Revert when writing or locking a key that is locked.
    error MetadataKeyIsLocked(string key);

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
     * @notice Returns the metadata authority for `tokenId`, or the zero
     *         address when none is set.
     */
    function metadataAuthority(uint256 tokenId)
        external
        view
        returns (address)
    {
        return _metadataAuthorities[tokenId];
    }

    /**
     * @notice Returns whether the admin allows `account` to write metadata.
     */
    function isMetadataWriter(address account) external view returns (bool) {
        return _metadataWriters[account];
    }

    /**
     * @notice Returns whether `key` is locked for good.
     */
    function metadataKeyLocked(string calldata key)
        external
        view
        returns (bool)
    {
        return _lockedMetadataKeys[keccak256(bytes(key))];
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
     *         `setMetadata` would. Any entry that fails reverts the batch,
     *         so leave out tokens whose holder has set a metadata authority.
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
     * @notice Set, change, or clear `tokenId`'s metadata authority. The
     *         token's holder can always call this. The current authority
     *         can hand the role to another address or clear it.
     *
     * @param tokenId      The token id.
     * @param newAuthority The new authority, or the zero address to clear
     *                     it.
     */
    function setMetadataAuthority(uint256 tokenId, address newAuthority)
        external
    {
        address authority = _metadataAuthorities[tokenId];

        if (msg.sender != authority || authority == address(0)) {
            address holder = _metadataHolderOf(tokenId);
            if (msg.sender != holder || holder == address(0)) {
                revert MetadataAuthorityUnauthorized(tokenId);
            }
        }

        _metadataAuthorities[tokenId] = newAuthority;
        emit MetadataAuthoritySet(tokenId, newAuthority);
    }

    /**
     * @notice Allow or remove a metadata writer. Only the admin can call
     *         this.
     *
     * @param writer  The account.
     * @param allowed Whether the account can write metadata.
     */
    function setMetadataWriter(address writer, bool allowed) external {
        if (!_isMetadataAdmin(msg.sender)) revert MetadataAdminOnly();

        _metadataWriters[writer] = allowed;
        emit MetadataWriterUpdated(writer, allowed);
    }

    /**
     * @notice Lock `key` for every token, for good. Only the admin can call
     *         this.
     *
     * @param key The key.
     */
    function lockMetadataKey(string calldata key) external {
        if (!_isMetadataAdmin(msg.sender)) revert MetadataAdminOnly();

        bytes32 keyHash = keccak256(bytes(key));
        if (_lockedMetadataKeys[keyHash]) revert MetadataKeyIsLocked(key);

        _lockedMetadataKeys[keyHash] = true;
        emit MetadataKeyLocked(key, key);
    }

    /**
     * @dev Clear `tokenId`'s metadata authority, if it has one. The token
     *      contract calls this when the token is transferred or burned, so
     *      an authority set under one holder never carries over to the
     *      next.
     */
    function _clearMetadataAuthority(uint256 tokenId) internal {
        if (_metadataAuthorities[tokenId] != address(0)) {
            delete _metadataAuthorities[tokenId];
            emit MetadataAuthoritySet(tokenId, address(0));
        }
    }

    /**
     * @dev Emit ERC-4906 `MetadataUpdate` for `tokenId` if it exists.
     */
    function _emitMetadataUpdate(uint256 tokenId) internal {
        if (_metadataTokenExists(tokenId)) {
            emit MetadataUpdate(tokenId);
        }
    }

    /**
     * @dev Store `value` for `key` on `tokenId` after checking the caller
     *      and the lock, and emit `MetadataSet`.
     */
    function _setMetadata(
        uint256 tokenId,
        string calldata key,
        bytes calldata value
    ) internal {
        address authority = _metadataAuthorities[tokenId];

        if (authority == address(0)) {
            if (!_metadataWriters[msg.sender] && !_isMetadataAdmin(msg.sender))
            {
                revert MetadataWriteUnauthorized(tokenId);
            }
        } else if (msg.sender != authority) {
            revert MetadataWriteUnauthorized(tokenId);
        }

        if (_lockedMetadataKeys[keccak256(bytes(key))]) {
            revert MetadataKeyIsLocked(key);
        }

        _metadata[tokenId][key] = value;
        emit MetadataSet(tokenId, key, key, value);
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
     * @dev Returns whether `tokenId` exists.
     */
    function _metadataTokenExists(uint256 tokenId)
        internal
        view
        virtual
        returns (bool);

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
