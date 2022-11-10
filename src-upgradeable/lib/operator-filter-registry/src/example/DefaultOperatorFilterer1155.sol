// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OperatorFilterer1155} from "./OperatorFilterer1155.sol";

abstract contract DefaultOperatorFilterer1155 is OperatorFilterer1155 {
    address constant DEFAULT_SUBSCRIPTION = address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);

    constructor() OperatorFilterer1155(DEFAULT_SUBSCRIPTION, true) {}
}
