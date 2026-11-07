// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title  IERC6982
 * @notice ERC-6982: Efficient Default Lockable Tokens.
 *         The ERC-165 identifier for this interface is 0x6b61a747.
 */
interface IERC6982 {
    /**
     * @dev Emitted at deployment to set the default lock status of every
     *      token, and again whenever the default lock status changes.
     */
    event DefaultLocked(bool locked);

    /**
     * @dev Emitted when the lock status of a single token changes.
     *      This status overrides the default lock status for that token.
     */
    event Locked(uint256 indexed tokenId, bool locked);

    /**
     * @notice Returns the default lock status, which matches the most
     *         recent `DefaultLocked` event.
     */
    function defaultLocked() external view returns (bool);

    /**
     * @notice Returns the lock status of a token. Reverts if the token
     *         does not exist.
     *
     * @param tokenId The token id.
     */
    function locked(uint256 tokenId) external view returns (bool);
}
