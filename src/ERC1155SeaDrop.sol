// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC1155SeaDropContractOfferer
} from "./lib/ERC1155SeaDropContractOfferer.sol";

import {
    DefaultOperatorFilterer
} from "operator-filter-registry/DefaultOperatorFilterer.sol";

import { ERC1155 } from "solady/src/tokens/ERC1155.sol";

/**
 * @title  ERC1155SeaDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice An ERC1155 token contract that can mint as a
 *         Seaport contract offerer.
 */
contract ERC1155SeaDrop is
    ERC1155SeaDropContractOfferer,
    DefaultOperatorFilterer
{
    /**
     * @notice Deploy the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          implementation code. Also contains SeaDrop
     *                          implementation code.
     * @param allowedConduit    The address of the conduit contract allowed to
     *                          interact.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     */
    constructor(
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport,
        string memory name_,
        string memory symbol_
    )
        ERC1155SeaDropContractOfferer(
            allowedConfigurer,
            allowedConduit,
            allowedSeaport,
            name_,
            symbol_
        )
    {}

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     *
     *      The added modifier ensures that the operator is allowed
     *      by the OperatorFilterRegistry.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public override onlyAllowedOperatorApproval(operator) {
        ERC1155.setApprovalForAll(operator, approved);
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     *
     *      The added modifier ensures that the operator is allowed
     *      by the OperatorFilterRegistry.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes calldata data
    ) public override onlyAllowedOperator(from) {
        ERC1155SeaDropContractOfferer.safeTransferFrom(
            from,
            to,
            tokenId,
            amount,
            data
        );
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     *
     *      The added modifier ensures that the operator is allowed
     *      by the OperatorFilterRegistry.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual override onlyAllowedOperator(from) {
        ERC1155._safeBatchTransfer(msg.sender, from, to, ids, amounts, data);
    }

    /**
     * @dev Auto-approve the conduit after mint or transfer.
     *
     * @custom:param from    The address to transfer from.
     * @param        to      The address to transfer to.
     * @custom:param ids     The token ids to transfer.
     * @custom:param amounts The quantities to transfer.
     * @custom:param data    The data to pass if receiver is a contract.
     */
    function _afterTokenTransfer(
        address /* from */,
        address to,
        uint256[] memory /* ids */,
        uint256[] memory /* amounts */,
        bytes memory /* data */
    ) internal virtual override {
        // Auto-approve the conduit.
        if (to != address(0) && !isApprovedForAll(to, _CONDUIT)) {
            _setApprovalForAll(to, _CONDUIT, true);
        }
    }

    /**
     * @dev Override this function to return true if `_afterTokenTransfer` is
     *      used. The is to help the compiler avoid producing dead bytecode.
     */
    function _useAfterTokenTransfer()
        internal
        view
        virtual
        override
        returns (bool)
    {
        return true;
    }

    /**
     * @notice Burns a token, restricted to the owner or approved operator,
     *         and must have sufficient balance.
     *
     * @param from   The address to burn from.
     * @param id     The token id to burn.
     * @param amount The amount to burn.
     */
    function burn(address from, uint256 id, uint256 amount) external {
        // Burn the token.
        _burn(msg.sender, from, id, amount);
    }

    /**
     * @notice Burns a batch of tokens, restricted to the owner or
     *         approved operator, and must have sufficient balance.
     *
     * @param from    The address to burn from.
     * @param ids     The token ids to burn.
     * @param amounts The amounts to burn per token id.
     */
    function batchBurn(
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external {
        // Burn the tokens.
        _batchBurn(msg.sender, from, ids, amounts);
    }
}
