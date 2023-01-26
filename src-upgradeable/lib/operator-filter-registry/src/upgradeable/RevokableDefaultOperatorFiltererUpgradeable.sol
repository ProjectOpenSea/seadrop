// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RevokableOperatorFiltererUpgradeable} from "./RevokableOperatorFiltererUpgradeable.sol";

abstract contract RevokableDefaultOperatorFiltererUpgradeable is RevokableOperatorFiltererUpgradeable {
    address constant DEFAULT_SUBSCRIPTION = address(0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6);

    function __RevokableDefaultOperatorFilterer_init() internal onlyInitializing {
        RevokableOperatorFiltererUpgradeable.__RevokableOperatorFilterer_init(DEFAULT_SUBSCRIPTION, true);
    }
}
