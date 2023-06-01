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

import "./ERC1155SeaDropConstants.sol";

import { IDelegationRegistry } from "../interfaces/IDelegationRegistry.sol";

import { ItemType } from "seaport-types/src/lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    SpentItem,
    Schema
} from "seaport-types/src/lib/ConsiderationStructs.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

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
    constructor() {}

    /**
     * @notice The fallback function is used as a dispatcher for SeaDrop
     *         methods.
     */
    fallback(bytes calldata) external returns (bytes memory output) {
        // Get the function selector.
        bytes4 selector = msg.sig;

        // Get the rest of the msg data after the selector.
        bytes calldata data = msg.data[4:];

        if (selector == GET_PUBLIC_DROP_SELECTOR) {
            // Get the public drop index.
            uint256 publicDropIndex = uint256(bytes32(data[:32]));

            // Return the public drop.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage.layout()._publicDrops[
                        publicDropIndex
                    ]
                );
        } else if (selector == GET_PUBLIC_DROP_INDEXES_SELECTOR) {
            // Return the public drop indexes.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedPublicDropIndexes
                );
        } else if (selector == GET_CREATOR_PAYOUTS_SELECTOR) {
            // Return the creator payouts.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._creatorPayouts
                );
        } else if (selector == GET_ALLOW_LIST_MERKLE_ROOT_SELECTOR) {
            // Return the creator payouts.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._allowListMerkleRoot
                );
        } else if (selector == GET_ALLOWED_FEE_RECIPIENTS_SELECTOR) {
            // Return the allowed fee recipients.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedFeeRecipients
                );
        } else if (selector == GET_SIGNERS_SELECTOR) {
            // Return the allowed signers.
            return
                abi.encode(
                    ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._enumeratedSigners
                );
        } else if (selector == GET_SIGNED_MINT_VALIDATION_PARAMS_SELECTOR) {
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
            selector == GET_SIGNED_MINT_VALIDATION_PARAMS_INDEXES_SELECTOR
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
        } else if (selector == GET_PAYERS_SELECTOR) {
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
        // Revert if the fee basis points is greater than 10_000.
        if (publicDrop.feeBps > 10_000) {
            revert InvalidFeeBps(publicDrop.feeBps);
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
                add(
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
        uint256 errorBuffer = 0;
        uint256 minimumReceivedLength = minimumReceived.length;
        for (uint256 i = 0; i < minimumReceivedLength; ) {
            errorBuffer |= _castAndInvert(
                minimumReceived[i].itemType == ItemType.ERC1155 &&
                    minimumReceived[i].token == address(this)
            );
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

        // Next, check for correct context length. Minimum is 42 bytes
        // (version byte, substandard byte, feeRecipient, minter)
        unchecked {
            errorBuffer |= _castAndInvert(context.length > 41) << 3;
        }

        // Handle decoding errors.
        if (errorBuffer != 0) {
            uint8 version = uint8(context[0]);

            if (errorBuffer << 255 != 0) {
                revert MustSpecifyERC1155ConsiderationItemForSeaDropMint();
            } else if (errorBuffer << 254 != 0) {
                revert UnsupportedExtraDataVersion(version);
            } else if (errorBuffer << 253 != 0) {
                revert InvalidSubstandard(substandard);
            } else {
                // errorBuffer << 252 != 0
                revert InvalidExtraDataEncoding(version);
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
        // The offer is the minimumReceived.
        offer = minimumReceived;

        // Derive the substandard version.
        uint8 substandard = _decodeOrder(minimumReceived, context);

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
            bytes32[] memory proof = _bytesToBytes32Array(context[458:]);
            consideration = _mintAllowList(mintDetails, mintParams, proof);
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
            bytes memory signature = context[491:];
            consideration = _mintSigned(
                mintDetails,
                signedMintValidationParamsIndex,
                mintParams,
                salt,
                signature
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
     * @param proof        The proof for the leaf of the allow list.
     */
    function _mintAllowList(
        MintDetails memory mintDetails,
        MintParams memory mintParams,
        bytes32[] memory proof
    ) internal returns (ReceivedItem[] memory consideration) {
        // Verify the proof.
        if (
            !MerkleProof.verify(
                proof,
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
     * @param signature    The server-side signature, must be an allowed
     *                     signer.
     */
    function _mintSigned(
        MintDetails memory mintDetails,
        uint256 index,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
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
        address recoveredAddress = digest.recover(signature);
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
                _cast(tokenIds[i] < fromTokenId || tokenIds[i] > toTokenId) == 1
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
        if (
            _cast(block.timestamp < startTime || block.timestamp > endTime) == 1
        ) {
            // Revert if the drop stage is not active.
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
            _cast(
                payer != minter &&
                    !ERC1155SeaDropContractOffererStorage
                        .layout()
                        ._allowedPayers[payer] &&
                    !DELEGATION_REGISTRY.checkDelegateForAll(payer, minter)
            ) == 1
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
        uint256 tokenIdsLength = tokenIds.length;
        for (uint256 i = 0; i < tokenIdsLength; ) {
            _checkMintQuantity(
                tokenIds[i],
                quantities[i],
                minter,
                maxTotalMintableByWallet,
                maxTotalMintableByWalletPerToken,
                maxTokenSupplyForStage
            );
            totalQuantity += quantities[i];
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
     * @param minter                   The mint recipient.
     * @param maxTotalMintableByWallet The max allowed mints per wallet.
     * @param maxTotalMintableByWalletPerToken The max allowed mints per wallet per token.
     * @param maxTokenSupplyForStage   The max token supply for the drop stage.
     */
    function _checkMintQuantity(
        uint256 tokenId,
        uint256 quantity,
        address minter,
        uint256 maxTotalMintableByWallet,
        uint256 maxTotalMintableByWalletPerToken,
        uint256 maxTokenSupplyForStage
    ) internal view {
        // Get the mint stats from the token contract.
        (bool success, bytes memory data) = address(this).staticcall(
            abi.encodeWithSelector(GET_MINT_STATS_SELECTOR, minter, tokenId)
        );

        // Require that the call was successful.
        if (!success) _revertWithReason(data);

        // Decode the returned mint stats.
        (
            uint256 minterNumMinted,
            uint256 minterNumMintedForTokenId,
            uint256 currentTotalSupply,
            uint256 maxSupply
        ) = abi.decode(data, (uint256, uint256, uint256, uint256));

        // Ensure mint quantity doesn't exceed maxTotalMintableByWallet.
        if (quantity + minterNumMinted > maxTotalMintableByWallet) {
            revert MintQuantityExceedsMaxMintedPerWallet(
                quantity + minterNumMinted,
                maxTotalMintableByWallet
            );
        }

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
        if (quantity + currentTotalSupply > maxSupply) {
            revert MintQuantityExceedsMaxSupply(
                quantity + currentTotalSupply,
                maxSupply
            );
        }

        // Ensure mint quantity doesn't exceed maxTokenSupplyForStage.
        if (quantity + currentTotalSupply > maxTokenSupplyForStage) {
            revert MintQuantityExceedsMaxTokenSupplyForStage(
                quantity + currentTotalSupply,
                maxTokenSupplyForStage
            );
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

        // Set the new mapping for allowed SeaDrop contracts.
        for (uint256 i = 0; i < allowedSeaportLength; ) {
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
            _removeFromEnumeration(feeRecipient, enumeratedStorage);
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
        if (signedMintValidationParams.minFeeBps > 10_000) {
            revert InvalidFeeBps(signedMintValidationParams.minFeeBps);
        }
        if (signedMintValidationParams.maxFeeBps > 10_000) {
            revert InvalidFeeBps(signedMintValidationParams.maxFeeBps);
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
                add(
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
            _removeFromEnumeration(signer, enumeratedSignersStorage);
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
            _removeFromEnumeration(payer, enumeratedStorage);
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
     * @notice Internal utility function to remove an address from a supplied
     *         enumeration.
     *
     * @param toRemove    The address to remove.
     * @param enumeration The enumerated addresses to parse.
     */
    function _removeFromEnumeration(
        address toRemove,
        address[] storage enumeration
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
     * @dev Internal utility function to convert bytes to bytes32[].
     */
    function _bytesToBytes32Array(
        bytes memory data
    ) internal pure returns (bytes32[] memory) {
        // Find 32 bytes segments nb.
        uint256 dataNb = data.length / 32;
        // Create an array of dataNb elements.
        bytes32[] memory dataList = new bytes32[](dataNb);
        // Start array index at 0.
        uint256 index = 0;
        // Loop all 32 bytes segments.
        for (uint256 i = 32; i <= data.length; i = i + 32) {
            bytes32 temp;
            // Get 32 bytes from data.
            assembly {
                temp := mload(add(data, i))
            }
            // Add extracted 32 bytes to list.
            dataList[index] = temp;
            unchecked {
                ++index;
            }
        }
        // Return data list
        return (dataList);
    }

    /**
     * @dev Internal pure function to revert with a provided reason.
     *      If no reason is provided, reverts with no message.
     */
    function _revertWithReason(bytes memory data) internal pure {
        // Revert if no revert reason.
        if (data.length == 0) revert();

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
