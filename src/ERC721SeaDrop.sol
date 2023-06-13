// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC721SeaDropContractOfferer
} from "./lib/ERC721SeaDropContractOfferer.sol";

import {
    DefaultOperatorFilterer
} from "operator-filter-registry/DefaultOperatorFilterer.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

/**
 * @title  ERC721SeaDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice An ERC721 token contract based on ERC721A that can mint as a
 *         Seaport contract offerer.
 */
contract ERC721SeaDrop is
    ERC721SeaDropContractOfferer,
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
     * @param name              The name of the token.
     * @param symbol            The symbol of the token.
     */
    constructor(
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport,
        string memory name,
        string memory symbol
    )
        ERC721SeaDropContractOfferer(
            allowedConfigurer,
            allowedConduit,
            allowedSeaport,
            name,
            symbol
        )
    {}

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     * - The `operator` must be allowed.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public override onlyAllowedOperatorApproval(operator) {
        ERC721A.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     * - The `operator` mut be allowed.
     *
     * Emits an {Approval} event.
     */
    function approve(
        address operator,
        uint256 tokenId
    ) public payable override onlyAllowedOperatorApproval(operator) {
        ERC721A.approve(operator, tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - The operator must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override onlyAllowedOperator(from) {
        ERC721A.transferFrom(from, to, tokenId);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override onlyAllowedOperator(from) {
        ERC721A.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     * - The operator must be allowed.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable override onlyAllowedOperator(from) {
        ERC721A.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *      Always returns true for the conduit.
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override returns (bool) {
        if (operator == _CONDUIT) {
            return true;
        }
        return ERC721A.isApprovedForAll(owner, operator);
    }

    /**
     * @notice Withdraws contract balance to the contract owner.
     *         Provided as a safety measure to rescue stuck funds since ERC721A
     *         makes all methods payable for gas efficiency reasons.
     *
     *         Only the owner can use this function.
     */
    function withdraw() external {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Put the balance on the stack.
        uint256 balance = address(this).balance;

        // Revert if the contract has no balance.
        if (balance == 0) {
            revert NoBalanceToWithdraw();
        }

        // Send contract balance to the owner.
        (bool success, bytes memory data) = payable(owner()).call{
            value: balance
        }("");

        // Require that the call was successful.
        if (!success) {
            // Bubble up the revert reason.
            assembly {
                revert(add(32, data), mload(data))
            }
        }
    }

    /**
     * @notice Burns `tokenId`. The caller must own `tokenId` or be an
     *         approved operator.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external {
        // Passing `true` to `_burn()` checks that the caller owns the token
        // or is an approved operator.
        _burn(tokenId, true);
    }
}
