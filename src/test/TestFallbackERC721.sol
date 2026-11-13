// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { TestMinimalERC721 } from "./TestMinimalERC721.sol";

/// @notice An existing ERC-721 whose fallback accepts any call, such as a
///         proxy without EIP-2981.
contract TestFallbackERC721 is TestMinimalERC721 {
    fallback() external { }
}
