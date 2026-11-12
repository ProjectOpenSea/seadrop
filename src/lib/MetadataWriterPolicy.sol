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

    function lockMetadataKey(string calldata key) external;

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
 *         The admin can also lock a key and change the token's collection
 *         authority through this contract.
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

    /// @notice Emitted when the admin allows or removes a writer.
    event WriterUpdated(address indexed writer, bool allowed);

    /// @notice Emitted when `holder` delegates `tokenId`'s writes to
    ///         `delegate`, or clears it with the zero address.
    event DelegateSet(
        uint256 indexed tokenId,
        address indexed holder,
        address indexed delegate
    );

    /// @notice Revert when the caller can't write `tokenId`.
    error WriteUnauthorized(uint256 tokenId);

    /// @notice Revert when the caller doesn't hold `tokenId`.
    error NotTokenHolder(uint256 tokenId);

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
        _checkWriter(tokenId);
        token.setMetadata(tokenId, key, value);
    }

    /**
     * @notice Write a batch on the token. The caller must be able to write
     *         every token in it.
     */
    function setMetadataBatch(
        uint256[] calldata tokenIds,
        string[] calldata keys,
        bytes[] calldata values
    ) external {
        if (!_writers[msg.sender]) {
            for (uint256 i = 0; i < tokenIds.length; ++i) {
                _checkDelegate(tokenIds[i]);
            }
        }
        token.setMetadataBatch(tokenIds, keys, values);
    }

    /**
     * @notice Lock `key` on the token. Only the admin can call this.
     */
    function lockMetadataKey(string calldata key) external onlyOwner {
        token.lockMetadataKey(key);
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
     * @dev Revert unless the caller is a writer or `tokenId`'s delegate.
     */
    function _checkWriter(uint256 tokenId) internal view {
        if (!_writers[msg.sender]) _checkDelegate(tokenId);
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
