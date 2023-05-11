// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC1155SeaDropContractOfferer
} from "./lib/ERC1155SeaDropContractOfferer.sol";

import {
    DefaultOperatorFilterer
} from "operator-filter-registry/DefaultOperatorFilterer.sol";

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
     *                          configure parameters.
     * @param allowedConduit    The address of the conduit contract allowed to
     *                          interact.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     */
    constructor(
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport
    )
        ERC1155SeaDropContractOfferer(
            allowedConfigurer,
            allowedConduit,
            allowedSeaport
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
        super.setApprovalForAll(operator, approved);
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
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, amount, data);
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
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @notice Burns a token, restricted to the owner or approved operator.
     *
     * @param id The token id to burn.
     */
    function burn(address from, uint256 id, uint256 amount) internal virtual {
        // Require that only the owner or approved operator can call.
        if (
            _cast(msg.sender != from && !isApprovedForAll[from][msg.sender]) ==
            1
        ) {
            revert NotAuthorized();
        }

        // Ensure the balance is sufficient.
        if (balanceOf(from, id) < amount) {
            revert InsufficientBalance(id);
        }

        // Subtract from the total supply for the token ID.
        _totalSupply[id] -= amount;

        // Burn the token.
        _burn(from, id, amount);
    }

    /**
     * @notice Burns a batch of tokens, restricted to the owner or approved operator.
     *
     * @param from The address to burn from.
     * @param ids  The token IDs to burn.
     * @param amounts The amounts to burn per token ID.
     */
    function batchBurn(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        // Require that only the owner or approved operator can call.
        if (
            _cast(msg.sender != from && !isApprovedForAll[from][msg.sender]) ==
            1
        ) {
            revert NotAuthorized();
        }

        // Ensure the balances are sufficient.
        uint256 idsLength = ids.length;
        uint256 balances = balanceOfBatch(from, ids);
        for (uint256 i = 0; i < idsLength; ) {
            if (balances[i] < amounts[i]) {
                revert InsufficientBalance(id);
            }

            // Subtract from the total supply for the token ID.
            _totalSupply[ids[i]] -= amounts[i];

            unchecked {
                ++i;
            }
        }

        // Burn the tokens.
        _batchBurn(from, ids, amounts);
    }
}
