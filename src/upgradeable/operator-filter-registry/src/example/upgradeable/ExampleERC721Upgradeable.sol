// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {DefaultOperatorFilterer721Upgradeable} from "./DefaultOperatorFilterer721Upgradeable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title  ExampleERC721Upgradeable
 * @notice This example contract is configured to use the DefaultOperatorFilterer, which automatically registers the
 *         token and subscribes it to OpenSea's curated filters.
 *         Adding the onlyAllowedOperator modifier to the transferFrom and both safeTransferFrom methods ensures that
 *         the msg.sender (operator) is allowed by the OperatorFilterRegistry.
 */
abstract contract ExampleERC721Upgradeable is
    ERC721Upgradeable,
    DefaultOperatorFilterer721Upgradeable,
    OwnableUpgradeable
{
    function initialize() public initializer {
        __ERC721_init("Example", "EXAMPLE");
        __Ownable_init();
        __DefaultOperatorFilterer721_init();
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

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}
