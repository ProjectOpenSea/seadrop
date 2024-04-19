// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721AUpgradeable } from "../../lib/ERC721A-Upgradeable/contracts/ERC721AUpgradeable.sol";

/**
 * @title  ERC721AConduitPreapproved
 * @notice ERC721A with the OpenSea conduit preapproved.
 */
abstract contract ERC721AConduitPreapprovedUpgradeable is ERC721AUpgradeable {
    /// @dev The canonical OpenSea conduit.
    address internal constant _CONDUIT = 0x1E0049783F008A0085193E00003D00cd54003c71;

    /**
     * @notice Deploy the token contract with its name and symbol.
     */
    function __ERC721AConduitPreapprovedUpgradeable_init_unchained(
        string memory name, string memory symbol
    ) internal onlyInitializingERC721A {
        __ERC721A_init_unchained(name, symbol);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the
     *      assets of `owner`. Always returns true for the conduit.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        if (operator == _CONDUIT) {
            return true;
        }
        return ERC721AUpgradeable.isApprovedForAll(owner, operator);
    }
}
