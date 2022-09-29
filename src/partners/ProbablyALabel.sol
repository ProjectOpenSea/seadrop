// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721PartnerSeaDropBurnable
} from "../extensions/ERC721PartnerSeaDropBurnable.sol";

/** -----------------------------------------------------
 *     ____             __          __    __         ___
 *    / __ \_________  / /_  ____ _/ /_  / /_  __   /   |
 *   / /_/ / ___/ __ \/ __ \/ __ `/ __ \/ / / / /  / /| |
 *  / ____/ /  / /_/ / /_/ / /_/ / /_/ / / /_/ /  / ___ |
 * /_/   /_/   \____/_.___/\__,_/_.___/_/\__, /  /_/  |_|
 *                                     /____/
 *     __          __         __
 *    / /   ____ _/ /_  ___  / /
 *   / /   / __ `/ __ \/ _ \/ /
 *  / /___/ /_/ / /_/ /  __/ /
 * /_____/\__,_/_.___/\___/_/
 *
 * ------------------------------------------------------
 *
 * @notice This contract uses ERC721PartnerSeaDropBurnable,
 *         an ERC721A token contract that is compatible with SeaDrop,
 *         along with a burn function only callable by the token owner.
 */
contract ProbablyALabel is ERC721PartnerSeaDropBurnable {
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
        ERC721PartnerSeaDropBurnable(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        )
    {}
}
