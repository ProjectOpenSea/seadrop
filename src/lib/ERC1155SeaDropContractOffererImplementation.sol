// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ERC1155SeaDropContractOffererStorage
} from "./ERC1155SeaDropContractOffererStorage.sol";

import {
    MintDetails,
    MintParams,
    PublicDrop,
    SignedMintValidationParams
} from "./ERC1155SeaDropStructs.sol";

import {
    ERC1155SeaDropErrorsAndEvents
} from "./ERC1155SeaDropErrorsAndEvents.sol";

import { AllowListData, CreatorPayout } from "./SeaDropStructs.sol";

import { IERC1155SeaDrop } from "../interfaces/IERC1155SeaDrop.sol";

import { ISeaDropToken } from "../interfaces/ISeaDropToken.sol";

import { IDelegationRegistry } from "../interfaces/IDelegationRegistry.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    SpentItem,
    Schema
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title  ERC1155SeaDropContractOffererImplementation
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice A helper contract that contains the implementation logic for
 *         ERC1155SeaDropContractOfferer, to help reduce contract size
 *         on the token contract itself.
 */
contract ERC1155SeaDropContractOffererImplementation is
    ERC1155SeaDropErrorsAndEvents
{
    using ERC1155SeaDropContractOffererStorage for ERC1155SeaDropContractOffererStorage.Layout;
    using ECDSA for bytes32;

    /// @notice The delegation registry.
    IDelegationRegistry public constant DELEGATION_REGISTRY =
        IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);

    /// @notice The original address of this contract, to ensure that it can
    ///         only be called into with delegatecall.
    address internal immutable _originalImplementation;

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _SIGNED_MINT_TYPEHASH =
        // prettier-ignore
        keccak256(
            "SignedMint("
                "address minter,"
                "address feeRecipient,"
                "MintParams mintParams,"
                "uint256 salt"
            ")"
            "MintParams("
                "uint256 startPrice,"
                "uint256 endPrice,"
                "uint256 startTime,"
                "uint256 endTime,"
                "address paymentToken,"
                "uint256 fromTokenId,"
                "uint256 toTokenId,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 maxTotalMintableByWalletPerToken,"
                "uint256 maxTokenSupplyForStage,"
                "uint256 dropStageIndex,"
                "uint256 feeBps,"
                "bool restrictFeeRecipients"
            ")"
        );
    bytes32 internal constant _MINT_PARAMS_TYPEHASH =
        // prettier-ignore
        keccak256(
            "MintParams("
                "uint256 startPrice,"
                "uint256 endPrice,"
                "uint256 startTime,"
                "uint256 endTime,"
                "address paymentToken,"
                "uint256 fromTokenId,"
                "uint256 toTokenId,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 maxTotalMintableByWalletPerToken,"
                "uint256 maxTokenSupplyForStage,"
                "uint256 dropStageIndex,"
                "uint256 feeBps,"
                "bool restrictFeeRecipients"
            ")"
        );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        // prettier-ignore
        keccak256(
            "EIP712Domain("
                "string name,"
                "string version,"
                "uint256 chainId,"
                "address verifyingContract"
            ")"
        );
    bytes32 internal constant _NAME_HASH = keccak256("ERC1155SeaDrop");
    bytes32 internal constant _VERSION_HASH = keccak256("2.0");

    /**
     * @notice Constant for an unlimited `maxTokenSupplyForStage`.
     *         Used in `mintPublic` where no `maxTokenSupplyForStage`
     *         is stored in the `PublicDrop` struct.
     */
    uint256 internal constant _UNLIMITED_MAX_TOKEN_SUPPLY_FOR_STAGE =
        type(uint256).max;

    /**
     * @dev Constructor for contract deployment.
     */
    constructor() {
        // Set the immutable address of this contract.
        _originalImplementation = address(this);
    }

    /**
     * @notice The fallback function is used as a dispatcher for SeaDrop
     *         methods.
     */
    fallback(bytes calldata) external returns (bytes memory output) {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Get the function selector.
        bytes4 selector = msg.sig;

        // Get the rest of the msg data after the selector.
        bytes calldata data = msg.data[4:];

        if (selector == IERC1155SeaDrop.getPublicDrop.selector) {
            // Get the public drop index.
            uint256 publicDropIndex = uint256(bytes32(data[:32]));

            // Return the public drop.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage.layout()._publicDrops[
                        publicDropIndex
                    ]
                );
        } else if (selector == IERC1155SeaDrop.getPublicDropIndexes.selector) {
            // Return the public drop indexes.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedPublicDropIndexes
                );
        } else if (selector == ISeaDropToken.getCreatorPayouts.selector) {
            // Return the creator payouts.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._creatorPayouts
                );
        } else if (selector == ISeaDropToken.getAllowListMerkleRoot.selector) {
            // Return the creator payouts.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._allowListMerkleRoot
                );
        } else if (selector == ISeaDropToken.getAllowedFeeRecipients.selector) {
            // Return the allowed fee recipients.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedFeeRecipients
                );
        } else if (selector == ISeaDropToken.getSigners.selector) {
            // Return the allowed signers.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedSigners
                );
        } else if (
            selector == IERC1155SeaDrop.getSignedMintValidationParams.selector
        ) {
            // Get the signer.
            address signer = address(bytes20(data[12:32]));
            // Get the validation params index.
            uint256 index = uint256(bytes32(data[32:64]));

            // Return the signed mint validation params for the signer
            // at the index.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._signedMintValidationParams[signer][index]
                );
        } else if (
            selector ==
            ISeaDropToken.getSignedMintValidationParamsIndexes.selector
        ) {
            // Get the signer.
            address signer = address(bytes20(data[12:32]));

            // Return the enumerated indexes for the signer validation params.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedSignedMintValidationParamsIndexes[signer]
                );
        } else if (selector == ISeaDropToken.getPayers.selector) {
            // Return the allowed signers.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedPayers
                );
        } else {
            // Revert if the function selector is not supported.
            revert UnsupportedFunctionSelector(selector);
        }
    }

    /**
     * @notice Returns the metadata for this contract offerer.
     *
     * @return name    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        name = "ERC1155SeaDrop";
        schemas = new Schema[](1);
        schemas[0].id = 12;

        // Encode the SIP-12 substandards.
        uint256[] memory substandards = new uint256[](3);
        substandards[0] = 0;
        substandards[1] = 1;
        substandards[2] = 2;
        schemas[0].metadata = abi.encode(substandards);
    }

    /**
     * @notice Implementation function to emit an event to notify update of
     *         the drop URI.
     *
     *         Do not use this method directly.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(string calldata dropURI) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Emit an event with the update.
        emit DropURIUpdated(dropURI);
    }

    /**
     * @notice Implementation function to update the public drop data and
     *         emit an event.
     *
     *         Do not use this method directly.
     *
     * @param publicDrop The public drop data.
     * @param index      The index of the public drop.
     */
    function updatePublicDrop(
        PublicDrop calldata publicDrop,
        uint256 index
    ) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Revert if the fee basis points is greater than 10_000.
        if (publicDrop.feeBps > 10_000) {
            revert InvalidFeeBps(publicDrop.feeBps);
        }

        // Revert if the startTime is past the endTime.
        if (publicDrop.startTime > publicDrop.endTime) {
            revert InvalidStartAndEndTime(
                publicDrop.startTime,
                publicDrop.endTime
            );
        }

        // Revert if the fromTokenId is greater than the toTokenId.
        if (publicDrop.fromTokenId > publicDrop.toTokenId) {
            revert InvalidFromAndToTokenId(
                publicDrop.fromTokenId,
                publicDrop.toTokenId
            );
        }

        // Use maxTotalMintableByWallet != 0 as a signal that this update should
        // add or update the drop stage, otherwise we will be removing.
        bool addOrUpdateDropStage = publicDrop.maxTotalMintableByWallet != 0;

        // Get pointers to the token gated drop data and enumerated addresses.
        PublicDrop
            storage existingDropStageData = ERC1155SeaDropContractOffererStorage
                .layout()
                ._publicDrops[index];
        uint256[]
            storage enumeratedIndexes = ERC1155SeaDropContractOffererStorage
                .layout()
                ._enumeratedPublicDropIndexes;

        // Stage struct packs to two slots, so load it
        // as a uint256; if it is 0, it is empty.
        bool dropStageDoesNotExist;
        assembly {
            dropStageDoesNotExist := iszero(
                or(
                    sload(existingDropStageData.slot),
                    sload(add(existingDropStageData.slot, 1))
                )
            )
        }

        if (addOrUpdateDropStage) {
            ERC1155SeaDropContractOffererStorage.layout()._publicDrops[
                index
            ] = publicDrop;
            // Add to enumeration if it does not exist already.
            if (dropStageDoesNotExist) {
                enumeratedIndexes.push(index);
            }
        } else {
            // Check we are not deleting a drop stage that does not exist.
            if (dropStageDoesNotExist) {
                revert PublicDropStageNotPresent();
            }
            // Clear storage slot and remove from enumeration.
            delete ERC1155SeaDropContractOffererStorage.layout()._publicDrops[
                index
            ];
            _removeFromEnumeration(index, enumeratedIndexes);
        }

        // Emit an event with the update.
        emit PublicDropUpdated(publicDrop, index);
    }

    /**
     * @notice Implementation function to update the allow list merkle root
     *         for the nft contract and emit an event.
     *
     *         Do not use this method directly.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData) external {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Put the previous root on the stack to use for the event.
        bytes32 prevRoot = ERC1155SeaDropContractOffererStorage
            .layout()
            ._allowListMerkleRoot;

        // Update the merkle root.
        ERC1155SeaDropContractOffererStorage
            .layout()
            ._allowListMerkleRoot = allowListData.merkleRoot;

        // Emit an event with the update.
        emit AllowListUpdated(
            prevRoot,
            allowListData.merkleRoot,
            allowListData.publicKeyURIs,
            allowListData.allowListURI
        );
    }

    /**
     * @dev Implementation function to generate a mint order with the required
     *      consideration items.
     *
     *      Do not use this method directly.
     *
     * @param fulfiller              The address of the fulfiller.
     * @param minimumReceived        The minimum items that the caller must
     *                               receive. To specify a range of ERC-1155
     *                               tokens, use a null address ERC-1155 with
     *                               the amount as the quantity.
     * @custom:param maximumSpent    Maximum items the caller is willing to
     *                               spend. Must meet or exceed the requirement.
     * @param context                Context of the order according to SIP-12,
     *                               containing the mint parameters.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function generateOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata /* maximumSpent */,
        bytes calldata context // encoded based on the schemaID
    )
        external
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // Only an allowed Seaport can call this function.
        if (
            !ERC1155SeaDropContractOffererStorage.layout()._allowedSeaport[
                msg.sender
            ]
        ) {
            revert InvalidCallerOnlyAllowedSeaport(msg.sender);
        }

        // Derive the offer and consideration with effects.
        (offer, consideration) = _createOrder(
            fulfiller,
            minimumReceived,
            context,
            true
        );
    }

    /**
     * @dev Implementation view function to preview a mint order.
     *
     *      Do not use this method directly.
     *
     * @custom:param caller       The address of the caller (e.g. Seaport).
     * @param fulfiller           The address of the fulfiller.
     * @param minimumReceived     The minimum items that the caller must
     *                            receive.
     * @custom:param maximumSpent Maximum items the caller is willing to spend.
     *                            Must meet or exceed the requirement.
     * @param context             Context of the order according to SIP-12,
     *                            containing the mint parameters.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function previewOrder(
        address /* caller */,
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] calldata /* maximumSpent */,
        bytes calldata context
    )
        external
        view
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Ensure this contract is only called into with delegatecall.
        _onlyDelegateCalled();

        // To avoid the solidity compiler complaining about calling a non-view
        // function here (_createOrder), we will cast it as a view and use it.
        // This is okay because we are not modifying any state when passing
        // withEffects=false.
        function(address, SpentItem[] calldata, bytes calldata, bool)
            internal
            view
            returns (SpentItem[] memory, ReceivedItem[] memory) fn;
        function(address, SpentItem[] calldata, bytes calldata, bool)
            internal
            returns (
                SpentItem[] memory,
                ReceivedItem[] memory
            ) fn2 = _createOrder;
        assembly {
            fn := fn2
        }

        // Derive the offer and consideration without effects.
        (offer, consideration) = fn(fulfiller, minimumReceived, context, false);
    }

    /**
     * @dev Decodes an order and returns the offer and substandard version.
     *
     * @param minimumReceived The minimum items that the caller must
     *                        receive.
     * @param context         Context of the order according to SIP-12.
     */
    function _decodeOrder(
        SpentItem[] calldata minimumReceived,
        bytes calldata context
    ) internal view returns (uint8 substandard) {
        // Declare an error buffer; first check that every minimumReceived has
        // this address.
        uint256 errorBuffer;
        uint256 minimumReceivedLength = minimumReceived.length;
        for (uint256 i = 0; i < minimumReceivedLength; ) {
            errorBuffer |=
                _castAndInvert(
                    minimumReceived[i].itemType == ItemType.ERC1155
                ) |
                _castAndInvert(minimumReceived[i].token == address(this));
            unchecked {
                ++i;
            }
        }

        // Set the substandard version.
        substandard = uint8(context[1]);

        // Next, check for SIP-6 version byte.
        errorBuffer |= _castAndInvert(context[0] == bytes1(0x00)) << 1;

        // Next, check for supported substandard.
        errorBuffer |= _castAndInvert(substandard < 3) << 2;

        // Next, check for correct context length. Minimum is 43 bytes
        // (version byte, substandard byte, feeRecipient, minter,
        //  publicDropIndex OR other substandard mint params)
        unchecked {
            errorBuffer |= _castAndInvert(context.length > 42) << 3;
        }

        // Handle decoding errors.
        if (errorBuffer != 0) {
            uint8 version = uint8(context[0]);

            // We'll first revert with SIP-6 errors to follow spec.
            // (`UnsupportedExtraDataVersion` and `InvalidExtraDataEncoding`)
            if (errorBuffer << 254 != 0) {
                revert UnsupportedExtraDataVersion(version);
            } else if (errorBuffer << 252 != 0) {
                revert InvalidExtraDataEncoding(version);
            } else if (errorBuffer << 253 != 0) {
                revert InvalidSubstandard(substandard);
            } else {
                // errorBuffer << 255 != 0
                revert MustSpecifyERC1155ConsiderationItemForSeaDropMint();
            }
        }
    }

    /**
     * @dev Creates an order with the required mint payment.
     *
     * @param fulfiller           The fulfiller of the order.
     * @param minimumReceived     The minimum items that the caller must
     *                            receive.
     * @param context             Context of the order according to SIP-12,
     *                            containing the mint parameters.
     * @param withEffects         Whether to apply state changes of the mint.
     *
     * @return offer         An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function _createOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        bytes calldata context,
        bool withEffects
    )
        internal
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Derive the substandard version.
        uint8 substandard = _decodeOrder(minimumReceived, context);

        // The offer is the minimumReceived which is validated in `_decodeOrder`.
        offer = minimumReceived;

        // All substandards have feeRecipient and minter as first two params.
        address feeRecipient = address(bytes20(context[2:22]));
        address minter = address(bytes20(context[22:42]));

        // If the minter is the zero address, set it to the fulfiller.
        if (minter == address(0)) {
            minter = fulfiller;
        }

        // Start compiling the MintDetails struct to avoid stack too deep.
        uint256 minimumReceivedLength = minimumReceived.length;
        MintDetails memory mintDetails = MintDetails({
            feeRecipient: feeRecipient,
            payer: fulfiller,
            minter: minter,
            tokenIds: new uint256[](minimumReceivedLength),
            quantities: new uint256[](minimumReceivedLength),
            withEffects: withEffects
        });

        // Set the token ids and quantities.
        for (uint256 i = 0; i < minimumReceivedLength; ) {
            mintDetails.tokenIds[i] = minimumReceived[i].identifier;
            mintDetails.quantities[i] = minimumReceived[i].amount;
            unchecked {
                ++i;
            }
        }

        if (substandard == 0) {
            // 0: Public mint
            uint8 publicDropIndex = uint8(bytes1(context[42:43]));
            consideration = _mintPublic(mintDetails, publicDropIndex);
        } else if (substandard == 1) {
            // 1: Allow list mint
            MintParams memory mintParams = abi.decode(
                context[42:458],
                (MintParams)
            );
            // Instead of putting the proof in memory, pass context and offset
            // to use it directly from calldata.
            consideration = _mintAllowList(
                mintDetails,
                mintParams,
                context,
                458
            );
        } else {
            // substandard == 2
            // 2: Signed mint
            uint8 signedMintValidationParamsIndex = uint8(
                bytes1(context[42:43])
            );
            MintParams memory mintParams = abi.decode(
                context[43:459],
                (MintParams)
            );
            uint256 salt = uint256(bytes32(context[459:491]));
            bytes32 signatureR = bytes32(context[491:523]);
            bytes32 signatureVS = bytes32(context[523:555]);
            if (context.length > 555) {
                revert MintSignedSignatureMustBeERC2098Compact();
            }
            consideration = _mintSigned(
                mintDetails,
                signedMintValidationParamsIndex,
                mintParams,
                salt,
                signatureR,
                signatureVS
            );
        }
    }

    /**
     * @notice Mint a public drop stage.
     *
     * @param mintDetails     The mint details.
     * @param publicDropIndex The public drop index to mint.
     */
    function _mintPublic(
        MintDetails memory mintDetails,
        uint8 publicDropIndex
    ) internal returns (ReceivedItem[] memory consideration) {
        // Get the public drop.
        PublicDrop memory publicDrop = ERC1155SeaDropContractOffererStorage
            .layout()
            ._publicDrops[publicDropIndex];

        // Check that the tokenIds are within the range of the stage.
        _checkTokenIds(
            mintDetails.tokenIds,
            publicDrop.fromTokenId,
            publicDrop.toTokenId
        );

        // Check the number of mints are available
        // and reduce quantity if needed..
        uint256 totalQuantity = _checkMintQuantities(
            mintDetails.tokenIds,
            mintDetails.quantities,
            mintDetails.minter,
            publicDrop.maxTotalMintableByWallet,
            publicDrop.maxTotalMintableByWalletPerToken,
            _UNLIMITED_MAX_TOKEN_SUPPLY_FOR_STAGE
        );

        // Check that the stage is active and calculate the current price.
        uint256 currentPrice = _currentPrice(
            publicDrop.startTime,
            publicDrop.endTime,
            publicDrop.startPrice,
            publicDrop.endPrice
        );

        // Validate the mint parameters.
        // If passed withEffects=true, emits an event for analytics.
        consideration = _validateMint(
            mintDetails,
            totalQuantity,
            currentPrice,
            publicDrop.paymentToken,
            publicDrop.feeBps,
            publicDropIndex,
            publicDrop.restrictFeeRecipients
        );
    }

    /**
     * @notice Mint an allow list drop stage.
     *
     * @param mintDetails  The mint details.
     * @param mintParams   The mint parameters.
     * @param context      The context of the order.
     * @param proofOffsetInContext The offset of the proof in the context.
     */
    function _mintAllowList(
        MintDetails memory mintDetails,
        MintParams memory mintParams,
        bytes calldata context,
        uint256 proofOffsetInContext
    ) internal returns (ReceivedItem[] memory consideration) {
        // Verify the proof.
        if (
            !_verifyProof(
                context,
                proofOffsetInContext,
                ERC1155SeaDropContractOffererStorage
                    .layout()
                    ._allowListMerkleRoot,
                keccak256(abi.encode(mintDetails.minter, mintParams))
            )
        ) {
            revert InvalidProof();
        }

        // Check that the tokenIds are within the range of the stage.
        _checkTokenIds(
            mintDetails.tokenIds,
            mintParams.fromTokenId,
            mintParams.toTokenId
        );

        // Check the number of mints are available.
        uint256 totalQuantity = _checkMintQuantities(
            mintDetails.tokenIds,
            mintDetails.quantities,
            mintDetails.minter,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTotalMintableByWalletPerToken,
            mintParams.maxTokenSupplyForStage
        );

        // Check that the stage is active and calculate the current price.
        uint256 currentPrice = _currentPrice(
            mintParams.startTime,
            mintParams.endTime,
            mintParams.startPrice,
            mintParams.endPrice
        );

        // Validate the mint parameters.
        // If passed withEffects=true, emits an event for analytics.
        consideration = _validateMint(
            mintDetails,
            totalQuantity,
            currentPrice,
            mintParams.paymentToken,
            mintParams.feeBps,
            mintParams.dropStageIndex,
            mintParams.restrictFeeRecipients
        );
    }

    /**
     * @notice Mint with a server-side signature.
     *         Note that a signature can only be used once.
     *
     * @param mintDetails  The mint details.
     * @param index        The signed mint validation params index for
     *                     the signer.
     * @param mintParams   The mint parameters.
     * @param salt         The salt for the signed mint.
     * @param signatureR   The server-side signature `r` value.
     * @param signatureVS  The server-side signature `vs` value.
     */
    function _mintSigned(
        MintDetails memory mintDetails,
        uint256 index,
        MintParams memory mintParams,
        uint256 salt,
        bytes32 signatureR,
        bytes32 signatureVS
    ) internal returns (ReceivedItem[] memory consideration) {
        // Get the digest to verify the EIP-712 signature.
        bytes32 digest = _getDigest(
            mintDetails.minter,
            mintDetails.feeRecipient,
            mintParams,
            salt
        );

        // Ensure the digest has not already been used.
        if (
            ERC1155SeaDropContractOffererStorage.layout()._usedDigests[digest]
        ) {
            revert SignatureAlreadyUsed();
        } else if (mintDetails.withEffects) {
            // Mark the digest as used.
            ERC1155SeaDropContractOffererStorage.layout()._usedDigests[
                digest
            ] = true;
        }

        // Check that the tokenId is within the range of the stage.
        _checkTokenIds(
            mintDetails.tokenIds,
            mintParams.fromTokenId,
            mintParams.toTokenId
        );

        // Check the number of mints are available.
        uint256 totalQuantity = _checkMintQuantities(
            mintDetails.tokenIds,
            mintDetails.quantities,
            mintDetails.minter,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTotalMintableByWalletPerToken,
            mintParams.maxTokenSupplyForStage
        );

        // Check that the stage is active and calculate the current price.
        uint256 currentPrice = _currentPrice(
            mintParams.startTime,
            mintParams.endTime,
            mintParams.startPrice,
            mintParams.endPrice
        );

        // Validate the mint parameters.
        // If passed withEffects=true, emits an event for analytics.
        consideration = _validateMint(
            mintDetails,
            totalQuantity,
            currentPrice,
            mintParams.paymentToken,
            mintParams.feeBps,
            mintParams.dropStageIndex,
            mintParams.restrictFeeRecipients
        );

        // Use the recover method to see what address was used to create
        // the signature on this data.
        // Note that if the digest doesn't exactly match what was signed we'll
        // get a random recovered address.
        address recoveredAddress = digest.recover(signatureR, signatureVS);
        _validateSignerAndParams(
            mintParams,
            recoveredAddress,
            index,
            currentPrice
        );
    }

    /**
     * @notice Enforce stored parameters for signed mints to mitigate
     *         the effects of a malicious signer.
     *
     * @param mintParams   The mint parameters.
     * @param signer       The signer.
     * @param index        The index for the signed mint validation params.
     * @param currentPrice The current price.
     */
    function _validateSignerAndParams(
        MintParams memory mintParams,
        address signer,
        uint256 index,
        uint256 currentPrice
    ) internal view {
        SignedMintValidationParams
            memory signedMintValidationParams = ERC1155SeaDropContractOffererStorage
                .layout()
                ._signedMintValidationParams[signer][index];

        // Check that SignedMintValidationParams have been initialized; if not,
        // this is an invalid signer.
        if (signedMintValidationParams.maxMaxTotalMintableByWallet == 0) {
            revert InvalidSignature(signer);
        }

        // Validate individual params.
        if (
            mintParams.paymentToken != signedMintValidationParams.paymentToken
        ) {
            revert InvalidSignedPaymentToken(
                mintParams.paymentToken,
                signedMintValidationParams.paymentToken
            );
        }
        if (currentPrice < signedMintValidationParams.minMintPrice) {
            revert InvalidSignedMintPrice(
                mintParams.paymentToken,
                currentPrice,
                signedMintValidationParams.minMintPrice
            );
        }
        if (
            mintParams.fromTokenId < signedMintValidationParams.minFromTokenId
        ) {
            revert InvalidSignedFromTokenId(
                mintParams.fromTokenId,
                signedMintValidationParams.minFromTokenId
            );
        }
        if (mintParams.toTokenId > signedMintValidationParams.maxToTokenId) {
            revert InvalidSignedToTokenId(
                mintParams.toTokenId,
                signedMintValidationParams.maxToTokenId
            );
        }
        if (
            mintParams.maxTotalMintableByWallet >
            signedMintValidationParams.maxMaxTotalMintableByWallet
        ) {
            revert InvalidSignedMaxTotalMintableByWallet(
                mintParams.maxTotalMintableByWallet,
                signedMintValidationParams.maxMaxTotalMintableByWallet
            );
        }
        if (
            mintParams.maxTotalMintableByWalletPerToken >
            signedMintValidationParams.maxMaxTotalMintableByWalletPerToken
        ) {
            revert InvalidSignedMaxTotalMintableByWalletPerToken(
                mintParams.maxTotalMintableByWalletPerToken,
                signedMintValidationParams.maxMaxTotalMintableByWalletPerToken
            );
        }
        if (mintParams.startTime < signedMintValidationParams.minStartTime) {
            revert InvalidSignedStartTime(
                mintParams.startTime,
                signedMintValidationParams.minStartTime
            );
        }
        if (mintParams.endTime > signedMintValidationParams.maxEndTime) {
            revert InvalidSignedEndTime(
                mintParams.endTime,
                signedMintValidationParams.maxEndTime
            );
        }
        if (
            mintParams.maxTokenSupplyForStage >
            signedMintValidationParams.maxMaxTokenSupplyForStage
        ) {
            revert InvalidSignedMaxTokenSupplyForStage(
                mintParams.maxTokenSupplyForStage,
                signedMintValidationParams.maxMaxTokenSupplyForStage
            );
        }
        if (mintParams.feeBps > signedMintValidationParams.maxFeeBps) {
            revert InvalidSignedFeeBps(
                mintParams.feeBps,
                signedMintValidationParams.maxFeeBps
            );
        }
        if (mintParams.feeBps < signedMintValidationParams.minFeeBps) {
            revert InvalidSignedFeeBps(
                mintParams.feeBps,
                signedMintValidationParams.minFeeBps
            );
        }
        if (!mintParams.restrictFeeRecipients) {
            revert SignedMintsMustRestrictFeeRecipients();
        }
    }

    /**
     * @dev Validates a mint, reverting if the mint is invalid.
     *      If withEffects=true, sets mint recipient and emits an event.
     *
     * @param mintDetails           The mint details.
     * @param totalQuantity         The total quantity of tokens to mint.
     * @param currentPrice          The current price of the stage.
     * @param paymentToken          The payment token.
     * @param feeBps                The fee basis points.
     * @param dropStageIndex        The drop stage index.
     * @param restrictFeeRecipients Whether to restrict fee recipients.
     */
    function _validateMint(
        MintDetails memory mintDetails,
        uint256 totalQuantity,
        uint256 currentPrice,
        address paymentToken,
        uint256 feeBps,
        uint256 dropStageIndex,
        bool restrictFeeRecipients
    ) internal returns (ReceivedItem[] memory consideration) {
        // Check the payer is allowed.
        _checkPayerIsAllowed(mintDetails.payer, mintDetails.minter);

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            mintDetails.feeRecipient,
            restrictFeeRecipients
        );

        // Set the required consideration items.
        consideration = _requiredConsideration(
            mintDetails.feeRecipient,
            feeBps,
            totalQuantity,
            currentPrice,
            paymentToken
        );

        // Apply the state changes of the mint.
        if (mintDetails.withEffects) {
            // Emit an event for the mint, for analytics.
            emit SeaDropMint(mintDetails.payer, dropStageIndex);
        }
    }

    /**
     * @dev Internal view function to derive the current price of a stage
     *      based on the the starting price and ending price. If the start
     *      and end prices differ, the current price will be interpolated on
     *      a linear basis.
     *
     *      Since this function is only used for consideration items, it will
     *      round up.
     *
     * @param startTime  The starting time of the stage.
     * @param endTime    The end time of the stage.
     * @param startPrice The starting price of the stage.
     * @param endPrice   The ending price of the stage.
     *
     * @return price The current price.
     */
    function _currentPrice(
        uint256 startTime,
        uint256 endTime,
        uint256 startPrice,
        uint256 endPrice
    ) internal view returns (uint256 price) {
        // Check that the drop stage has started and not ended.
        // This ensures that the startTime is not greater than the current
        // block timestamp and endTime is greater than the current block
        // timestamp. If this condition is not upheld `duration`, `elapsed`,
        // and `remaining` variables will underflow.
        _checkActive(startTime, endTime);

        // Return the price if startPrice == endPrice.
        if (startPrice == endPrice) {
            return endPrice;
        }

        // Declare variables to derive in the subsequent unchecked scope.
        uint256 duration;
        uint256 elapsed;
        uint256 remaining;

        // Skip underflow checks as startTime <= block.timestamp < endTime.
        unchecked {
            // Derive the duration for the stage and place it on the stack.
            duration = endTime - startTime;

            // Derive time elapsed since the stage started & place on stack.
            elapsed = block.timestamp - startTime;

            // Derive time remaining until stage expires and place on stack.
            remaining = duration - elapsed;
        }

        // Aggregate new amounts weighted by time with rounding factor.
        uint256 totalBeforeDivision = ((startPrice * remaining) +
            (endPrice * elapsed));

        // Use assembly to combine operations and skip divide-by-zero check.
        assembly {
            // Multiply by iszero(iszero(totalBeforeDivision)) to ensure
            // amount is set to zero if totalBeforeDivision is zero,
            // as intermediate overflow can occur if it is zero.
            price := mul(
                iszero(iszero(totalBeforeDivision)),
                // Subtract 1 from the numerator and add 1 to the result
                // to get the proper rounding direction to round up.
                // Division is performed with no zero check as duration
                // cannot be zero as long as startTime < endTime.
                add(div(sub(totalBeforeDivision, 1), duration), 1)
            )
        }
    }

    /**
     * @notice Check that the token ids are within the stage range.
     *
     * @param tokenIds    The token ids.
     * @param fromTokenId The drop stage start token id
     * @param toTokenId   The drop stage end token id.
     */
    function _checkTokenIds(
        uint256[] memory tokenIds,
        uint256 fromTokenId,
        uint256 toTokenId
    ) internal pure {
        uint256 tokenIdsLength = tokenIds.length;
        for (uint256 i = 0; i < tokenIdsLength; ) {
            if (
                _cast(tokenIds[i] < fromTokenId) |
                    _cast(tokenIds[i] > toTokenId) ==
                1
            ) {
                // Revert if the token id is not within range.
                revert TokenIdNotWithinDropStageRange(
                    tokenIds[i],
                    fromTokenId,
                    toTokenId
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Check that the drop stage is active.
     *
     * @param startTime The drop stage start time.
     * @param endTime   The drop stage end time.
     */
    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        // Define a variable if the drop stage is active.
        bool valid;

        // Using the same check for time boundary from Seaport.
        // startTime <= block.timestamp < endTime
        assembly {
            valid := and(
                iszero(gt(startTime, timestamp())),
                gt(endTime, timestamp())
            )
        }

        // Revert if the drop stage is not active.
        if (!valid) {
            revert NotActive(block.timestamp, startTime, endTime);
        }
    }

    /**
     * @notice Check that the fee recipient is allowed.
     *
     * @param feeRecipient          The fee recipient.
     * @param restrictFeeRecipients If the fee recipients are restricted.
     */
    function _checkFeeRecipientIsAllowed(
        address feeRecipient,
        bool restrictFeeRecipients
    ) internal view {
        // Ensure the fee recipient is not the zero address.
        if (feeRecipient == address(0)) {
            revert FeeRecipientCannotBeZeroAddress();
        }

        // Revert if the fee recipient is restricted and not allowed.
        if (restrictFeeRecipients)
            if (
                !ERC1155SeaDropContractOffererStorage
                    .layout()
                    ._allowedFeeRecipients[feeRecipient]
            ) {
                revert FeeRecipientNotAllowed(feeRecipient);
            }
    }

    /**
     * @notice Check that the payer is allowed when not the minter.
     *
     * @param payer The payer.
     * @param minter The minter.
     */
    function _checkPayerIsAllowed(address payer, address minter) internal view {
        if (
            // Note: not using _cast pattern here to short-circuit
            // and skip loading the allowed payers or delegation registry.
            payer != minter &&
            !ERC1155SeaDropContractOffererStorage.layout()._allowedPayers[
                payer
            ] &&
            !DELEGATION_REGISTRY.checkDelegateForAll(payer, minter)
        ) {
            revert PayerNotAllowed(payer);
        }
    }

    /**
     * @notice Check that the wallet is allowed to mint the desired quantities.
     *
     * @param tokenIds                 The token ids.
     * @param quantities               The number of tokens to mint per token id.
     * @param minter                   The mint recipient.
     * @param maxTotalMintableByWallet The max allowed mints per wallet.
     * @param maxTotalMintableByWalletPerToken The max allowed mints per wallet per token.
     * @param maxTokenSupplyForStage   The max token supply for the drop stage.
     */
    function _checkMintQuantities(
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        address minter,
        uint256 maxTotalMintableByWallet,
        uint256 maxTotalMintableByWalletPerToken,
        uint256 maxTokenSupplyForStage
    ) internal view returns (uint256 totalQuantity) {
        // Put the token ids length on the stack.
        uint256 tokenIdsLength = tokenIds.length;

        // Define an array of seenTokenIds to ensure there are no duplicates.
        uint256[] memory seenTokenIds = new uint256[](tokenIdsLength);
        uint256 seenTokenIdsCurrentLength;

        for (uint256 i = 0; i < tokenIdsLength; ) {
            // Put the tokenId and quantity on the stack.
            uint256 tokenId = tokenIds[i];
            uint256 quantity = quantities[i];

            // Revert if the offer contains duplicate token ids.
            for (uint256 j = 0; j < seenTokenIdsCurrentLength; ) {
                if (tokenId == seenTokenIds[j]) {
                    revert OfferContainsDuplicateTokenId(tokenId);
                }
                unchecked {
                    ++j;
                }
            }

            // Add to seen token ids.
            seenTokenIds[i] = tokenId;
            seenTokenIdsCurrentLength += 1;

            // Add to total mint quantity.
            totalQuantity += quantity;

            // Check the mint quantities.
            _checkMintQuantity(
                tokenId,
                quantity,
                // Only check totalQuantity on the last iteration.
                i == tokenIdsLength - 1 ? totalQuantity : 0,
                minter,
                maxTotalMintableByWallet,
                maxTotalMintableByWalletPerToken,
                maxTokenSupplyForStage
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Check that the wallet is allowed to mint the desired quantity.
     *
     * @param tokenId                  The token id.
     * @param quantity                 The number of tokens to mint.
     * @param totalQuantity            When provided as a nonzero value ensures
     *                                 doesn't exceed maxTotalMintableByWallet.
     * @param minter                   The mint recipient.
     * @param maxTotalMintableByWallet The max allowed mints per wallet.
     * @param maxTotalMintableByWalletPerToken The max allowed mints per wallet per token.
     * @param maxTokenSupplyForStage   The max token supply for the drop stage.
     */
    function _checkMintQuantity(
        uint256 tokenId,
        uint256 quantity,
        uint256 totalQuantity,
        address minter,
        uint256 maxTotalMintableByWallet,
        uint256 maxTotalMintableByWalletPerToken,
        uint256 maxTokenSupplyForStage
    ) internal view {
        // Get the mint stats from the token contract.
        (bool success, bytes memory data) = address(this).staticcall(
            abi.encodeWithSelector(
                IERC1155SeaDrop.getMintStats.selector,
                minter,
                tokenId
            )
        );

        // Require that the call was successful.
        if (!success) _revertWithReason(data);

        // Decode the returned mint stats.
        (
            uint256 minterNumMinted,
            uint256 minterNumMintedForTokenId,
            uint256 totalMintedForTokenId,
            uint256 maxSupply
        ) = abi.decode(data, (uint256, uint256, uint256, uint256));

        // Ensure mint quantity doesn't exceed maxTotalMintableByWalletPerToken.
        if (
            quantity + minterNumMintedForTokenId >
            maxTotalMintableByWalletPerToken
        ) {
            revert MintQuantityExceedsMaxMintedPerWalletForTokenId(
                tokenId,
                quantity + minterNumMinted,
                maxTotalMintableByWalletPerToken
            );
        }

        // Ensure mint quantity doesn't exceed maxSupply.
        if (quantity + totalMintedForTokenId > maxSupply) {
            revert MintQuantityExceedsMaxSupply(
                quantity + totalMintedForTokenId,
                maxSupply
            );
        }

        // Ensure mint quantity doesn't exceed maxTokenSupplyForStage.
        if (quantity + totalMintedForTokenId > maxTokenSupplyForStage) {
            revert MintQuantityExceedsMaxTokenSupplyForStage(
                quantity + totalMintedForTokenId,
                maxTokenSupplyForStage
            );
        }

        // If totalQuantity is provided, ensure it doesn't exceed maxTotalMintableByWallet.
        if (totalQuantity != 0) {
            // Ensure total mint quantity doesn't exceed maxTotalMintableByWallet.
            if (totalQuantity + minterNumMinted > maxTotalMintableByWallet) {
                revert MintQuantityExceedsMaxMintedPerWallet(
                    totalQuantity + minterNumMinted,
                    maxTotalMintableByWallet
                );
            }
        } else {
            // Otherwise, just check the quantity.
            // Ensure mint quantity doesn't exceed maxTotalMintableByWallet.
            if (quantity + minterNumMinted > maxTotalMintableByWallet) {
                revert MintQuantityExceedsMaxMintedPerWallet(
                    quantity + minterNumMinted,
                    maxTotalMintableByWallet
                );
            }
        }
    }

    /**
     * @notice Derive the required consideration items for the mint,
     *         includes the fee recipient and creator payouts.
     *
     * @param feeRecipient The fee recipient.
     * @param feeBps       The fee basis points.
     * @param quantity     The total number of tokens to mint.
     * @param currentPrice The current price of each token.
     * @param paymentToken The payment token.
     */
    function _requiredConsideration(
        address feeRecipient,
        uint256 feeBps,
        uint256 quantity,
        uint256 currentPrice,
        address paymentToken
    ) internal view returns (ReceivedItem[] memory receivedItems) {
        // If the mint price is zero, return early as there
        // are no required consideration items.
        if (currentPrice == 0) {
            return new ReceivedItem[](0);
        }

        // Revert if the fee basis points are greater than 10_000.
        if (feeBps > 10_000) {
            revert InvalidFeeBps(feeBps);
        }

        // Set the itemType.
        ItemType itemType = paymentToken == address(0)
            ? ItemType.NATIVE
            : ItemType.ERC20;

        // Put the total mint price on the stack.
        uint256 totalPrice = quantity * currentPrice;

        // Get the fee amount.
        // Note that the fee amount is rounded down in favor of the creator.
        uint256 feeAmount = (totalPrice * feeBps) / 10_000;

        // Get the creator payout amount.
        // Fee amount is <= totalPrice per above.
        uint256 payoutAmount;
        unchecked {
            payoutAmount = totalPrice - feeAmount;
        }

        // Put the creator payouts on the stack.
        CreatorPayout[]
            storage creatorPayouts = ERC1155SeaDropContractOffererStorage
                .layout()
                ._creatorPayouts;

        // Put the length of total creator payouts on the stack.
        uint256 creatorPayoutsLength = creatorPayouts.length;

        // Revert if the creator payouts are not set.
        if (creatorPayoutsLength == 0) {
            revert CreatorPayoutsNotSet();
        }

        // Put the start index including the fee on the stack.
        uint256 startIndexWithFee = feeAmount != 0 ? 1 : 0;

        // Initialize the returned array with the correct length.
        receivedItems = new ReceivedItem[](
            startIndexWithFee + creatorPayoutsLength
        );

        // Add a consideration item for the fee recipient.
        if (feeAmount != 0) {
            receivedItems[0] = ReceivedItem({
                itemType: itemType,
                token: paymentToken,
                identifier: uint256(0),
                amount: feeAmount,
                recipient: payable(feeRecipient)
            });
        }

        // Add a consideration item for each creator payout.
        for (uint256 i = 0; i < creatorPayoutsLength; ) {
            // Put the creator payout on the stack.
            CreatorPayout memory creatorPayout = creatorPayouts[i];

            // Get the creator payout amount.
            // Note that the payout amount is rounded down.
            uint256 creatorPayoutAmount = (payoutAmount *
                creatorPayout.basisPoints) / 10_000;

            receivedItems[startIndexWithFee + i] = ReceivedItem({
                itemType: itemType,
                token: paymentToken,
                identifier: uint256(0),
                amount: creatorPayoutAmount,
                recipient: payable(creatorPayout.payoutAddress)
            });

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Internal view function to derive the EIP-712 domain separator.
     *
     * @return The derived domain separator.
     */
    function _deriveDomainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @notice Implementation function to update the allowed Seaport contracts.
     *
     *         Do not use this method directly.
     *
     * @param allowedSeaport The allowed Seaport addresses.
     */
    function updateAllowedSeaport(address[] calldata allowedSeaport) external {
        // Put the lengths on the stack for more efficient access.
        uint256 allowedSeaportLength = allowedSeaport.length;
        uint256 enumeratedAllowedSeaportLength = ERC1155SeaDropContractOffererStorage
                .layout()
                ._enumeratedAllowedSeaport
                .length;

        // Reset the old mapping.
        for (uint256 i = 0; i < enumeratedAllowedSeaportLength; ) {
            ERC1155SeaDropContractOffererStorage.layout()._allowedSeaport[
                ERC1155SeaDropContractOffererStorage
                    .layout()
                    ._enumeratedAllowedSeaport[i]
            ] = false;
            unchecked {
                ++i;
            }
        }

        // Set the new mapping for allowed Seaport contracts.
        for (uint256 i = 0; i < allowedSeaportLength; ) {
            // Ensure the allowed Seaport address is not the zero address.
            if (allowedSeaport[i] == address(0)) {
                revert AllowedSeaportCannotBeZeroAddress();
            }

            ERC1155SeaDropContractOffererStorage.layout()._allowedSeaport[
                allowedSeaport[i]
            ] = true;
            unchecked {
                ++i;
            }
        }

        // Set the enumeration.
        ERC1155SeaDropContractOffererStorage
            .layout()
            ._enumeratedAllowedSeaport = allowedSeaport;

        // Emit an event for the update.
        emit AllowedSeaportUpdated(allowedSeaport);
    }

    /**
     * @notice Updates the creator payouts and emits an event.
     *         The basis points must add up to 10_000 exactly.
     *
     * @param creatorPayouts The creator payout address and basis points.
     */
    function updateCreatorPayouts(
        CreatorPayout[] calldata creatorPayouts
    ) external {
        // Reset the creator payout array.
        delete ERC1155SeaDropContractOffererStorage.layout()._creatorPayouts;

        // Track the total basis points.
        uint256 totalBasisPoints;

        // Put the total creator payouts length on the stack.
        uint256 creatorPayoutsLength = creatorPayouts.length;

        // Revert if no creator payouts were provided.
        if (creatorPayoutsLength == 0) {
            revert CreatorPayoutsNotSet();
        }

        for (uint256 i; i < creatorPayoutsLength; ) {
            // Get the creator payout.
            CreatorPayout memory creatorPayout = creatorPayouts[i];

            // Ensure the creator payout address is not the zero address.
            if (creatorPayout.payoutAddress == address(0)) {
                revert CreatorPayoutAddressCannotBeZeroAddress();
            }

            // Ensure the basis points are not zero.
            if (creatorPayout.basisPoints == 0) {
                revert CreatorPayoutBasisPointsCannotBeZero();
            }

            // Add to the total basis points.
            totalBasisPoints += creatorPayout.basisPoints;

            // Push to storage.
            ERC1155SeaDropContractOffererStorage.layout()._creatorPayouts.push(
                creatorPayout
            );

            unchecked {
                ++i;
            }
        }

        // Ensure the total basis points equals 10_000 exactly.
        if (totalBasisPoints != 10_000) {
            revert InvalidCreatorPayoutTotalBasisPoints(totalBasisPoints);
        }

        // Emit an event with the update.
        emit CreatorPayoutsUpdated(creatorPayouts);
    }

    /**
     * @notice Updates the allowed fee recipient and emits an event.
     *
     * @param feeRecipient The fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address feeRecipient,
        bool allowed
    ) external {
        if (feeRecipient == address(0)) {
            revert FeeRecipientCannotBeZeroAddress();
        }

        // Track the enumerated storage.
        address[]
            storage enumeratedStorage = ERC1155SeaDropContractOffererStorage
                .layout()
                ._enumeratedFeeRecipients;
        mapping(address => bool)
            storage feeRecipientsMap = ERC1155SeaDropContractOffererStorage
                .layout()
                ._allowedFeeRecipients;

        if (allowed) {
            if (feeRecipientsMap[feeRecipient]) {
                revert DuplicateFeeRecipient();
            }
            feeRecipientsMap[feeRecipient] = true;
            enumeratedStorage.push(feeRecipient);
        } else {
            if (!feeRecipientsMap[feeRecipient]) {
                revert FeeRecipientNotPresent();
            }
            delete ERC1155SeaDropContractOffererStorage
                .layout()
                ._allowedFeeRecipients[feeRecipient];
            _asAddressArray(_removeFromEnumeration)(
                feeRecipient,
                enumeratedStorage
            );
        }

        // Emit an event with the update.
        emit AllowedFeeRecipientUpdated(feeRecipient, allowed);
    }

    /**
     * @notice Updates the allowed server-side signers and emits an event.
     *
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters
     *                                   to enforce for signed mints.
     * @param index                      The index for the signer's mint
     *                                   validation params.
     */
    function updateSignedMintValidationParams(
        address signer,
        SignedMintValidationParams calldata signedMintValidationParams,
        uint256 index
    ) external {
        if (signer == address(0)) {
            revert SignerCannotBeZeroAddress();
        }

        // Revert if the min or max fee bps is greater than 10_000.
        if (signedMintValidationParams.maxFeeBps > 10_000) {
            revert InvalidFeeBps(signedMintValidationParams.maxFeeBps);
        }
        if (
            signedMintValidationParams.minFeeBps >
            signedMintValidationParams.maxFeeBps
        ) {
            revert InvalidFeeBps(signedMintValidationParams.minFeeBps);
        }

        // Track the enumerated storage.
        address[]
            storage enumeratedSignersStorage = ERC1155SeaDropContractOffererStorage
                .layout()
                ._enumeratedSigners;
        mapping(address => mapping(uint256 => SignedMintValidationParams))
            storage signedMintValidationParamsMap = ERC1155SeaDropContractOffererStorage
                .layout()
                ._signedMintValidationParams;
        mapping(address => uint256[])
            storage enumeratedSignedMintValidationParamsIndexesStorage = ERC1155SeaDropContractOffererStorage
                .layout()
                ._enumeratedSignedMintValidationParamsIndexes;
        SignedMintValidationParams
            storage existingSignedMintValidationParams = signedMintValidationParamsMap[
                signer
            ][index];

        // Validation params struct packs to two slots, so load it
        // as a uint256; if it is 0, it is empty.
        bool signedMintValidationParamsDoesNotExist;
        assembly {
            signedMintValidationParamsDoesNotExist := iszero(
                or(
                    sload(existingSignedMintValidationParams.slot),
                    sload(add(existingSignedMintValidationParams.slot, 1))
                )
            )
        }
        // Use maxMaxTotalMintableByWallet as sentry for add/update or delete.
        bool addOrUpdate = signedMintValidationParams
            .maxMaxTotalMintableByWallet != 0;

        if (addOrUpdate) {
            signedMintValidationParamsMap[signer][
                index
            ] = signedMintValidationParams;
            if (signedMintValidationParamsDoesNotExist) {
                enumeratedSignersStorage.push(signer);
                enumeratedSignedMintValidationParamsIndexesStorage[signer].push(
                    index
                );
            }
        } else {
            if (
                existingSignedMintValidationParams
                    .maxMaxTotalMintableByWallet == 0
            ) {
                revert SignerNotPresent();
            }
            delete ERC1155SeaDropContractOffererStorage
                .layout()
                ._signedMintValidationParams[signer][index];
            _asAddressArray(_removeFromEnumeration)(
                signer,
                enumeratedSignersStorage
            );
            _removeFromEnumeration(
                index,
                enumeratedSignedMintValidationParamsIndexesStorage[signer]
            );
        }

        // Emit an event with the update.
        emit SignedMintValidationParamsUpdated(
            signer,
            signedMintValidationParams,
            index
        );
    }

    /**
     * @notice Updates the allowed payer and emits an event.
     *
     * @param payer   The payer to add or remove.
     * @param allowed Whether to add or remove the payer.
     */
    function updatePayer(address payer, bool allowed) external {
        if (payer == address(0)) {
            revert PayerCannotBeZeroAddress();
        }

        // Track the enumerated storage.
        address[]
            storage enumeratedStorage = ERC1155SeaDropContractOffererStorage
                .layout()
                ._enumeratedPayers;
        mapping(address => bool)
            storage payersMap = ERC1155SeaDropContractOffererStorage
                .layout()
                ._allowedPayers;

        if (allowed) {
            if (payersMap[payer]) {
                revert DuplicatePayer();
            }
            payersMap[payer] = true;
            enumeratedStorage.push(payer);
        } else {
            if (!payersMap[payer]) {
                revert PayerNotPresent();
            }
            delete ERC1155SeaDropContractOffererStorage.layout()._allowedPayers[
                payer
            ];
            _asAddressArray(_removeFromEnumeration)(payer, enumeratedStorage);
        }

        // Emit an event with the update.
        emit PayerUpdated(payer, allowed);
    }

    /**
     * @notice Verify an EIP-712 signature by recreating the data structure
     *         that we signed on the client side, and then using that to recover
     *         the address that signed the signature for this data.
     *
     * @param minter       The mint recipient.
     * @param feeRecipient The fee recipient.
     * @param mintParams   The mint params.
     * @param salt         The salt for the signed mint.
     */
    function _getDigest(
        address minter,
        address feeRecipient,
        MintParams memory mintParams,
        uint256 salt
    ) internal view returns (bytes32 digest) {
        // Put mintParams back on the stack to avoid stack too deep.
        MintParams memory mintParams_ = mintParams;

        bytes32 mintParamsHashStruct = keccak256(
            abi.encode(
                _MINT_PARAMS_TYPEHASH,
                mintParams_.startPrice,
                mintParams_.endPrice,
                mintParams_.startTime,
                mintParams_.endTime,
                mintParams_.paymentToken,
                mintParams_.fromTokenId,
                mintParams_.toTokenId,
                mintParams_.maxTotalMintableByWallet,
                mintParams_.maxTotalMintableByWalletPerToken,
                mintParams_.maxTokenSupplyForStage,
                mintParams_.dropStageIndex,
                mintParams_.feeBps,
                mintParams_.restrictFeeRecipients
            )
        );
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _deriveDomainSeparator(),
                keccak256(
                    abi.encode(
                        _SIGNED_MINT_TYPEHASH,
                        minter,
                        feeRecipient,
                        mintParamsHashStruct,
                        salt
                    )
                )
            )
        );
    }

    /**
     * @notice Internal utility function to remove a uint256 from a supplied
     *         enumeration.
     *
     * @param toRemove    The uint256 to remove.
     * @param enumeration The enumerated uint256s to parse.
     */
    function _removeFromEnumeration(
        uint256 toRemove,
        uint256[] storage enumeration
    ) internal {
        // Cache the length.
        uint256 enumerationLength = enumeration.length;
        for (uint256 i = 0; i < enumerationLength; ) {
            // Check if the enumerated element is the one we are deleting.
            if (enumeration[i] == toRemove) {
                // Swap with the last element.
                enumeration[i] = enumeration[enumerationLength - 1];
                // Delete the (now duplicated) last element.
                enumeration.pop();
                // Exit the loop.
                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal utility function to cast uint types to address
     *         to dedupe the need for multiple implementations of
     *         `_removeFromEnumeration`.
     *
     * @param fnIn The fn with uint input.
     *
     * @return fnOut The fn with address input.
     */
    function _asAddressArray(
        function(uint256, uint256[] storage) internal fnIn
    )
        internal
        pure
        returns (function(address, address[] storage) internal fnOut)
    {
        assembly {
            fnOut := fnIn
        }
    }

    /**
     * @dev Returns whether `leaf` exists in the Merkle tree with `root`,
     *      given `proof`.
     *
     *      Original function from solady called `verifyCalldata`, modified
     *      to use an offset from the context calldata to avoid expanding
     *      memory.
     */
    function _verifyProof(
        bytes calldata context,
        uint256 proofOffsetInContext,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        /// @solidity memory-safe-assembly
        assembly {
            if sub(context.length, proofOffsetInContext) {
                // Initialize `offset` to the offset of `proof` in the calldata.
                let offset := add(context.offset, proofOffsetInContext)
                let end := add(
                    offset,
                    sub(context.length, proofOffsetInContext)
                )
                // Iterate over proof elements to compute root hash.
                // prettier-ignore
                for {} 1 {} {
                    // Slot of `leaf` in scratch space.
                    // If the condition is true: 0x20, otherwise: 0x00.
                    let scratch := shl(5, gt(leaf, calldataload(offset)))
                    // Store elements to hash contiguously in scratch space.
                    // Scratch space is 64 bytes (0x00 - 0x3f) and both elements are 32 bytes.
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), calldataload(offset))
                    // Reuse `leaf` to store the hash to reduce stack operations.
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) {
                        break
                    }
                }
            }
            isValid := eq(leaf, root)
        }
    }

    /**
     * @dev Internal view function to revert if this implementation contract is
     *      called without delegatecall.
     */
    function _onlyDelegateCalled() internal view {
        if (address(this) == _originalImplementation) {
            revert OnlyDelegateCalled();
        }
    }

    /**
     * @dev Internal pure function to revert with a provided reason.
     *      If no reason is provided, reverts with no message.
     */
    function _revertWithReason(bytes memory data) internal pure {
        // Bubble up the revert reason.
        assembly {
            revert(add(32, data), mload(data))
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value,
     *      then invert to match Unix style where 0 signifies success.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _castAndInvert(bool b) internal pure returns (uint256 u) {
        assembly {
            u := iszero(b)
        }
    }

    /**
     * @dev Internal pure function to cast a `bool` value to a `uint256` value.
     *
     * @param b The `bool` value to cast.
     *
     * @return u The `uint256` value.
     */
    function _cast(bool b) internal pure returns (uint256 u) {
        assembly {
            u := b
        }
    }
}
