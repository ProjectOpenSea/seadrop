// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721PartnerSeaDropRandomOffset
} from "../extensions/ERC721PartnerSeaDropRandomOffset.sol";

/*
 * ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
 * ▓▓                          CLOUDMACHINE                        ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░▓▓▓▓░░░░░░░░░░▓▓▓▓░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░▓▓▓░░▓▓▓▓▓▓▓▓▓▓░░▓▓▓░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░▓░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░▓▓░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓░░▓▓▓▓▓▓░░▓▓▓▓░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓░░░░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓░░░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░▓░░░░░░░▓▓░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░▓░░░░░▓▓░░▓░░▓▓▓░▓▓░░▓▓░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░▓▓░░░░░▓▓░░░░▓▓▓░▓░░▓▓░░▓▓░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░▓░░░▓▓▓░░▓▓░▓▓░░░▓▓░░▓░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░▓▓▓░▓▓░▓▓░░▓▓░░░▓░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░▓▓▓░░░▓▓▓▓▓▓▓░▓░░░░▓▓░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░▓▓▓░░░▓░▓▓▓▓░░░░▓▓▓░░░░▓▓▓░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░▓▓░░░░░░▓▓▓▓░░▓▓▓▓░░░▓▓▓░░░▓░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░▓▓▓▓░░▓▓▓▓▓▓░▓▓▓▓▓▓▓▓░▓▓░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░▓▓▓▓▓░▓▓▓▓▓▓░▓▓▓▓░░▓▓▓▓░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░▓▓░░▓▓▓▓▓▓▓▓░░▓▓░░░▓▓▓░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓░░░▓▓░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░░▓░░▓░░░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░░░▓░▓▓▓▓░░▓▓░░░░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░░░░▓▓░▓░░░░░▓▓░▓▓▓░░░░░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓░░▓░░░▓░░░░▓▓▓▓▓▓░░░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓░░░▓▓▓░░░▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓░░▓▓▓▓▓░░▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓░░░▓▓▓░░░▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓░░▓▓▓░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░   ▓▓
 * ▓▓   ░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░   ▓▓
 * ▓▓                          CLOUDMACHINE                        ▓▓
 * ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
 *
 * @notice This contract uses ERC721PartnerSeaDropRandomOffset,
 *         an ERC721A token contract that is compatible with SeaDrop,
 *         along with a random offset mechanism for metadata reveal.
 */
contract Cloudmachine is ERC721PartnerSeaDropRandomOffset {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    )
        ERC721PartnerSeaDropRandomOffset(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        )
    {}
}