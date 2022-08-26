// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @dev HardHat doesn't support multiple source folders; so import everything
 * extra that reference tests rely on so they get compiled. Allows for faster
 * feedback than running an extra yarn build
 */
import { ERC721 } from "solmate/tokens/ERC721.sol";
import { TestERC721 } from "seadrop/test/TestERC721.sol";
