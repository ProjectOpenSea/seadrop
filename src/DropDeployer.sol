// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {Drop} from "./Drop.sol";

contract DropDeployer {
    function deployDrop(
        string calldata name,
        string calldata symbol,
        uint256 maxNumMintable
    ) public returns (Drop) {
        // return new Drop(name, symbol, maxNumMintable);
    }
}
