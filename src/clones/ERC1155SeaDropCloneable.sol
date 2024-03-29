// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC1155SeaDropContractOffererCloneable
} from "./ERC1155SeaDropContractOffererCloneable.sol";

/**
 * @title  ERC1155SeaDropCloneable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A cloneable ERC1155 token contract that can mint as a
 *         Seaport contract offerer.
 */
contract ERC1155SeaDropCloneable is ERC1155SeaDropContractOffererCloneable {
    /**
     * @notice Initialize the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          implementation code. Also contains SeaDrop
     *                          implementation code.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     */
    function initialize(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name_,
        string memory symbol_,
        address initialOwner
    ) public initializer {
        // Initialize ownership.
        _initializeOwner(initialOwner);

        // Initialize ERC1155SeaDropContractOffererCloneable.
        __ERC1155SeaDropContractOffererCloneable_init(
            allowedConfigurer,
            allowedSeaport,
            name_,
            symbol_
        );
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
