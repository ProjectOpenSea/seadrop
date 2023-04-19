// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import {
//     ContractOffererInterface
// } from "seaport/interfaces/ContractOffererInterface.sol";

import {
    ISeaDropTokenContractMetadata
} from "./ISeaDropTokenContractMetadata.sol";

import {
    SeaDropStructsErrorsAndEvents
} from "../lib/SeaDropStructsErrorsAndEvents.sol";

// TODO rename to IERC721SeaDrop?
interface INonFungibleSeaDropToken is
    ISeaDropTokenContractMetadata,
    SeaDropStructsErrorsAndEvents
{
    /**
     * @dev Revert with an error if the caller is not an allowed Seaport
     *      or conduit address.
     */
    error InvalidCallerOnlyAllowedSeaportOrConduit(address caller);

    /**
     * @dev Revert with an error if the order does not have the ERC1155 magic
     *      consideration item to signify a consecutive mint.
     */
    error MustSpecifyERC1155ConsiderationItemForSeaDropConsecutiveMint();

    /**
     * @dev Revert with an error if the extra data version is not supported.
     */
    error UnsupportedExtraDataVersion(uint8 version);

    /**
     * @dev Revert with an error if the extra data encoding is not supported.
     */
    error InvalidExtraDataEncoding(uint8 version);

    /**
     * @dev Revert with an error if the provided substandard is not supported.
     */
    error InvalidSubstandard(uint8 substandard);

    /**
     * @dev Emit an event when allowed Seaport contracts are updated.
     */
    event AllowedSeaportUpdated(address[] allowedSeaport);
}
