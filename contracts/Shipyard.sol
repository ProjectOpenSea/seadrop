// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ShipyardInterface } from "./interfaces/ShipyardInterface.sol";

/**
 * @title Shipyard
 * @notice Shipyard is a template repo for OpenSea contract development based on
 *         the Seaport repo
 */
contract Shipyard is ShipyardInterface {
    /**
     * @notice Empty constructor
     *
     */
    constructor() {}

    /**
     * @dev Sample function returning a greeting
     *
     * @return A greeting
     */
    function greet() public pure override returns (string memory) {
        return "Ahoy";
    }
}
