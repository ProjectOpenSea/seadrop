// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @dev Use structs in an external function so typechain compiles them to use
 *      in HardHat tests.
 */
import { MintParams } from "../lib/ERC1155SeaDropStructs.sol";

contract Shim2 {
    function _shim(MintParams calldata mintParams) external {}
}
