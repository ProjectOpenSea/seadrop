// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title  IERC8048MetadataAuthority
 * @notice ERC-8048's optional Metadata Authority extension. While a token
 *         has an authority, only that authority can write its metadata.
 *         The ERC-165 identifier for this interface is 0xf9cb127d.
 */
interface IERC8048MetadataAuthority {
    /// @notice Emitted when `tokenId`'s metadata authority is set, changed,
    ///         or cleared. `authority` is the zero address when cleared.
    event MetadataAuthoritySet(
        uint256 indexed tokenId,
        address indexed authority
    );

    /// @notice Returns the metadata authority for `tokenId`, or the zero
    ///         address when none is set.
    function metadataAuthority(uint256 tokenId) external view returns (address);
}
