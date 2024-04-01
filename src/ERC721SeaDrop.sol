// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC721SeaDropContractOfferer
} from "./lib/ERC721SeaDropContractOfferer.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

/**
 * @title  ERC721SeaDrop
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @contributor Limit Break (@limitbreak)
 * @notice An ERC721 token contract based on ERC721A that can mint as a
 *         Seaport contract offerer.
 *         Implements Limit Break's Creator Token Standards transfer
 *         validation for royalty enforcement.
 */
contract ERC721SeaDrop is ERC721SeaDropContractOfferer {
    /**
     * @notice Deploy the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          implementation code. Also contains SeaDrop
     *                          implementation code.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name              The name of the token.
     * @param symbol            The symbol of the token.
     */
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name,
        string memory symbol
    )
        ERC721SeaDropContractOfferer(
            allowedConfigurer,
            allowedSeaport,
            name,
            symbol
        )
    {}

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
    function burn(uint256 tokenId) external virtual {
        // Passing `true` to `_burn()` checks that the caller owns the token
        // or is an approved operator.
        _burn(tokenId, true);
    }
}
