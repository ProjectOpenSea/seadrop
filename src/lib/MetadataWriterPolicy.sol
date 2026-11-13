// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

/// @dev The parts of an ERC8048OnchainMetadata token the policy calls.
interface IERC8048OnchainMetadataToken {
    function setMetadata(
        uint256 tokenId,
        string calldata key,
        bytes calldata value
    ) external;

    function setMetadataBatch(
        uint256[] calldata tokenIds,
        string[] calldata keys,
        bytes[] calldata values
    ) external;

    function metadata(uint256 tokenId, string calldata key)
        external
        view
        returns (bytes memory);

    function setCollectionAuthority(
        address authority,
        bool holderCanWrite,
        bool authorityLocked
    ) external;

    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title  MetadataWriterPolicy
 * @author Ryan Ghods (ralxz.eth)
 * @notice A reference policy to set as an ERC8048OnchainMetadata token's
 *         collection authority. It is an example; the token doesn't need
 *         it. Writes go through this contract, which forwards them to the
 *         token when:
 *
 *         - The caller is a writer its owner (the admin) allows, such as a
 *           hot wallet that runs a metadata job.
 *         - The caller is the address a token's current holder delegated
 *           that token's writes to, such as their agent's wallet. A
 *           delegation records the holder who set it and counts only while
 *           that address still holds the token, so it lapses on transfer.
 *           It counts again if the token comes back to that holder.
 *
 *         The admin can mark a key write-once. A write to a write-once key
 *         reverts when the token already has a non-empty value for it, so
 *         each token's value can be set once and never changed, while
 *         tokens minted later can still be written. The admin can unmark
 *         the key, so for a lasting freeze, lock the collection authority
 *         to this policy and renounce or hand off its ownership. Set it
 *         as the authority with `holderCanWrite` false, since holders
 *         writing the token directly skip this policy's rules.
 *
 *         The admin can also change the token's collection authority
 *         through this contract.
 */
contract MetadataWriterPolicy is TwoStepOwnable {
    /// @dev A token's delegate and the holder who set it.
    struct Delegation {
        address holder;
        address delegate;
    }

    /// @notice The token this policy writes to.
    IERC8048OnchainMetadataToken public immutable token;

    /// @dev The accounts the admin allows to write any token.
    mapping(address => bool) private _writers;

    /// @dev Each token's delegation.
    mapping(uint256 => Delegation) private _delegations;

    /// @dev The write-once keys, by the hash of the key.
    mapping(bytes32 => bool) private _writeOnceKeys;

    /// @notice Emitted when the admin allows or removes a writer.
    event WriterUpdated(address indexed writer, bool allowed);

    /// @notice Emitted when `holder` delegates `tokenId`'s writes to
    ///         `delegate`, or clears it with the zero address.
    event DelegateSet(
        uint256 indexed tokenId,
        address indexed holder,
        address indexed delegate
    );

    /// @notice Emitted when the admin marks or unmarks `key` write-once.
    event WriteOnceKeyUpdated(
        string indexed indexedKey,
        string key,
        bool writeOnce
    );

    /// @notice Revert when the caller can't write `tokenId`.
    error WriteUnauthorized(uint256 tokenId);

    /// @notice Revert when the caller doesn't hold `tokenId`.
    error NotTokenHolder(uint256 tokenId);

    /// @notice Revert when writing a write-once `key` that `tokenId`
    ///         already has a value for.
    error WriteOnceValueSet(uint256 tokenId, string key);

    /// @notice Revert when a batch's arrays differ in length.
    error BatchLengthMismatch();

    /**
     * @param token_ The token this policy writes to.
     */
    constructor(address token_) {
        token = IERC8048OnchainMetadataToken(token_);
    }

    /**
     * @notice Returns whether the admin allows `account` to write any
     *         token.
     */
    function isWriter(address account) external view returns (bool) {
        return _writers[account];
    }

    /**
     * @notice Returns whether `key` is write-once.
     */
    function isWriteOnceKey(string calldata key) external view returns (bool) {
        return _writeOnceKeys[keccak256(bytes(key))];
    }

    /**
     * @notice Returns the address `tokenId`'s current holder delegated its
     *         writes to, or the zero address when there is none or the
     *         holder who set it no longer holds the token.
     */
    function delegateOf(uint256 tokenId) public view returns (address) {
        Delegation memory delegation = _delegations[tokenId];
        if (delegation.holder != _holderOf(tokenId)) return address(0);
        return delegation.delegate;
    }

    /**
     * @notice Allow or remove a writer. Only the admin can call this.
     *
     * @param writer  The account.
     * @param allowed Whether the account can write any token.
     */
    function setWriter(address writer, bool allowed) external onlyOwner {
        _writers[writer] = allowed;
        emit WriterUpdated(writer, allowed);
    }

    /**
     * @notice Mark or unmark `key` write-once. Only the admin can call
     *         this.
     *
     * @param key       The key.
     * @param writeOnce Whether a token's non-empty value for the key can't
     *                  be overwritten.
     */
    function setWriteOnceKey(string calldata key, bool writeOnce)
        external
        onlyOwner
    {
        _writeOnceKeys[keccak256(bytes(key))] = writeOnce;
        emit WriteOnceKeyUpdated(key, key, writeOnce);
    }

    /**
     * @notice Delegate `tokenId`'s writes to `delegate`, or clear it with
     *         the zero address. Only the token's current holder can call
     *         this.
     *
     * @param tokenId  The token id.
     * @param delegate The address that can write the token.
     */
    function setDelegate(uint256 tokenId, address delegate) external {
        if (msg.sender != _holderOf(tokenId)) revert NotTokenHolder(tokenId);

        _delegations[tokenId] = Delegation(msg.sender, delegate);
        emit DelegateSet(tokenId, msg.sender, delegate);
    }

    /**
     * @notice Write `tokenId`'s value for `key` on the token.
     */
    function setMetadata(
        uint256 tokenId,
        string calldata key,
        bytes calldata value
    ) external {
        if (!_writers[msg.sender]) _checkDelegate(tokenId);
        _checkWriteOnce(tokenId, key);
        token.setMetadata(tokenId, key, value);
    }

    /**
     * @notice Write a batch on the token. The caller must be able to write
     *         every token in it, and each entry follows the write-once
     *         rule, counting earlier entries in the batch.
     */
    function setMetadataBatch(
        uint256[] calldata tokenIds,
        string[] calldata keys,
        bytes[] calldata values
    ) external {
        uint256 length = tokenIds.length;
        if (keys.length != length || values.length != length) {
            revert BatchLengthMismatch();
        }

        bool writer = _writers[msg.sender];
        for (uint256 i = 0; i < length; ++i) {
            uint256 tokenId = tokenIds[i];
            if (!writer) _checkDelegate(tokenId);

            bytes32 keyHash = keccak256(bytes(keys[i]));
            if (!_writeOnceKeys[keyHash]) continue;

            // The value on the token, or one an earlier entry in this batch
            // sets, makes the entry an overwrite.
            if (token.metadata(tokenId, keys[i]).length != 0) {
                revert WriteOnceValueSet(tokenId, keys[i]);
            }
            for (uint256 j = 0; j < i; ++j) {
                if (
                    tokenIds[j] == tokenId && values[j].length != 0
                        && keccak256(bytes(keys[j])) == keyHash
                ) {
                    revert WriteOnceValueSet(tokenId, keys[i]);
                }
            }
        }

        token.setMetadataBatch(tokenIds, keys, values);
    }

    /**
     * @notice Set the token's collection authority, for example to hand it
     *         to a new policy. Only the admin can call this.
     */
    function setCollectionAuthority(
        address authority,
        bool holderCanWrite,
        bool authorityLocked
    ) external onlyOwner {
        token.setCollectionAuthority(authority, holderCanWrite, authorityLocked);
    }

    /**
     * @notice Renounce ownership. This also cancels a pending ownership
     *         transfer, so the pending owner can't accept it and take back
     *         a policy that was renounced.
     */
    function renounceOwnership() public virtual override {
        cancelOwnershipTransfer();
        super.renounceOwnership();
    }

    /**
     * @dev Revert when `key` is write-once and `tokenId` already has a
     *      non-empty value for it on the token.
     */
    function _checkWriteOnce(uint256 tokenId, string calldata key)
        internal
        view
    {
        if (
            _writeOnceKeys[keccak256(bytes(key))]
                && token.metadata(tokenId, key).length != 0
        ) {
            revert WriteOnceValueSet(tokenId, key);
        }
    }

    /**
     * @dev Revert unless the caller is `tokenId`'s delegate.
     */
    function _checkDelegate(uint256 tokenId) internal view {
        address delegate = delegateOf(tokenId);
        if (delegate == address(0) || msg.sender != delegate) {
            revert WriteUnauthorized(tokenId);
        }
    }

    /**
     * @dev Returns `tokenId`'s holder, or the zero address when `ownerOf`
     *      reverts, as it does for a token that doesn't exist.
     */
    function _holderOf(uint256 tokenId) internal view returns (address) {
        try token.ownerOf(tokenId) returns (address holder) {
            return holder;
        } catch {
            return address(0);
        }
    }
}
