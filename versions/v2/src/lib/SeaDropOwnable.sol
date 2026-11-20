// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Ownable } from "solady/src/auth/Ownable.sol";

/**
 * @title  SeaDropOwnable
 * @notice Solady's Ownable plus the public `ownershipHandoverValidFor()`
 *         getter, which solady made internal in v0.0.109. Keeping it leaves
 *         the token ABI unchanged for callers of the earlier releases.
 */
abstract contract SeaDropOwnable is Ownable {
    /**
     * @notice Returns how long a two-step ownership handover is valid for,
     *         in seconds.
     */
    function ownershipHandoverValidFor() public view virtual returns (uint64) {
        return _ownershipHandoverValidFor();
    }
}
