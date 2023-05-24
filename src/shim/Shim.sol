// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @dev HardHat doesn't support multiple source folders; so import everything
 * extra that hardhat tests rely on so they get compiled. Allows for faster
 * feedback than running an extra yarn build.
 */
import { MaliciousRecipient } from "../test/MaliciousRecipient.sol";
import { Shim2 } from "./Shim2.sol";

/**
 * @dev Use structs in an external function so typechain compiles them to use
 *      in HardHat tests.
 */
import { MintParams } from "../lib/ERC721SeaDropStructs.sol";

import { AllowListData } from "../lib/SeaDropStructs.sol";

contract Shim {
    function _shim(
        MintParams calldata mintParams,
        AllowListData calldata allowListData
    ) external {}
}
