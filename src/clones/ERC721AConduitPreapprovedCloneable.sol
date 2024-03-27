// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721ACloneable } from "./ERC721ACloneable.sol";

/**
 * @title  ERC721AConduitPreapprovedCloneable
 * @notice ERC721A with the OpenSea conduit preapproved.
 */
abstract contract ERC721AConduitPreapprovedCloneable is ERC721ACloneable {
    /// @dev The canonical OpenSea conduit.
    address internal constant _CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the
     *      assets of `owner`. Always returns true for the conduit.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        if (operator == _CONDUIT) {
            return true;
        }
        return ERC721ACloneable.isApprovedForAll(owner, operator);
    }
}
