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

interface IERC173 {
    /// @notice Returns the address of the owner.
    function owner() external view returns (address);
}

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
     * @notice Returns SeaDrop settings for a token.
     *
     * @param token The ERC721SeaDrop contract address.
     */
    function getSeaDropSettings(
        address token
    )
        external
        view
        returns (
            PublicDrop memory publicDrop,
            CreatorPayout[] memory creatorPayouts,
            bytes32 allowListMerkleRoot,
            address[] memory allowedFeeRecipients,
            address[] memory signers,
            address[] memory payers,
            address[] memory tokenGatedAllowedNftTokens
        )
    {
        // Define the selectors to call.
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = GET_PUBLIC_DROP_SELECTOR;
        selectors[1] = GET_CREATOR_PAYOUTS_SELECTOR;
        selectors[2] = GET_ALLOW_LIST_MERKLE_ROOT_SELECTOR;
        selectors[3] = GET_ALLOWED_FEE_RECIPIENTS_SELECTOR;
        selectors[4] = GET_SIGNERS_SELECTOR;
        selectors[5] = GET_PAYERS_SELECTOR;
        selectors[6] = GET_TOKEN_GATED_ALLOWED_TOKENS_SELECTOR;

        // Define variables to store the staticcall results.
        bool success;
        bytes memory data;

        for (uint256 i = 0; i < selectors.length; ) {
            // Call the selector on the token contract.
            (success, data) = token.staticcall(
                abi.encodeWithSelector(selectors[i])
            );

            // Revert with the reason if the call failed.
            if (!success) _revertWithReason(data);

            // Set the return data.
            if (i == 0) {
                publicDrop = abi.decode(data, (PublicDrop));
            } else if (i == 1) {
                creatorPayouts = abi.decode(data, (CreatorPayout[]));
            } else if (i == 2) {
                allowListMerkleRoot = abi.decode(data, (bytes32));
            } else if (i == 3) {
                allowedFeeRecipients = abi.decode(data, (address[]));
            } else if (i == 4) {
                signers = abi.decode(data, (address[]));
            } else if (i == 5) {
                payers = abi.decode(data, (address[]));
            } else {
                // i == 6
                tokenGatedAllowedNftTokens = abi.decode(data, (address[]));
            }

            unchecked {
                ++i;
            }
        }
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
            abi.encodeWithSelector(
                GET_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR,
                signer
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);

        // Return the signed mint validation params.
        return abi.decode(data, (SignedMintValidationParams));
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
        if (!success) _revertWithReason(data);

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
        if (!success) _revertWithReason(data);

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
        if (!success) _revertWithReason(data);

        // Return the mint stats.
        return abi.decode(data, (uint256, uint256, uint256));
    }

    /**
     * @notice Update the allowed Seaport contracts.
     *
     *         Warning: this lets the provided addresses mint tokens on this
     *         contract, be sure to only set official Seaport releases.
     *
     *         Only the token owner can use this function.
     *
     * @param token          The ERC721SeaDrop contract address.
     * @param allowedSeaport The allowed SeaDrop addresses.
     */
    function updateAllowedSeaport(
        address token,
        address[] calldata allowedSeaport
    ) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updateAllowedSeaport on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_ALLOWED_SEAPORT_SELECTOR,
                allowedSeaport
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Emits an event to notify update of the drop URI.
     *
     *         Only the token owner can use this function.
     *
     * @param token   The ERC721SeaDrop contract address.
     * @param dropURI The new drop URI.
     */
    function updateDropURI(address token, string calldata dropURI) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updateDropURI on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_DROP_URI_SELECTOR, dropURI)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Updates the public drop data and emits an event.
     *
     *         Only the token owner can use this function.
     *
     * @param token      The ERC721SeaDrop contract address.
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(
        address token,
        PublicDrop calldata publicDrop
    ) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updatePublicDrop on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_PUBLIC_DROP_SELECTOR, publicDrop)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Updates the allow list merkle root for the nft contract
     *         and emits an event.
     *
     *         Only the token owner can use this function.
     *
     * @param token         The ERC721SeaDrop contract address.
     * @param allowListData The allow list data.
     */
    function updateAllowList(
        address token,
        AllowListData calldata allowListData
    ) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updateAllowList on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_ALLOW_LIST_SELECTOR, allowListData)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Updates the token gated drop stage for the nft contract
     *         and emits an event.
     *
     *         Only the token owner can use this function.
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
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updateTokenGatedDrop on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_TOKEN_GATED_DROP_SELECTOR,
                allowedNftToken,
                dropStage
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Updates the creator payouts and emits an event.
     *         The basis points must add up to 10_000 exactly.
     *
     *         Only the token owner can use this function.
     *
     * @param token          The ERC721SeaDrop contract address.
     * @param creatorPayouts The creator payout address and basis points.
     */
    function updateCreatorPayouts(
        address token,
        CreatorPayout[] calldata creatorPayouts
    ) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updateCreatorPayouts on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_CREATOR_PAYOUTS_SELECTOR,
                creatorPayouts
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Updates the allowed fee recipient and emits an event.
     *
     *         Only the token owner can use this function.
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
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updateAllowedFeeRecipient on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_ALLOWED_FEE_RECIPIENT_SELECTOR,
                feeRecipient,
                allowed
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Updates the allowed server-side signers and emits an event.
     *
     *         Only the token owner can use this function.
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
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updateSignedMintValidationParams on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(
                UPDATE_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR,
                signer,
                signedMintValidationParams
            )
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
    }

    /**
     * @notice Updates the allowed payer and emits an event.
     *
     *         Only the token owner can use this function.
     *
     * @param token   The ERC721SeaDrop contract address.
     * @param payer   The payer to add or remove.
     * @param allowed Whether to add or remove the payer.
     */
    function updatePayer(address token, address payer, bool allowed) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

        // Call updatePayer on the token contract.
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(UPDATE_PAYER_SELECTOR, payer, allowed)
        );

        // Revert with the reason if the call failed.
        if (!success) _revertWithReason(data);
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
     * @param token  The ERC721SeaDrop contract address.
     * @param config The configuration struct.
     */
    function multiConfigure(
        address token,
        MultiConfigureStruct calldata config
    ) external {
        // Ensure the sender is the owner of the token.
        _onlyOwner(token);

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

        // Define variables for the low-level calls.
        bool success;
        bytes memory data;

        if (
            _cast(
                config.publicDrop.startTime != 0 &&
                    config.publicDrop.endTime != 0
            ) == 1
        ) {
            (success, data) = token.call(
                abi.encodeWithSelector(
                    UPDATE_PUBLIC_DROP_SELECTOR,
                    config.publicDrop
                )
            );
            if (!success) _revertWithReason(data);
        }
        if (bytes(config.dropURI).length != 0) {
            (success, data) = token.call(
                abi.encodeWithSelector(UPDATE_DROP_URI_SELECTOR, config.dropURI)
            );
            if (!success) _revertWithReason(data);
        }
        if (config.allowListData.merkleRoot != bytes32(0)) {
            (success, data) = token.call(
                abi.encodeWithSelector(
                    UPDATE_ALLOW_LIST_SELECTOR,
                    config.allowListData
                )
            );
            if (!success) _revertWithReason(data);
        }
        if (config.creatorPayouts.length != 0) {
            (success, data) = token.call(
                abi.encodeWithSelector(
                    UPDATE_CREATOR_PAYOUTS_SELECTOR,
                    config.creatorPayouts
                )
            );
            if (!success) _revertWithReason(data);
        }
        if (config.allowedFeeRecipients.length != 0) {
            for (uint256 i = 0; i < config.allowedFeeRecipients.length; ) {
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_ALLOWED_FEE_RECIPIENT_SELECTOR,
                        config.allowedFeeRecipients[i],
                        true
                    )
                );
                if (!success) _revertWithReason(data);
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedFeeRecipients.length != 0) {
            for (uint256 i = 0; i < config.disallowedFeeRecipients.length; ) {
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_ALLOWED_FEE_RECIPIENT_SELECTOR,
                        config.disallowedFeeRecipients[i],
                        false
                    )
                );
                if (!success) _revertWithReason(data);
                unchecked {
                    ++i;
                }
            }
        }
        if (config.allowedPayers.length != 0) {
            for (uint256 i = 0; i < config.allowedPayers.length; ) {
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_PAYER_SELECTOR,
                        config.allowedPayers[i],
                        true
                    )
                );
                if (!success) _revertWithReason(data);
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedPayers.length != 0) {
            for (uint256 i = 0; i < config.disallowedPayers.length; ) {
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_PAYER_SELECTOR,
                        config.disallowedPayers[i],
                        false
                    )
                );
                if (!success) _revertWithReason(data);
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
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_TOKEN_GATED_DROP_SELECTOR,
                        config.tokenGatedAllowedNftTokens[i],
                        config.tokenGatedDropStages[i]
                    )
                );
                if (!success) _revertWithReason(data);
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
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_TOKEN_GATED_DROP_SELECTOR,
                        config.disallowedTokenGatedAllowedNftTokens[i],
                        emptyStage
                    )
                );
                if (!success) _revertWithReason(data);
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
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR,
                        config.signers[i],
                        config.signedMintValidationParams[i]
                    )
                );
                if (!success) _revertWithReason(data);
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedSigners.length != 0) {
            SignedMintValidationParams memory emptyParams;
            for (uint256 i = 0; i < config.disallowedSigners.length; ) {
                (success, data) = token.call(
                    abi.encodeWithSelector(
                        UPDATE_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR,
                        config.disallowedSigners[i],
                        emptyParams
                    )
                );
                if (!success) _revertWithReason(data);
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @dev Internal pure function to revert with reason from a low-level call
     *      where the revert reason is encoded in the return data.
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