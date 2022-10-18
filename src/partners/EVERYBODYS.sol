// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721PartnerSeaDrop } from "../ERC721PartnerSeaDrop.sol";

/* -----------------------------------------------------------------------
 *  ________      ________ _______     ______   ____  _______     _______
 * |  ____\ \    / /  ____|  __ \ \   / /  _ \ / __ \|  __ \ \   / / ____|
 * | |__   \ \  / /| |__  | |__) \ \_/ /| |_) | |  | | |  | \ \_/ / (___
 * |  __|   \ \/ / |  __| |  _  / \   / |  _ <| |  | | |  | |\   / \___ \
 * | |____   \  /  | |____| | \ \  | |  | |_) | |__| | |__| | | |  ____) |
 * |______|   \/   |______|_|  \_\ |_|  |____/ \____/|_____/  |_| |_____/
 *
 * -----------------------------------------------------------------------
 *
 * @notice This contract uses ERC721PartnerSeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 */
contract EVERYBODYS is ERC721PartnerSeaDrop {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) ERC721PartnerSeaDrop(name, symbol, administrator, allowedSeaDrop) {}
}
