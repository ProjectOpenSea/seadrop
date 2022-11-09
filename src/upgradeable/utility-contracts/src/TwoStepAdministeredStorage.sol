// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import { TwoStepAdministeredUpgradeable } from "./TwoStepAdministeredUpgradeable.sol";

library TwoStepAdministeredStorage {

  struct Layout {

    address administrator;
    address potentialAdministrator;
  
  }
  
  bytes32 internal constant STORAGE_SLOT = keccak256('openzepplin.contracts.storage.TwoStepAdministered');

  function layout() internal pure returns (Layout storage l) {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      l.slot := slot
    }
  }
}
    
