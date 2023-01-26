// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import { ERC20Upgradeable } from "./ERC20Upgradeable.sol";

library ERC20Storage {

  struct Layout {
    //////////////////////////////////////////////////////////////*/

    string name;

    string symbol;

    uint8 decimals;
    //////////////////////////////////////////////////////////////*/

    uint256 totalSupply;

    mapping(address => uint256) balanceOf;

    mapping(address => mapping(address => uint256)) allowance;
    //////////////////////////////////////////////////////////////*/

    uint256 INITIAL_CHAIN_ID;

    bytes32 INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) nonces;
  
  }
  
  bytes32 internal constant STORAGE_SLOT = keccak256('openzepplin.contracts.storage.ERC20');

  function layout() internal pure returns (Layout storage l) {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      l.slot := slot
    }
  }
}
    
