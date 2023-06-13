// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PublicDrop } from "./ERC721SeaDropStructs.sol";

import { SeaDropErrorsAndEvents } from "./SeaDropErrorsAndEvents.sol";

interface ERC721SeaDropErrorsAndEvents is SeaDropErrorsAndEvents {
    /**
     * @dev An event with updated public drop data.
     */
    event PublicDropUpdated(PublicDrop publicDrop);
}
