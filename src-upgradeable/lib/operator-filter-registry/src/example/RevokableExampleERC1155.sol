// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC1155} from "openzeppelin-contracts/token/ERC1155/ERC1155.sol";
import {UpdatableOperatorFilterer} from "../UpdatableOperatorFilterer.sol";
import {RevokableDefaultOperatorFilterer} from "../RevokableDefaultOperatorFilterer.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title  RevokableExampleERC1155
 * @notice This example contract is configured to use the RevokableDefaultOperatorFilterer, which automatically
 *         registers the token and subscribes it to OpenSea's curated filters. The owner of the contract can
 *         permanently revoke checks to the filter registry by calling revokeOperatorFilterRegistry.
 *         Adding the onlyAllowedOperator modifier to the safeTransferFrom methods ensures that
 *         the msg.sender (operator) is allowed by the OperatorFilterRegistry. Adding the onlyAllowedOperatorApproval
 *         modifier to the setApprovalForAll method ensures that owners do not approve operators that are not allowed.
 */
abstract contract RevokableExampleERC1155 is ERC1155(""), RevokableDefaultOperatorFilterer, Ownable {
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, uint256 amount, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function owner() public view virtual override (Ownable, UpdatableOperatorFilterer) returns (address) {
        return Ownable.owner();
    }
}
