// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ITransferValidator {
    /// @notice Ensure that a transfer has been authorized for a specific tokenId.
    function validateTransfer(
        address caller,
        address from,
        address to,
        uint256 tokenId
    ) external view;

    /// @notice Ensure that a transfer has been authorized for a specific amount of
    //          a specific tokenId, and reduce the transferable amount remaining.
    function validateTransfer(
        address caller,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external;
}
