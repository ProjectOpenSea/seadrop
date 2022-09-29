// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721PartnerSeaDropBurnable
} from "../extensions/ERC721PartnerSeaDropBurnable.sol";

/** --------------------------------------------------
 *   _    _ _    _  _____  ____           _____ ____
 *  | |  | | |  | |/ ____|/ __ \         |_   _/ __ \
 *  | |__| | |  | | |  __| |  | | __  __   | || |  | |
 *  |  __  | |  | | | |_ | |  | | \ \/ /   | || |  | |
 *  | |  | | |__| | |__| | |__| |  >  <   _| || |__| |
 *  |_|  |_|\____/ \_____|\____/  /_/\_\ |_____\____/
 *
 * ---------------------------------------------------
 *
 * @notice This contract uses ERC721PartnerSeaDropBurnable,
 *         an ERC721A token contract that is compatible with SeaDrop,
 *         along with a burn function only callable by the token owner.
 */
contract HUGOxIO is ERC721PartnerSeaDropBurnable {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     *
     *         Also mints the first token to the contract deployer
     *         for the charity auction.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    )
        ERC721PartnerSeaDropBurnable(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        )
    {
        // Mint the first token to the contract deployer
        // for the charity auction.
        _mint(msg.sender, 1);
    }
}
