// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title  IERC8048TokenMetadataAuthority
 * @notice ERC-8048's optional Metadata Authority extension (draft). One
 *         metadata authority for every token in the collection. While it
 *         is set, it is the only address that can write metadata. While
 *         it is the zero address, the contract's own write policy applies.
 *         The ERC-165 identifier for this interface is 0x04f90b41.
 */
interface IERC8048TokenMetadataAuthority {
    /// @notice Emitted when the metadata authority is set, changed, or
    ///         cleared. `authority` is the zero address when cleared.
    event TokenMetadataAuthoritySet(address indexed authority);

    /// @notice Returns the metadata authority for every token, or the
    ///         zero address when none is set.
    function tokenMetadataAuthority() external view returns (address);
}
