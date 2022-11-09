// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {OperatorFilterer721Upgradeable} from "./OperatorFilterer721Upgradeable.sol";

abstract contract DefaultOperatorFilterer721Upgradeable is OperatorFilterer721Upgradeable {
    address constant DEFAULT_SUBSCRIPTION = address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);

    function __DefaultOperatorFilterer721_init() public onlyInitializing {
        OperatorFilterer721Upgradeable.__OperatorFilterer721_init(DEFAULT_SUBSCRIPTION, true);
    }
}
