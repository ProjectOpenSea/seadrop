// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title  IERC8048Metadata
 * @notice ERC-8048: Onchain Metadata for Token Registries (draft). String
 *         keys with bytes values, stored per token.
 *         The ERC-165 identifier for this interface is 0xdf670be1.
 */
interface IERC8048Metadata {
    /// @notice Emitted when a token's value for `key` is set.
    event MetadataSet(
        uint256 indexed tokenId,
        string indexed indexedKey,
        string key,
        bytes value
    );

    /// @notice Returns the value of `key` for `tokenId`, or empty bytes
    ///         when none is set.
    function metadata(uint256 tokenId, string calldata key)
        external
        view
        returns (bytes memory);
}
