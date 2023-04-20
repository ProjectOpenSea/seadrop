// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {
//     ContractOffererInterface
// } from "seaport/interfaces/ContractOffererInterface.sol";

import {
    ISeaDropTokenContractMetadata
} from "./ISeaDropTokenContractMetadata.sol";

import { SeaDropErrorsAndEvents } from "../lib/SeaDropErrorsAndEvents.sol";

// TODO rename to IERC721SeaDrop?
interface INonFungibleSeaDropToken is
    ISeaDropTokenContractMetadata,
    SeaDropErrorsAndEvents
{

}
