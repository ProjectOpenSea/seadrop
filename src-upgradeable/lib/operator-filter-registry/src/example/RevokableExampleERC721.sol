// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721} from "openzeppelin-contracts/token/ERC721/ERC721.sol";
import {UpdatableOperatorFilterer} from "../UpdatableOperatorFilterer.sol";
import {RevokableDefaultOperatorFilterer} from "../RevokableDefaultOperatorFilterer.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/**
 * @title  ExampleERC721
 * @notice This example contract is configured to use the RevokableDefaultOperatorFilterer, which automatically
 *         registers the token and subscribes it to OpenSea's curated filters. The owner of the contract can
 *         permanently revoke checks to the filter registry by calling revokeOperatorFilterRegistry.
 *         Adding the onlyAllowedOperator modifier to the transferFrom and both safeTransferFrom methods ensures that
 *         the msg.sender (operator) is allowed by the OperatorFilterRegistry. Adding the onlyAllowedOperatorApproval
 *         modifier to the approval methods ensures that owners do not approve operators that are not allowed.
 */
abstract contract RevokableExampleERC721 is ERC721("Example", "EXAMPLE"), RevokableDefaultOperatorFilterer, Ownable {
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    function owner() public view virtual override (Ownable, UpdatableOperatorFilterer) returns (address) {
        return Ownable.owner();
    }
}
