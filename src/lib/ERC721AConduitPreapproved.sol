// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721A } from "ERC721A/ERC721A.sol";

/**
 * @title  ERC721AConduitPreapproved
 * @notice ERC721A with the OpenSea conduit preapproved.
 */
abstract contract ERC721AConduitPreapproved is ERC721A {
    /// @dev The canonical OpenSea conduit.
    address internal constant _CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /**
     * @notice Deploy the token contract.
     *
     * @param name              The name of the token.
     * @param symbol            The symbol of the token.
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC721A(name, symbol) {}

    /**
     * @dev Returns if the `operator` is allowed to manage all of the
     *      assets of `owner`. Always returns true for the conduit.
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
}