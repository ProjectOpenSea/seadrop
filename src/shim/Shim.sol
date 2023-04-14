// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @dev HardHat doesn't support multiple source folders; so import everything
 * extra that hardhat tests rely on so they get compiled. Allows for faster
 * feedback than running an extra yarn build.
 */
import { MaliciousRecipient } from "../test/MaliciousRecipient.sol";

/**
 * @dev Use structs in an external function so typechain compiles them to use
 *      in HardHat tests.
 */
import {
    SeaDropStructsErrorsAndEvents
} from "../lib/SeaDropStructsErrorsAndEvents.sol";

contract Shim is SeaDropStructsErrorsAndEvents {
    function _shim(
        MintParams calldata mintParams,
        AllowListData calldata allowListData,
        TokenGatedMintParams calldata tokenGatedMintParams
    ) external {}
}
