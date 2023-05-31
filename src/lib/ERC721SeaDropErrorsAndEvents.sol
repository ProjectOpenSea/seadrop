// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    PublicDrop,
    SignedMintValidationParams
} from "./ERC721SeaDropStructs.sol";

import { SeaDropErrorsAndEvents } from "./SeaDropErrorsAndEvents.sol";

interface ERC721SeaDropErrorsAndEvents is SeaDropErrorsAndEvents {
    /**
     * @dev An event with updated public drop data for an nft contract.
     */
    event PublicDropUpdated(PublicDrop publicDrop);

    /**
     * @dev An event with the updated validation parameters for server-side
     *      signers.
     */
    event SignedMintValidationParamsUpdated(
        address indexed signer,
        SignedMintValidationParams signedMintValidationParams,
        uint256 index
    );
}
