// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title  IERC8451
 * @notice ERC-8451: Permanent Locks for Lockable Tokens, an extension of
 *         ERC-6982.
 *         The ERC-165 identifier for this interface is 0x9051c597.
 */
interface IERC8451 {
    /// @notice Emitted when every token in the contract becomes
    ///         permanently locked.
    event PermanentlyLocked();

    /// @notice Thrown when a holder transfer of a locked token is attempted.
    error TokenLocked(uint256 tokenId);

    /// @notice Returns true if every token in the contract is permanently
    ///         locked.
    function permanentlyLocked() external view returns (bool);
}
