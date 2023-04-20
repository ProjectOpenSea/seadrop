// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC721SeaDropContractOffererImplementation
} from "./ERC721SeaDropContractOffererImplementation.sol";

import {
    PublicDrop,
    MultiConfigureStruct,
    SignedMintValidationParams,
    TokenGatedDropStage
} from "./ERC721SeaDropStructs.sol";

import { AllowListData, CreatorPayout } from "./SeaDropStructs.sol";

import "./ERC721SeaDropConstants.sol";

import {
    ISeaDropTokenContractMetadata
} from "../interfaces/ISeaDropTokenContractMetadata.sol";

/**
 * @title  ERC721SeaDropConfigurer
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A helper contract to configure parameters for ERC721SeaDrop.
 */
contract ERC721SeaDropConfigurer is ERC721SeaDropContractOffererImplementation {
    /**
     * @notice Returns the mint public drop data.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getPublicDrop(
        address token
    ) external view returns (PublicDrop memory) {
        // Call getPublicDrop on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_PUBLIC_DROP_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the public drop.
        return abi.decode(data, (PublicDrop));
    }

    /**
     * @notice Returns the creator payouts for the nft contract.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getCreatorPayouts(
        address token
    ) external view returns (CreatorPayout[] memory) {
        // Call getCreatorPayouts on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_CREATOR_PAYOUTS_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the creator payouts.
        return abi.decode(data, (CreatorPayout[]));
    }

    /**
     * @notice Returns the allow list merkle root for the nft contract.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getAllowListMerkleRoot(
        address token
    ) external view returns (bytes32) {
        // Call getAllowListMerkleRoot on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_ALLOW_LIST_MERKLE_ROOT_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the allow list merkle root.
        return abi.decode(data, (bytes32));
    }

    /**
     * @notice Returns an enumeration of allowed fee recipients
     *         when fee recipients are enforced.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getAllowedFeeRecipients(
        address token
    ) external view returns (address[] memory) {
        // Call getAllowedFeeRecipients on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_ALLOWED_FEE_RECIPIENTS_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the allowed fee recipients.
        return abi.decode(data, (address[]));
    }

    /**
     * @notice Returns the server-side signers.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getSigners(
        address token
    ) external view returns (address[] memory) {
        // Call getSigners on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_SIGNERS_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the signers.
        return abi.decode(data, (address[]));
    }

    /**
     * @notice Returns the struct of SignedMintValidationParams for a signer.
     *
     * @param token  The ERC721SeaDrop contract address.
     * @param signer The signer.
     */
    function getSignedMintValidationParams(
        address token,
        address signer
    ) external view returns (SignedMintValidationParams memory) {
        // Call getSignedMintValidationParams on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the signed mint validation params.
        return abi.decode(data, (SignedMintValidationParams));
    }

    /**
     * @notice Returns the allowed payers.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getPayers(address token) external view returns (address[] memory) {
        // Call getPayers on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_PAYERS_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the payers.
        return abi.decode(data, (address[]));
    }

    /**
     * @notice Returns the allowed token gated drop tokens.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getTokenGatedAllowedTokens(
        address token
    ) external view returns (address[] memory) {
        // Call getTokenGatedAllowedTokens on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encode(GET_TOKEN_GATED_ALLOWED_TOKENS_SELECTOR)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the allowed token addresses.
        return abi.decode(data, (address[]));
    }

    /**
     * @notice Returns the token gated drop data for the token gated nft.
     *
     * @param token           The ERC721SeaDrop contract address.
     * @param allowedNftToken The allowed nft token.
     */
    function getTokenGatedDrop(
        address token,
        address allowedNftToken
    ) external view returns (TokenGatedDropStage memory) {
        // Call getTokenGatedDrop on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(
                GET_TOKEN_GATED_DROP_SELECTOR,
                allowedNftToken
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the token gated drop stage.
        return abi.decode(data, (TokenGatedDropStage));
    }

    /**
     * @notice Returns the redeemed count for a token id for a
     *         token gated drop.
     *
     * @param token             The ERC721SeaDrop contract address.
     * @param allowedNftToken   The token gated nft token.
     * @param allowedNftTokenId The token gated nft token id to check.
     */
    function getAllowedNftTokenIdRedeemedCount(
        address token,
        address allowedNftToken,
        uint256 allowedNftTokenId
    ) external view returns (uint256) {
        // Call getAllowedNftTokenIdRedeemedCount on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(
                GET_ALLOWED_NFT_TOKEN_ID_REDEEMED_COUNT_SELECTOR,
                allowedNftToken,
                allowedNftTokenId
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the redeemed mint count.
        return abi.decode(data, (uint256));
    }

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists in enforcing maxSupply, maxTotalMintableByWallet,
     *         and maxTokenSupplyForStage checks.
     *
     * @dev    NOTE: Implementing contracts should always update these numbers
     *         before transferring any tokens with _safeMint() to mitigate
     *         consequences of malicious onERC721Received() hooks.
     *
     * @param token  The ERC721SeaDrop contract address.
     * @param minter The minter address.
     */
    function getMintStats(
        address token,
        address minter
    )
        external
        view
        returns (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply
        )
    {
        // Call getMintStats on the token contract.
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(GET_MINT_STATS_SELECTOR, minter)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();

        // Return the mint stats.
        return abi.decode(data, (uint256, uint256, uint256));
    }

    /**
     * @notice Update the allowed Seaport contracts.
     *
     *         Warning: this lets the provided addresses mint tokens on this
     *         contract, be sure to only set official Seaport releases.
     *
     *         Only the owner can use this function.
     *
     * @param token          The ERC721SeaDrop contract address.
     * @param allowedSeaport The allowed SeaDrop addresses.
     */
    function updateAllowedSeaport(
        address token,
        address[] calldata allowedSeaport
    ) external {
        // Call updateAllowedSeaport on the token contract.
        (bool success, bytes memory result) = token.call(
            abi.encodeWithSelector(
                UPDATE_ALLOWED_SEAPORT_SELECTOR,
                allowedSeaport
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Emits an event to notify update of the drop URI.
     *
     *         Only the owner can use this function.
     *
     * @param token   The ERC721SeaDrop contract address.
     * @param dropURI The new drop URI.
     */
    function updateDropURI(address token, string calldata dropURI) external {
        // Call updateDropURI on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_DROP_URI_SELECTOR, dropURI)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Updates the public drop data and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param token      The ERC721SeaDrop contract address.
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(
        address token,
        PublicDrop calldata publicDrop
    ) external {
        // Call updatePublicDrop on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_PUBLIC_DROP_SELECTOR, publicDrop)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Updates the allow list merkle root for the nft contract
     *         and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param token         The ERC721SeaDrop contract address.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address token,
        AllowListData calldata allowListData
    ) external {
        // Call updateAllowList on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_ALLOW_LIST_SELECTOR, allowListData)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Updates the token gated drop stage for the nft contract
     *         and emits an event.
     *
     *         Only the owner can use this function.
     *
     *         Note: If two SeaDrop tokens are doing simultaneous token gated
     *         drop promotions for each other, they can be minted by the same
     *         actor until `maxTokenSupplyForStage` is reached. Please ensure
     *         the `allowedNftToken` is not running an active drop during the
     *         `dropStage` time period.
     *
     * @param token           The ERC721SeaDrop contract address.
     * @param allowedNftToken The token gated nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address token,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external {
        // Call updateTokenGatedDrop on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_TOKEN_GATED_DROP_SELECTOR,
                allowedNftToken,
                dropStage
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Updates the creator payouts and emits an event.
     *         The basis points must add up to 10_000 exactly.
     *
     *         Only the owner can use this function.
     *
     * @param token          The ERC721SeaDrop contract address.
     * @param creatorPayouts The creator payout address and basis points.
     */
    function updateCreatorPayouts(
        address token,
        CreatorPayout[] calldata creatorPayouts
    ) external {
        // Call updateCreatorPayouts on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_CREATOR_PAYOUTS_SELECTOR,
                creatorPayouts
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Updates the allowed fee recipient and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param token        The ERC721SeaDrop contract address.
     * @param feeRecipient The fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address token,
        address feeRecipient,
        bool allowed
    ) external {
        // Call updateAllowedFeeRecipient on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_ALLOWED_FEE_RECIPIENT_SELECTOR,
                feeRecipient,
                allowed
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Updates the allowed server-side signers and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param token                      The ERC721SeaDrop contract address.
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters
     *                                   to enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address token,
        address signer,
        SignedMintValidationParams calldata signedMintValidationParams
    ) external {
        // Call updateSignedMintValidationParams on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR,
                signer,
                signedMintValidationParams
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Updates the allowed payer and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param token   The ERC721SeaDrop contract address.
     * @param payer   The payer to add or remove.
     * @param allowed Whether to add or remove the payer.
     */
    function updatePayer(address token, address payer, bool allowed) external {
        // Call updatePayer on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_PAYER_SELECTOR, payer, allowed)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason();
    }

    /**
     * @notice Configure multiple properties at a time.
     *
     *         Note: The individual configure methods should be used
     *         to unset or reset any properties to zero, as this method
     *         will ignore zero-value properties in the config struct.
     *
     * @param token  The ERC721SeaDrop contract address.
     * @param config The configuration struct.
     */
    function multiConfigure(
        address token,
        MultiConfigureStruct calldata config
    ) external {
        if (config.maxSupply != 0) {
            ISeaDropTokenContractMetadata(token).setMaxSupply(config.maxSupply);
        }
        if (bytes(config.baseURI).length != 0) {
            ISeaDropTokenContractMetadata(token).setBaseURI(config.baseURI);
        }
        if (bytes(config.contractURI).length != 0) {
            ISeaDropTokenContractMetadata(token).setContractURI(
                config.contractURI
            );
        }
        if (config.provenanceHash != bytes32(0)) {
            ISeaDropTokenContractMetadata(token).setProvenanceHash(
                config.provenanceHash
            );
        }
        if (
            _cast(
                config.royaltyReceiver != address(0) && config.royaltyBps != 0
            ) == 1
        ) {
            ISeaDropTokenContractMetadata(token).setDefaultRoyalty(
                config.royaltyReceiver,
                config.royaltyBps
            );
        }
        if (
            _cast(
                config.publicDrop.startTime != 0 &&
                    config.publicDrop.endTime != 0
            ) == 1
        ) {
            this.updatePublicDrop(token, config.publicDrop);
        }
        if (bytes(config.dropURI).length != 0) {
            this.updateDropURI(token, config.dropURI);
        }
        if (config.allowListData.merkleRoot != bytes32(0)) {
            this.updateAllowList(token, config.allowListData);
        }
        if (config.creatorPayouts.length != 0) {
            this.updateCreatorPayouts(token, config.creatorPayouts);
        }

        if (config.allowedFeeRecipients.length != 0) {
            for (uint256 i = 0; i < config.allowedFeeRecipients.length; ) {
                this.updateAllowedFeeRecipient(
                    token,
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
                this.updateAllowedFeeRecipient(
                    token,
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
                this.updatePayer(token, config.allowedPayers[i], true);
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedPayers.length != 0) {
            for (uint256 i = 0; i < config.disallowedPayers.length; ) {
                this.updatePayer(token, config.disallowedPayers[i], false);
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
                this.updateTokenGatedDrop(
                    token,
                    config.tokenGatedAllowedNftTokens[i],
                    config.tokenGatedDropStages[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedTokenGatedAllowedNftTokens.length != 0) {
            for (
                uint256 i = 0;
                i < config.disallowedTokenGatedAllowedNftTokens.length;

            ) {
                TokenGatedDropStage memory emptyStage;
                this.updateTokenGatedDrop(
                    token,
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
                this.updateSignedMintValidationParams(
                    token,
                    config.signers[i],
                    config.signedMintValidationParams[i]
                );
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedSigners.length != 0) {
            for (uint256 i = 0; i < config.disallowedSigners.length; ) {
                SignedMintValidationParams memory emptyParams;
                this.updateSignedMintValidationParams(
                    token,
                    config.disallowedSigners[i],
                    emptyParams
                );
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @dev Revert with reason from a low-level call
     */
    function _revertWithReason() internal pure {
        assembly {
            let ptr := mload(0x40)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            revert(ptr, size)
        }
    }
}
