// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OperatorFilterer1155Upgradeable} from "./OperatorFilterer1155Upgradeable.sol";

abstract contract DefaultOperatorFilterer1155Upgradeable is OperatorFilterer1155Upgradeable {
    address constant DEFAULT_SUBSCRIPTION = address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);

    function __DefaultOperatorFilterer1155_init() public onlyInitializing {
        OperatorFilterer1155Upgradeable.__OperatorFilterer1155_init(DEFAULT_SUBSCRIPTION, true);
    }
}
