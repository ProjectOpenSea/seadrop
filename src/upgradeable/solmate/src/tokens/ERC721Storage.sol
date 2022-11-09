// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import { ERC721Upgradeable } from "./ERC721Upgradeable.sol";

library ERC721Storage {

  struct Layout {
    //////////////////////////////////////////////////////////////*/

    string name;

    string symbol;
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) _ownerOf;

    mapping(address => uint256) _balanceOf;
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => address) getApproved;

    mapping(address => mapping(address => bool)) isApprovedForAll;
  
  }
  
  bytes32 internal constant STORAGE_SLOT = keccak256('openzepplin.contracts.storage.ERC721');

  function layout() internal pure returns (Layout storage l) {
    bytes32 slot = STORAGE_SLOT;
    assembly {
      l.slot := slot
    }
  }
}
    
