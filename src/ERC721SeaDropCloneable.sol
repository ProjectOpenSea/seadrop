// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDrop } from "./ERC721SeaDrop.sol";
import {
    Initializable
} from "openzeppelin-contracts/proxy/utils/Initializable.sol";

/**
 * @title  ERC721SeaDropCloneable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721SeaDrop is a token contract that contains methods
 *         to properly interact with SeaDrop.
 */
contract ERC721SeaDropCloneable is
    ERC721SeaDrop("", "", new address[](0)),
    Initializable
{
    string internal _name;
    string internal _symbol;

    function initialize(
        string calldata __name,
        string calldata __symbol,
        address[] calldata allowedSeaDrop,
        address initialOwner
    ) public initializer {
        _name = __name;
        _symbol = __symbol;
        _updateAllowedSeaDrop(allowedSeaDrop);
        _transferOwnership(initialOwner);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
}
