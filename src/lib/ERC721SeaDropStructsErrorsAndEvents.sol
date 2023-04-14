// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    SeaDropStructsErrorsAndEvents
} from "./SeaDropStructsErrorsAndEvents.sol";

interface ERC721SeaDropStructsErrorsAndEvents is SeaDropStructsErrorsAndEvents {
    /**
     * @notice A struct to configure multiple contract options at a time.
     */
    struct MultiConfigureStruct {
        uint256 maxSupply;
        string baseURI;
        string contractURI;
        PublicDrop publicDrop;
        string dropURI;
        AllowListData allowListData;
        CreatorPayout[] creatorPayouts;
        bytes32 provenanceHash;
        address[] allowedFeeRecipients;
        address[] disallowedFeeRecipients;
        address[] allowedPayers;
        address[] disallowedPayers;
        // Token-gated
        address[] tokenGatedAllowedNftTokens;
        TokenGatedDropStage[] tokenGatedDropStages;
        address[] disallowedTokenGatedAllowedNftTokens;
        // Server-signed
        address[] signers;
        SignedMintValidationParams[] signedMintValidationParams;
        address[] disallowedSigners;
    }
}
