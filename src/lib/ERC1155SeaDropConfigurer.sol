// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC1155SeaDropContractOffererImplementation
} from "./ERC1155SeaDropContractOffererImplementation.sol";

import {
    PublicDrop,
    MultiConfigureStruct,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "./ERC1155SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "./SeaDropStructs.sol";

import "./ERC1155SeaDropConstants.sol";

import {
    IERC1155ContractMetadata
} from "../interfaces/IERC1155ContractMetadata.sol";

import { IERC1155SeaDrop } from "../interfaces/IERC1155SeaDrop.sol";

import { IERC173 } from "../interfaces/IERC173.sol";

/**
 * @title  ERC1155SeaDropConfigurer
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A helper contract to configure parameters for ERC1155SeaDrop.
 */
contract ERC1155SeaDropConfigurer is
    ERC1155SeaDropContractOffererImplementation
{
    /**
     * @notice Revert with an error if the sender is not the owner
     *         of the token contract.
     */
    error OnlyOwner();

    /**
     * @dev Reverts if the sender is not the owner of the token.
     *
     *      This function is inlined instead of being a modifier
     *      to save contract space from being inlined N times.
     */
    function _onlyOwner(address token) internal view {
        if (msg.sender != IERC173(token).owner()) {
            revert OnlyOwner();
        }
    }

    /**
     * @notice Configure multiple properties at a time.
     *
     *         Only the owner of the token can use this function.
     *
     *         Note: The individual configure methods should be used
     *         to unset or reset any properties to zero, as this method
     *         will ignore zero-value properties in the config struct.
     *
     * @param token  The ERC1155SeaDrop contract address.
     * @param config The configuration struct.
     */
    function multiConfigure(
        address token,
        MultiConfigureStruct calldata config
    ) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        if (config.maxSupplyTokenIds.length != 0) {
            if (
                config.maxSupplyTokenIds.length !=
                config.maxSupplyAmounts.length
            ) {
                revert MaxSupplyMismatch();
            }
            for (uint256 i = 0; i < config.maxSupplyTokenIds.length; ) {
                IERC1155ContractMetadata(token).setMaxSupply(
                    config.maxSupplyTokenIds[i],
                    config.maxSupplyAmounts[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (bytes(config.baseURI).length != 0) {
            IERC1155ContractMetadata(token).setBaseURI(config.baseURI);
        }
        if (bytes(config.contractURI).length != 0) {
            IERC1155ContractMetadata(token).setContractURI(config.contractURI);
        }
        if (config.provenanceHash != bytes32(0)) {
            IERC1155ContractMetadata(token).setProvenanceHash(
                config.provenanceHash
            );
        }
        if (
            _cast(
                config.royaltyReceiver != address(0) && config.royaltyBps != 0
            ) == 1
        ) {
            IERC1155ContractMetadata(token).setDefaultRoyalty(
                config.royaltyReceiver,
                config.royaltyBps
            );
        }

        if (config.publicDropsIndexes.length != 0) {
            if (config.publicDropsIndexes.length != config.publicDrops.length) {
                revert PublicDropsMismatch();
            }
            for (uint256 i = 0; i < config.publicDropsIndexes.length; ) {
                IERC1155SeaDrop(address(token)).updatePublicDrop(
                    config.publicDropsIndexes[i],
                    config.publicDrops[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (bytes(config.dropURI).length != 0) {
            IERC1155SeaDrop(address(token)).updateDropURI(config.dropURI);
        }
        if (config.allowListData.merkleRoot != bytes32(0)) {
            IERC1155SeaDrop(address(token)).updateAllowList(
                config.allowListData
            );
        }
        if (config.creatorPayouts.length != 0) {
            IERC1155SeaDrop(address(token)).updateCreatorPayouts(
                config.creatorPayouts
            );
        }
        if (config.allowedFeeRecipients.length != 0) {
            for (uint256 i = 0; i < config.allowedFeeRecipients.length; ) {
                IERC1155SeaDrop(address(token)).updateAllowedFeeRecipient(
                    config.allowedFeeRecipients[i],
                    true
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedFeeRecipients.length != 0) {
            for (uint256 i = 0; i < config.disallowedFeeRecipients.length; ) {
                IERC1155SeaDrop(address(token)).updateAllowedFeeRecipient(
                    config.disallowedFeeRecipients[i],
                    false
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.allowedPayers.length != 0) {
            for (uint256 i = 0; i < config.allowedPayers.length; ) {
                IERC1155SeaDrop(address(token)).updatePayer(
                    config.allowedPayers[i],
                    true
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedPayers.length != 0) {
            for (uint256 i = 0; i < config.disallowedPayers.length; ) {
                IERC1155SeaDrop(address(token)).updatePayer(
                    config.disallowedPayers[i],
                    false
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.tokenGatedDropStages.length != 0) {
            if (
                config.tokenGatedDropStages.length !=
                config.tokenGatedAllowedNftTokens.length
            ) {
                revert TokenGatedMismatch();
            }
            for (uint256 i = 0; i < config.tokenGatedDropStages.length; ) {
                IERC1155SeaDrop(address(token)).updateTokenGatedDrop(
                    config.tokenGatedAllowedNftTokens[i],
                    config.tokenGatedDropStages[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedTokenGatedAllowedNftTokens.length != 0) {
            TokenGatedDropStage memory emptyStage;
            for (
                uint256 i = 0;
                i < config.disallowedTokenGatedAllowedNftTokens.length;

            ) {
                IERC1155SeaDrop(address(token)).updateTokenGatedDrop(
                    config.disallowedTokenGatedAllowedNftTokens[i],
                    emptyStage
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.signedMintValidationParams.length != 0) {
            if (
                config.signedMintValidationParams.length !=
                config.signers.length
            ) {
                revert SignersMismatch();
            }
            for (
                uint256 i = 0;
                i < config.signedMintValidationParams.length;

            ) {
                IERC1155SeaDrop(address(token))
                    .updateSignedMintValidationParams(
                        config.signers[i],
                        config.signedMintValidationParams[i]
                    );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedSigners.length != 0) {
            SignedMintValidationParams memory emptyParams;
            for (uint256 i = 0; i < config.disallowedSigners.length; ) {
                IERC1155SeaDrop(address(token))
                    .updateSignedMintValidationParams(
                        config.disallowedSigners[i],
                        emptyParams
                    );
                unchecked {
                    ++i;
                }
            }
        }
    }
}
