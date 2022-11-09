// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OperatorFilterer721} from "./OperatorFilterer721.sol";

abstract contract DefaultOperatorFilterer721 is OperatorFilterer721 {
    address constant DEFAULT_SUBSCRIPTION = address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);

    constructor() OperatorFilterer721(DEFAULT_SUBSCRIPTION, true) {}
}
