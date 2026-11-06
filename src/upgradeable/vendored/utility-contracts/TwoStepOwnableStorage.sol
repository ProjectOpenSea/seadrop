// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import { TwoStepOwnableUpgradeable } from "./TwoStepOwnableUpgradeable.sol";

library TwoStepOwnableStorage {

  struct Layout {
    address _owner;

    address potentialOwner;
  
  }
  
  bytes32 internal constant STORAGE_SLOT = keccak256('openzepplin.contracts.storage.TwoStepOwnable');

  function layout() internal pure returns (Layout storage l) {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      l.slot := slot
    }
  }
}
    
