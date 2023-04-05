// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    AllowListData,
    CreatorPayout,
    PublicDrop,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "./SeaDropStructs.sol";

interface ERC721SeaDropStructsErrorsAndEvents {
    /**
     * @notice Revert with an error if the caller is not an allowed Seaport
     *         contract address.
     */
    error OnlyAllowedSeaport();

    /**
     * @notice Revert with an error if the number of token gated
     *         allowedNftTokens doesn't match the length of supplied
     *         drop stages.
     */
    error TokenGatedMismatch();

    /**
     *  @notice Revert with an error if the number of signers doesn't match
     *          the length of supplied signedMintValidationParams
     */
    error SignersMismatch();

    /**
     * @notice The SeaDrop token types, emitted as part of
     *         `event SeaDropTokenDeployed`.
     */
    enum SEADROP_TOKEN_TYPE {
        ERC721_STANDARD,
        ERC721_CLONE,
        ERC721_LAZY,
        ERC721_UPGRADEABLE,
        ERC1155_STANDARD,
        ERC1155_CLONE,
        ERC1155_UPGRADEABLE
    }

    /**
     * @notice An event to signify that a SeaDrop token contract was deployed.
     */
    event SeaDropTokenDeployed(SEADROP_TOKEN_TYPE tokenType);

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
