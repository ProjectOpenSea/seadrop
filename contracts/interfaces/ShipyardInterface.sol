// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title ShipyardInterface
 *
 * @dev ShipyardInterface contains all external function interfaces for Shipyard
 *      sample contract
 *
 * @notice Shipyard is a template repo for OpenSea contract development based on
 *         the Seaport repo
 */
interface ShipyardInterface {
    /**
     * @notice Sample function returning a greeting
     *
     * @return greeting A greeting from the shipyard
     */
    function greet() external view returns (string memory greeting);
}
