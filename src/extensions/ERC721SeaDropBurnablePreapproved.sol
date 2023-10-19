// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

/**
 * @title  ERC721SeaDropBurnablePreapproved
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice ERC721SeaDropBurnablePreapproved is a token contract that extends
 *         ERC721SeaDrop to additionally provide a burn function and
           preapproved operator address.
 */
contract ERC721SeaDropBurnablePreapproved is ERC721SeaDrop {
    /// @dev The preapproved address.
    address internal _preapprovedAddress;

    /// @dev The preapproved OpenSea conduit address.
    address internal immutable _CONDUIT =
        0x1E0049783F008A0085193E00003D00cd54003c71;

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {}

    /**
     * @notice Set the preapproved address. Only callable by the owner.
     *
     * @param newPreapprovedAddress The new preapproved address.
     */
    function setPreapprovedAddress(address newPreapprovedAddress)
        external
        onlyOwner
    {
        _preapprovedAddress = newPreapprovedAddress;
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets
     *      of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        if (operator == _CONDUIT || operator == _preapprovedAddress) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice Burns `tokenId`. The caller must own `tokenId` or be an
     *         approved operator.
     *
     * @param tokenId The token id to burn.
     */
    // solhint-disable-next-line comprehensive-interface
    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }
}
