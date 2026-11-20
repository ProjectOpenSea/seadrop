// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC1155SeaDropV3 } from "./ERC1155SeaDropV3.sol";

/**
 * @title  ERC1155SeaDropV3Standalone
 * @notice ERC1155SeaDropV3, deployed directly instead of as a factory
 *         clone. The constructor sets the owner, the first allowed minter
 *         and the URI in the deployment transaction, so there is no
 *         separate initialization for anyone to front-run, and
 *         `initialize` always reverts.
 *
 *         It behaves like a clone in every other way, token ids starting
 *         at 1 included. `factory` returns the deployer, and the token
 *         isn't registered with the minter, since no allowed factory
 *         deployed it.
 */
contract ERC1155SeaDropV3Standalone is ERC1155SeaDropV3 {
    error MinterIsZeroAddress();

    /**
     * @notice Deploy the token, ready to mint through SeaDropMinter.
     *
     * @param initialOwner The token's owner.
     * @param minter       The first allowed minter, the chain's
     *                     SeaDropMinter.
     * @param uri_         The URI for every id, with `{id}` for clients to
     *                     substitute.
     * @param conduit      The conduit every holder's tokens are approved
     *                     for until the holder revokes it, or the zero
     *                     address for none. OpenSea's differs by chain.
     */
    constructor(
        address initialOwner,
        address minter,
        string memory uri_,
        address conduit
    ) ERC1155SeaDropV3(conduit) {
        if (initialOwner == address(0)) {
            revert NewOwnerIsZeroAddress();
        }
        if (minter == address(0)) revert MinterIsZeroAddress();
        // SeaDropTokenV3Base's constructor marked the token initialized
        // and gave up ownership, as it does for a clone implementation.
        _transferOwnership(initialOwner);
        _setAllowedMinter(minter, true);
        _erc1155Storage().uri = uri_;
    }
}
