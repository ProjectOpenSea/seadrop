// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1155 } from "solady/src/tokens/ERC1155.sol";

/**
 * @title  ERC1155ConduitPreapproved
 * @notice Solady's ERC1155 with the OpenSea conduit preapproved.
 */
abstract contract ERC1155ConduitPreapproved is ERC1155 {
    /// @dev The canonical OpenSea conduit.
    address internal constant _CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public virtual override {
        _safeTransfer(_by(), from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual override {
        _safeBatchTransfer(_by(), from, to, ids, amounts, data);
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override returns (bool) {
        if (operator == _CONDUIT) return true;
        return ERC1155.isApprovedForAll(owner, operator);
    }

    function _by() internal view returns (address result) {
        assembly {
            // `msg.sender == _CONDUIT ? address(0) : msg.sender`.
            result := mul(iszero(eq(caller(), _CONDUIT)), caller())
        }
    }
}
