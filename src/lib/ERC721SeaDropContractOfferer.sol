// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721ContractMetadata,
    ISeaDropTokenContractMetadata
} from "./ERC721ContractMetadata.sol";

import {
    INonFungibleSeaDropToken
} from "../interfaces/INonFungibleSeaDropToken.sol";

import {
    ERC721SeaDropStructsErrorsAndEvents
} from "./ERC721SeaDropStructsErrorsAndEvents.sol";

import { IDelegationRegistry } from "../interfaces/IDelegationRegistry.sol";

import { ItemType } from "seaport/lib/ConsiderationEnums.sol";

import {
    ReceivedItem,
    Schema,
    SpentItem
} from "seaport/lib/ConsiderationStructs.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {
    IERC165
} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title  ERC721SeaDropContractOfferer
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice An ERC721 token contract based on ERC721A that can mint as a
 *         Seaport contract offerer.
 */
contract ERC721SeaDropContractOfferer is
    ERC721ContractMetadata,
    ERC721SeaDropStructsErrorsAndEvents,
    INonFungibleSeaDropToken
{
    using ECDSA for bytes32;

    /// @notice The allowed Seaport addresses that can mint.
    mapping(address => bool) internal _allowedSeaport;

    /// @notice The enumerated allowed Seaport addresses.
    address[] internal _enumeratedAllowedSeaport;

    /// @notice The allowed conduit address that can mint.
    address private immutable _CONDUIT;

    /// @notice The delegation registry.
    IDelegationRegistry public constant delegationRegistry =
        IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);

    /// @notice The public drop data.
    PublicDrop private _publicDrop;

    /// @notice The creator payout addresses and basis points.
    CreatorPayout[] private _creatorPayouts;

    /// @notice The allow list merkle root.
    bytes32 private _allowListMerkleRoot;

    /// @notice The allowed fee recipients.
    mapping(address => bool) private _allowedFeeRecipients;

    /// @notice The enumerated allowed fee recipients.
    address[] private _enumeratedFeeRecipients;

    /// @notice The parameters for allowed signers for server-side drops.
    mapping(address => SignedMintValidationParams)
        private _signedMintValidationParams;

    /// @notice The signers for each server-side drop.
    address[] private _enumeratedSigners;

    /// @notice The used signature digests.
    mapping(bytes32 => bool) private _usedDigests;

    /// @notice The allowed payers.
    mapping(address => bool) private _allowedPayers;

    /// @notice The enumerated allowed payers.
    address[] private _enumeratedPayers;

    /// @notice The token gated drop stages.
    mapping(address => TokenGatedDropStage) private _tokenGatedDrops;

    /// @notice The tokens for token gated drops.
    address[] private _enumeratedTokenGatedTokens;

    /// @notice The token IDs and redeemed counts for token gated drop stages.
    mapping(address => mapping(uint256 => uint256)) private _tokenGatedRedeemed;

    /// @notice The mint recipient set during the execution of a mint order.
    address private _mintRecipient;

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
                "address paymentToken,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 startTime,"
                "uint256 endTime,"
                "uint256 dropStageIndex,"
                "uint256 maxTokenSupplyForStage,"
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
                "address paymentToken,"
                "uint256 maxTotalMintableByWallet,"
                "uint256 startTime,"
                "uint256 endTime,"
                "uint256 dropStageIndex,"
                "uint256 maxTokenSupplyForStage,"
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
    bytes32 internal constant _NAME_HASH = keccak256("ERC721SeaDrop");
    bytes32 internal constant _VERSION_HASH = keccak256("2.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR;

    /**
     * @notice Constant for an unlimited `maxTokenSupplyForStage`.
     *        Used in `mintPublic` where no `maxTokenSupplyForStage`
     *        is stored in the `PublicDrop` struct.
     */
    uint256 internal constant _UNLIMITED_MAX_TOKEN_SUPPLY_FOR_STAGE =
        type(uint256).max;

    /**
     * @notice Constant for a public mint's `dropStageIndex`.
     *         Used in `mintPublic` where no `dropStageIndex`
     *         is stored in the `PublicDrop` struct.
     */
    uint256 internal constant _PUBLIC_DROP_STAGE_INDEX = 0;

    /**
     * @notice Deploy the token contract.
     *
     * @param name           The name of the token.
     * @param symbol         The symbol of the token.
     * @param allowedSeaport The address of the Seaport contract allowed to
     *                       interact.
     * @param allowedConduit The address of the conduit contract allowed to
     *                       interact.
     */
    constructor(
        string memory name,
        string memory symbol,
        address allowedSeaport,
        address allowedConduit
    ) ERC721ContractMetadata(name, symbol) {
        // Set the allowed Seaport to interact with this contract.
        _allowedSeaport[allowedSeaport] = true;

        // Set the allowed Seaport enumeration.
        address[] memory enumeratedAllowedSeaport = new address[](1);
        enumeratedAllowedSeaport[0] = allowedSeaport;
        _enumeratedAllowedSeaport = enumeratedAllowedSeaport;

        // Set the allowed conduit to interact with this contract.
        _CONDUIT = allowedConduit;

        // Set the domain separator.
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();

        // Emit an event noting the contract deployment.
        emit SeaDropTokenDeployed(SEADROP_TOKEN_TYPE.ERC721_STANDARD);
    }

    /**
     * @notice Update the allowed Seaport contracts.
     *
     *         Warning: this lets the provided addresses mint tokens on this
     *         contract, be sure to only set official Seaport releases.
     *
     *         Only the owner can use this function.
     *
     * @param allowedSeaport The allowed SeaDrop addresses.
     */
    function updateAllowedSeaport(
        address[] calldata allowedSeaport
    ) external virtual override onlyOwner {
        _updateAllowedSeaport(allowedSeaport);
    }

    /**
     * @notice Internal function to update the allowed Seaport contracts.
     *
     * @param allowedSeaport The allowed Seaport addresses.
     */
    function _updateAllowedSeaport(address[] calldata allowedSeaport) internal {
        // Put the length on the stack for more efficient access.
        uint256 enumeratedAllowedSeaportLength = _enumeratedAllowedSeaport
            .length;
        uint256 allowedSeaportLength = allowedSeaport.length;

        // Reset the old mapping.
        for (uint256 i = 0; i < enumeratedAllowedSeaportLength; ) {
            _allowedSeaport[_enumeratedAllowedSeaport[i]] = false;
            unchecked {
                ++i;
            }
        }

        // Set the new mapping for allowed SeaDrop contracts.
        for (uint256 i = 0; i < allowedSeaportLength; ) {
            _allowedSeaport[allowedSeaport[i]] = true;
            unchecked {
                ++i;
            }
        }

        // Set the enumeration.
        _enumeratedAllowedSeaport = allowedSeaport;

        // Emit an event for the update.
        emit AllowedSeaportUpdated(allowedSeaport);
    }

    /**
     * @dev Generates a mint order with the required consideration items.
     *
     * @param fulfiller              The address of the fulfiller.
     * @param minimumReceived        The minimum items that the caller must
     *                               receive. To specify a range of ERC-721
     *                               tokens, use a null address ERC-1155 with
     *                               the amount as the quantity.
     * @param maximumSpent           Maximum items the caller is willing to
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
        SpentItem[] memory maximumSpent,
        bytes calldata context // encoded based on the schemaID
    )
        external
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Derive the offer and consideration.
        (offer, consideration) = _createOrder(
            fulfiller,
            minimumReceived,
            maximumSpent,
            context,
            true
        );
    }

    /**
     * @dev Ratifies a mint order. Nothing additional needs to happen here.
     *
     * @custom:param offer         The offer items.
     * @custom:param consideration The consideration items.
     * @custom:param context       Additional context of the order.
     * @custom:param orderHashes   The hashes to ratify.
     * @custom:param contractNonce The nonce of the contract.
     *
     * @return The magic value required by Seaport.
     */
    function ratifyOrder(
        SpentItem[] calldata /* offer */,
        ReceivedItem[] calldata /* consideration */,
        bytes calldata /* context */, // encoded based on the schemaID
        bytes32[] calldata /* orderHashes */,
        uint256 /* contractNonce */
    ) external pure override returns (bytes4) {
        // Utilize assembly to efficiently return the ratifyOrder magic value.
        assembly {
            mstore(0, 0xf4dd92ce)
            return(0x1c, 0x04)
        }
    }

    /**
     * @dev View function to preview a mint order.
     *
     * @custom:param caller       The address of the caller (e.g. Seaport).
     * @param fulfiller           The address of the fulfiller.
     * @param minimumReceived     The minimum items that the caller must
     *                            receive. If empty, the fulfiller receives the
     *                            ability to transfer the NFT in question for a
     *                            secondary fee; if a single item is provided
     *                            and that item is an unminted NFT, the
     *                            fulfiller receives the ability to transfer
     *                            the NFT in question for a primary fee.
     * @param maximumSpent        Maximum items the caller is willing to spend.
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
        SpentItem[] memory maximumSpent,
        bytes calldata context
    )
        external
        view
        override
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // To avoid the solidity compiler complaining about calling a non-view
        // function here (_createOrder), we will cast it as a view and use it.
        // This is okay because we are not modifying any state when passing
        // withEffects=false.
        function(
            address,
            SpentItem[] calldata,
            SpentItem[] memory,
            bytes calldata,
            bool
        ) internal view returns (SpentItem[] memory, ReceivedItem[] memory) fn;
        function(
            address,
            SpentItem[] calldata,
            SpentItem[] memory,
            bytes calldata,
            bool
        )
            internal
            returns (
                SpentItem[] memory,
                ReceivedItem[] memory
            ) fn2 = _createOrder;
        assembly {
            fn := fn2
        }

        // Derive the offer and consideration.
        (offer, consideration) = fn(
            fulfiller,
            minimumReceived,
            maximumSpent,
            context,
            false
        );
    }

    /**
     * @dev Gets the metadata for this contract offerer.
     *
     * @return name    The name of the contract offerer.
     * @return schemas The schemas supported by the contract offerer.
     */
    function getSeaportMetadata()
        external
        pure
        override
        returns (
            string memory name,
            Schema[] memory schemas // map to Seaport Improvement Proposal IDs
        )
    {
        schemas = new Schema[](1);

        schemas[0].id = 12;

        // Encode the SIP-12 information.
        uint256[] memory substandards = new uint256[](4);
        substandards[0] = 0;
        substandards[1] = 1;
        substandards[2] = 2;
        substandards[3] = 3;
        schemas[0].metadata = abi.encode(substandards);

        return ("ERC721SeaDrop", schemas);
    }

    /**
     * @dev Decodes an order and returns the offer and substandard version.
     */
    function _decodeOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] memory maximumSpent,
        bytes calldata context
    ) internal view returns (SpentItem[] memory offer, uint8 substandard) {
        // Declare an error buffer; first check that the minimumReceived has the
        // this address and a non-zero "amount" as the quantity for the mint.
        uint256 errorBuffer = (
            _castAndInvert(
                minimumReceived.length == 1 &&
                    minimumReceived[0].itemType == ItemType.ERC1155 &&
                    minimumReceived[0].token == address(this) &&
                    minimumReceived[0].amount != 0
            )
        );

        // The offer is the minimumReceived.
        offer = minimumReceived;

        // Get the length of the context array from calldata (masked).
        uint256 contextLength;
        assembly {
            contextLength := and(calldataload(context.offset), 0xfffffff)
        }

        // Set the substandard version.
        substandard = uint8(context[1]);

        // Next, check for SIP-6 version byte.
        errorBuffer |= _castAndInvert(context[0] == bytes1(0x00)) << 1;

        // Next, check for supported substandard.
        errorBuffer |= _castAndInvert(substandard < 4) << 2;

        // Next, check for correct context length. Minimum is 42 bytes
        // (version byte, substandard byte, feeRecipient, minter)
        unchecked {
            errorBuffer |= _castAndInvert(context.length > 41) << 3;
        }

        // Handle decoding errors.
        if (errorBuffer != 0) {
            uint8 version = uint8(context[0]);

            if (errorBuffer << 255 != 0) {
                revert MustSpecifyERC1155ConsiderationItemForSeaDropConsecutiveMint();
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
     * @param maximumSpent        The maximum items that the caller is
     *                            willing to spend.
     * @param context             Context of the order according to SIP-12,
     *                            containing the mint parameters.
     * @param withEffects         Whether to apply the effects of the order.
     *
     * @return offer An array containing the offer items.
     * @return consideration An array containing the consideration items.
     */
    function _createOrder(
        address fulfiller,
        SpentItem[] calldata minimumReceived,
        SpentItem[] memory maximumSpent,
        bytes calldata context,
        bool withEffects
    )
        internal
        returns (SpentItem[] memory offer, ReceivedItem[] memory consideration)
    {
        // Define a variable for the substandard version.
        uint8 substandard;

        (offer, substandard) = _decodeOrder(
            fulfiller,
            minimumReceived,
            maximumSpent,
            context
        );

        // Quantity is the amount of the ERC-1155 min received item.
        uint256 quantity = minimumReceived[0].amount;

        // All substandards have feeRecipient and minter as first two params.
        address feeRecipient = address(bytes20(context[2:22]));
        address minter = address(bytes20(context[22:42]));

        // If the minter is the zero address, set it to the fulfiller.
        if (minter == address(0)) {
            minter = fulfiller;
        }

        // Put the fulfiller back on the stack to avoid stack too deep.
        address fulfiller_ = fulfiller;

        // Define a variable for the current price.
        uint256 currentPrice;

        if (substandard == 0) {
            // 0: Public mint
            // Checks
            (consideration, currentPrice) = _validateMintPublic(
                feeRecipient,
                fulfiller_,
                minter,
                quantity
            );
            // Effects
            if (withEffects) {
                _mintPublic(
                    feeRecipient,
                    fulfiller_,
                    minter,
                    quantity,
                    currentPrice
                );
            }
        } else if (substandard == 1) {
            // 1: Allow list mint
            MintParams memory mintParams = abi.decode(
                context[42:362],
                (MintParams)
            );
            bytes32[] memory proof = _bytesToBytes32Array(context[362:]);
            // Checks
            (consideration, currentPrice) = _validateMintAllowList(
                feeRecipient,
                fulfiller_,
                minter,
                quantity,
                mintParams,
                proof
            );
            // Effects
            if (withEffects) {
                _mintAllowList(
                    feeRecipient,
                    fulfiller_,
                    minter,
                    quantity,
                    currentPrice,
                    mintParams,
                    proof
                );
            }
        } else if (substandard == 2) {
            // 2: Token gated mint
            TokenGatedMintParams memory mintParams = abi.decode(
                context[42:],
                (TokenGatedMintParams)
            );
            // Checks
            (consideration, currentPrice) = _validateMintAllowedTokenHolder(
                feeRecipient,
                fulfiller_,
                minter,
                mintParams
            );
            // Effects
            if (withEffects) {
                _mintAllowedTokenHolder(
                    feeRecipient,
                    fulfiller_,
                    minter,
                    currentPrice,
                    mintParams
                );
            }
        } else {
            // substandard == 3
            // 3: Signed mint
            MintParams memory mintParams = abi.decode(
                context[42:362],
                (MintParams)
            );
            uint256 salt = uint256(bytes32(context[362:394]));
            bytes memory signature = context[394:];
            bytes32 digest;
            // Checks
            (consideration, currentPrice, digest) = _validateMintSigned(
                feeRecipient,
                fulfiller_,
                minter,
                quantity,
                mintParams,
                salt,
                signature
            );
            // Effects
            if (withEffects) {
                _mintSigned(
                    feeRecipient,
                    fulfiller_,
                    minter,
                    quantity,
                    currentPrice,
                    mintParams,
                    salt,
                    signature,
                    digest
                );
            }
        }

        // Modify maximumSpent to reflect the consideration items, in case
        // it is a descending price stage the recipient will be refunded
        // if the fulfiller overpaid.
        if (consideration.length != 0) {
            for (uint256 i = 0; i < maximumSpent.length; ) {
                maximumSpent[i].amount = consideration[i].amount;
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Validate a public drop mint.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param quantity     The number of tokens to mint.
     */
    function _validateMintPublic(
        address feeRecipient,
        address payer,
        address minter,
        uint256 quantity
    )
        internal
        view
        returns (ReceivedItem[] memory consideration, uint256 currentPrice)
    {
        // Put the public drop data on the stack.
        PublicDrop memory publicDrop = _publicDrop;

        // Ensure that the drop has started.
        _checkActive(publicDrop.startTime, publicDrop.endTime);

        // Ensure the payer is allowed if not the minter.
        if (payer != minter) {
            if (
                !_allowedPayers[payer] &&
                !delegationRegistry.checkDelegateForAll(payer, minter)
            ) {
                revert PayerNotAllowed(payer);
            }
        }

        // Check the number of mints are available.
        _checkMintQuantity(
            minter,
            quantity,
            publicDrop.maxTotalMintableByWallet,
            _UNLIMITED_MAX_TOKEN_SUPPLY_FOR_STAGE
        );

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            feeRecipient,
            publicDrop.restrictFeeRecipients
        );

        // Derive the current price.
        currentPrice = _currentPrice(
            publicDrop.startPrice,
            publicDrop.endPrice,
            publicDrop.startTime,
            publicDrop.endTime
        );

        // Set the required consideration items.
        consideration = _requiredItems(
            quantity,
            currentPrice,
            publicDrop.paymentToken,
            feeRecipient,
            publicDrop.feeBps
        );
    }

    /**
     * @notice Effects for minting a public drop.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param quantity     The number of tokens to mint.
     * @param currentPrice The current price for each token.
     */
    function _mintPublic(
        address feeRecipient,
        address payer,
        address minter,
        uint256 quantity,
        uint256 currentPrice
    ) internal {
        // Set the mint recipient.
        _mintRecipient = minter;

        // Put the public drop data on the stack.
        PublicDrop memory publicDrop = _publicDrop;

        // Emit an event for the mint, for analytics.
        _emitSeaDropMint(
            minter,
            feeRecipient,
            payer,
            quantity,
            currentPrice,
            publicDrop.paymentToken,
            publicDrop.feeBps,
            _PUBLIC_DROP_STAGE_INDEX
        );
    }

    /**
     * @notice Validate mint from an allow list.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param quantity     The number of tokens to mint.
     * @param mintParams   The mint parameters.
     * @param proof        The proof for the leaf of the allow list.
     */
    function _validateMintAllowList(
        address feeRecipient,
        address payer,
        address minter,
        uint256 quantity,
        MintParams memory mintParams,
        bytes32[] memory proof
    )
        internal
        view
        returns (ReceivedItem[] memory consideration, uint256 currentPrice)
    {
        // Check that the drop stage is active.
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Ensure the payer is allowed if not the minter.
        if (payer != minter) {
            if (
                !_allowedPayers[payer] &&
                !delegationRegistry.checkDelegateForAll(payer, minter)
            ) {
                revert PayerNotAllowed(payer);
            }
        }

        // Check that the minter is allowed to mint the desired quantity.
        _checkMintQuantity(
            minter,
            quantity,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTokenSupplyForStage
        );

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            feeRecipient,
            mintParams.restrictFeeRecipients
        );

        // Verify the proof.
        if (
            !MerkleProof.verify(
                proof,
                _allowListMerkleRoot,
                keccak256(abi.encode(minter, mintParams))
            )
        ) {
            revert InvalidProof();
        }

        // Derive the current price.
        currentPrice = _currentPrice(
            mintParams.startPrice,
            mintParams.endPrice,
            mintParams.startTime,
            mintParams.endTime
        );

        // Set the required consideration items.
        consideration = _requiredItems(
            quantity,
            currentPrice,
            mintParams.paymentToken,
            feeRecipient,
            mintParams.feeBps
        );
    }

    /**
     * @notice Effects for minting from an allow list.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param quantity     The number of tokens to mint.
     * @param mintParams   The mint parameters.
     * @param currentPrice The current price for each token.
     * @param proof        The proof for the leaf of the allow list.
     */
    function _mintAllowList(
        address feeRecipient,
        address payer,
        address minter,
        uint256 quantity,
        uint256 currentPrice,
        MintParams memory mintParams,
        bytes32[] memory proof
    ) internal {
        // Set the mint recipient.
        _mintRecipient = minter;

        // Emit an event for the mint, for analytics.
        _emitSeaDropMint(
            minter,
            feeRecipient,
            payer,
            quantity,
            currentPrice,
            mintParams.paymentToken,
            mintParams.feeBps,
            mintParams.dropStageIndex
        );
    }

    /**
     * @notice Validate minting with a server-side signature.
     *         Note that a signature can only be used once.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param quantity     The number of tokens to mint.
     * @param mintParams   The mint parameters.
     * @param salt         The salt for the signed mint.
     * @param signature    The server-side signature, must be an allowed
     *                     signer.
     */
    function _validateMintSigned(
        address feeRecipient,
        address payer,
        address minter,
        uint256 quantity,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature
    )
        internal
        view
        returns (
            ReceivedItem[] memory consideration,
            uint256 currentPrice,
            bytes32 digest
        )
    {
        // Check that the drop stage is active.
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Ensure the payer is allowed if not the minter.
        if (minter != payer) {
            if (
                !_allowedPayers[payer] &&
                !delegationRegistry.checkDelegateForAll(payer, minter)
            ) {
                revert PayerNotAllowed(payer);
            }
        }

        // Check that the minter is allowed to mint the desired quantity.
        _checkMintQuantity(
            minter,
            quantity,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTokenSupplyForStage
        );

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            feeRecipient,
            mintParams.restrictFeeRecipients
        );

        // Derive the current price.
        currentPrice = _currentPrice(
            mintParams.startPrice,
            mintParams.endPrice,
            mintParams.startTime,
            mintParams.endTime
        );

        // Validate the signature in a block scope to avoid "stack too deep".
        {
            // Get the digest to verify the EIP-712 signature.
            digest = _getDigest(minter, feeRecipient, mintParams, salt);

            // Ensure the digest has not already been used.
            if (_usedDigests[digest]) {
                revert SignatureAlreadyUsed();
            }

            // Use the recover method to see what address was used to create
            // the signature on this data.
            // Note that if the digest doesn't exactly match what was signed we'll
            // get a random recovered address.
            address recoveredAddress = digest.recover(signature);
            _validateSignerAndParams(
                mintParams,
                recoveredAddress,
                currentPrice
            );
        }

        // Set the required consideration items.
        consideration = _requiredItems(
            quantity,
            currentPrice,
            mintParams.paymentToken,
            feeRecipient,
            mintParams.feeBps
        );
    }

    /**
     * @notice Effects for minting with a server-side signature.
     *         Note that a signature can only be used once.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param quantity     The number of tokens to mint.
     * @param currentPrice The current price of each token.
     * @param mintParams   The mint parameters.
     * @param salt         The salt for the signed mint.
     * @param signature    The server-side signature, must be an allowed
     *                     signer.
     */
    function _mintSigned(
        address feeRecipient,
        address payer,
        address minter,
        uint256 quantity,
        uint256 currentPrice,
        MintParams memory mintParams,
        uint256 salt,
        bytes memory signature,
        bytes32 digest
    ) internal {
        // Set the mint recipient.
        _mintRecipient = minter;

        // Mark the digest as used.
        _usedDigests[digest] = true;

        // Emit an event for the mint, for analytics.
        _emitSeaDropMint(
            minter,
            feeRecipient,
            payer,
            quantity,
            currentPrice,
            mintParams.paymentToken,
            mintParams.feeBps,
            mintParams.dropStageIndex
        );
    }

    /**
     * @notice Enforce stored parameters for signed mints to mitigate
     *         the effects of a malicious signer.
     *
     * @param mintParams   The mint parameters.
     * @param signer       The signer.
     * @param currentPrice The current price.
     */
    function _validateSignerAndParams(
        MintParams memory mintParams,
        address signer,
        uint256 currentPrice
    ) internal view {
        SignedMintValidationParams
            memory signedMintValidationParams = _signedMintValidationParams[
                signer
            ];

        // Check that SignedMintValidationParams have been initialized; if not,
        // this is an invalid signer.
        if (signedMintValidationParams.maxMaxTotalMintableByWallet == 0) {
            revert InvalidSignature(signer);
        }

        // Validate individual params.
        uint256 minMintPrice;
        uint256 validationMintPriceLength = signedMintValidationParams
            .minMintPrices
            .length;
        for (uint256 i = 0; i < validationMintPriceLength; ) {
            if (
                mintParams.paymentToken ==
                signedMintValidationParams.minMintPrices[i].paymentToken
            ) {
                minMintPrice = signedMintValidationParams
                    .minMintPrices[i]
                    .minMintPrice;
                break;
            }
            // Revert if we've iterated through the whole array without finding
            // a match.
            if (i == validationMintPriceLength - 1) {
                revert SignedMintValidationParamsMinMintPriceNotSetForToken(
                    mintParams.paymentToken
                );
            }
            unchecked {
                ++i;
            }
        }
        if (currentPrice < minMintPrice) {
            revert InvalidSignedMintPrice(
                mintParams.paymentToken,
                currentPrice,
                minMintPrice
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
     * @notice Validate mint as an allowed token holder.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param mintParams   The token gated mint params.
     */
    function _validateMintAllowedTokenHolder(
        address feeRecipient,
        address payer,
        address minter,
        TokenGatedMintParams memory mintParams
    )
        internal
        view
        returns (ReceivedItem[] memory consideration, uint256 currentPrice)
    {
        // Ensure the payer is allowed if not the minter.
        if (payer != minter) {
            if (
                !_allowedPayers[payer] &&
                !delegationRegistry.checkDelegateForAll(payer, minter)
            ) {
                revert PayerNotAllowed(payer);
            }
        }

        // Put the allowedNftToken on the stack for more efficient access.
        address allowedNftToken = mintParams.allowedNftToken;

        // Put the drop stage on the stack.
        TokenGatedDropStage memory dropStage = _tokenGatedDrops[
            allowedNftToken
        ];

        // Validate that the dropStage is active.
        _checkActive(dropStage.startTime, dropStage.endTime);

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            feeRecipient,
            dropStage.restrictFeeRecipients
        );

        // Put the length on the stack for more efficient access.
        uint256 allowedNftTokenIdsLength = mintParams.allowedNftTokenIds.length;

        // Revert if the token IDs and amounts are not the same length.
        if (allowedNftTokenIdsLength != mintParams.amounts.length) {
            revert TokenGatedTokenIdsAndAmountsLengthMismatch();
        }

        // Track the total number of mints requested.
        uint256 totalMintQuantity;

        // Iterate through each allowedNftTokenId
        // to ensure it is not already fully redeemed.
        for (uint256 i = 0; i < allowedNftTokenIdsLength; ) {
            // Put the tokenId on the stack.
            uint256 tokenId = mintParams.allowedNftTokenIds[i];

            // Put the amount on the stack.
            uint256 amount = mintParams.amounts[i];

            // Check that the minter is the owner of the allowedNftTokenId.
            if (IERC721(allowedNftToken).ownerOf(tokenId) != minter) {
                revert TokenGatedNotTokenOwner(allowedNftToken, tokenId);
            }

            // Cache the storage pointer for cheaper access.
            mapping(uint256 => uint256)
                storage redeemedTokenIds = _tokenGatedRedeemed[allowedNftToken];

            // Check that the token id has not already been redeemed to its limit.
            if (
                redeemedTokenIds[tokenId] + amount >
                dropStage.maxMintablePerRedeemedToken
            ) {
                revert TokenGatedTokenIdMintExceedsQuantityRemaining(
                    allowedNftToken,
                    tokenId,
                    dropStage.maxMintablePerRedeemedToken,
                    redeemedTokenIds[tokenId],
                    amount
                );
            }

            // Add to the total mint quantity.
            totalMintQuantity += amount;

            unchecked {
                ++i;
            }
        }

        // Check that the minter is allowed to mint the desired quantity.
        _checkMintQuantity(
            minter,
            totalMintQuantity,
            dropStage.maxTotalMintableByWallet,
            dropStage.maxTokenSupplyForStage
        );

        // Derive the current price.
        currentPrice = _currentPrice(
            dropStage.startPrice,
            dropStage.endPrice,
            dropStage.startTime,
            dropStage.endTime
        );

        // Set the required consideration items.
        consideration = _requiredItems(
            totalMintQuantity,
            currentPrice,
            dropStage.paymentToken,
            feeRecipient,
            dropStage.feeBps
        );
    }

    /**
     * @notice Effects for minting as an allowed token holder.
     *
     * @param feeRecipient The fee recipient.
     * @param payer        The payer of the mint.
     * @param minter       The mint recipient.
     * @param currentPrice The current price of each token.
     * @param mintParams   The token gated mint params.
     */
    function _mintAllowedTokenHolder(
        address feeRecipient,
        address payer,
        address minter,
        uint256 currentPrice,
        TokenGatedMintParams memory mintParams
    ) internal returns (ReceivedItem[] memory consideration) {
        // Set the mint recipient.
        _mintRecipient = minter;

        // Put the allowedNftToken on the stack for more efficient access.
        address allowedNftToken = mintParams.allowedNftToken;

        // Put the drop stage on the stack.
        TokenGatedDropStage memory dropStage = _tokenGatedDrops[
            allowedNftToken
        ];

        // Put the length on the stack for more efficient access.
        uint256 allowedNftTokenIdsLength = mintParams.allowedNftTokenIds.length;

        // Track the total number of mints requested.
        uint256 totalMintQuantity;

        // Iterate through each allowedNftTokenId and increase minted count
        for (uint256 i = 0; i < allowedNftTokenIdsLength; ) {
            // Put the tokenId on the stack.
            uint256 tokenId = mintParams.allowedNftTokenIds[i];

            // Put the amount on the stack.
            uint256 amount = mintParams.amounts[i];

            // Cache the storage pointer for cheaper access.
            mapping(uint256 => uint256)
                storage redeemedTokenIds = _tokenGatedRedeemed[allowedNftToken];

            // Increase mint count on redeemed token id.
            redeemedTokenIds[tokenId] += amount;

            // Add to the total mint quantity.
            totalMintQuantity += amount;

            unchecked {
                ++i;
            }
        }

        // Emit an event for the mint, for analytics.
        _emitSeaDropMint(
            minter,
            feeRecipient,
            payer,
            totalMintQuantity,
            currentPrice,
            dropStage.paymentToken,
            dropStage.feeBps,
            dropStage.dropStageIndex
        );
    }

    /**
     * @notice Check that the drop stage is active.
     *
     * @param startTime The drop stage start time.
     * @param endTime   The drop stage end time.
     */
    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        if (
            _cast(block.timestamp < startTime) |
                _cast(block.timestamp > endTime) ==
            1
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
            if (!_allowedFeeRecipients[feeRecipient]) {
                revert FeeRecipientNotAllowed(feeRecipient);
            }
    }

    /**
     * @notice Check that the wallet is allowed to mint the desired quantity.
     *
     * @param minter                   The mint recipient.
     * @param quantity                 The number of tokens to mint.
     * @param maxTotalMintableByWallet The max allowed mints per wallet.
     * @param maxTokenSupplyForStage   The max token supply for the drop stage.
     */
    function _checkMintQuantity(
        address minter,
        uint256 quantity,
        uint256 maxTotalMintableByWallet,
        uint256 maxTokenSupplyForStage
    ) internal view {
        // Get the mint stats.
        (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply
        ) = this.getMintStats(minter);

        // Ensure mint quantity doesn't exceed maxTotalMintableByWallet.
        if (quantity + minterNumMinted > maxTotalMintableByWallet) {
            revert MintQuantityExceedsMaxMintedPerWallet(
                quantity + minterNumMinted,
                maxTotalMintableByWallet
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
     * @param quantity     The number of tokens to mint.
     * @param currentPrice The current price of each token.
     * @param paymentToken The payment token.
     * @param feeRecipient The fee recipient.
     * @param feeBps       The fee basis points.
     */
    function _requiredItems(
        uint256 quantity,
        uint256 currentPrice,
        address paymentToken,
        address feeRecipient,
        uint256 feeBps
    ) internal view returns (ReceivedItem[] memory receivedItems) {
        // If the mint price is zero, return early as there
        // are no required consideration items.
        if (currentPrice == 0) return new ReceivedItem[](0);

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
        CreatorPayout[] storage creatorPayouts = _creatorPayouts;

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
     * @notice Emits an event for the mint, for analytics.
     *
     * @param minter         The mint recipient.
     * @param payer          The address that payed for the mint.
     * @param quantity       The number of tokens to mint.
     * @param mintPrice      The mint price per token.
     * @param paymentToken   The payment token. Null for native token.
     * @param dropStageIndex The drop stage index.
     * @param feeBps         The fee basis points.
     * @param feeRecipient   The fee recipient.
     */
    function _emitSeaDropMint(
        address minter,
        address feeRecipient,
        address payer,
        uint256 quantity,
        uint256 mintPrice,
        address paymentToken,
        uint256 feeBps,
        uint256 dropStageIndex
    ) internal {
        // Emit an event for the mint.
        emit SeaDropMint(
            minter,
            feeRecipient,
            payer,
            quantity,
            mintPrice,
            paymentToken,
            feeBps,
            dropStageIndex
        );
    }

    /**
     * @dev Internal view function to get the EIP-712 domain separator. If the
     *      chainId matches the chainId set on deployment, the cached domain
     *      separator will be returned; otherwise, it will be derived from
     *      scratch.
     *
     * @return The domain separator.
     */
    function _domainSeparator() internal view returns (bytes32) {
        // prettier-ignore
        return block.chainid == _CHAIN_ID
            ? _DOMAIN_SEPARATOR
            : _deriveDomainSeparator();
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
     * @notice Returns the mint public drop data.
     */
    function getPublicDrop() external view returns (PublicDrop memory) {
        return _publicDrop;
    }

    /**
     * @notice Returns the creator payouts for the nft contract.
     */
    function getCreatorPayouts()
        external
        view
        returns (CreatorPayout[] memory)
    {
        return _creatorPayouts;
    }

    /**
     * @notice Returns the allow list merkle root for the nft contract.
     */
    function getAllowListMerkleRoot() external view returns (bytes32) {
        return _allowListMerkleRoot;
    }

    /**
     * @notice Returns an enumeration of allowed fee recipients
     *         when fee recipients are enforced.
     */
    function getAllowedFeeRecipients()
        external
        view
        returns (address[] memory)
    {
        return _enumeratedFeeRecipients;
    }

    /**
     * @notice Returns the server-side signers.
     */
    function getSigners() external view returns (address[] memory) {
        return _enumeratedSigners;
    }

    /**
     * @notice Returns the struct of SignedMintValidationParams for a signer.
     *
     * @param signer      The signer.
     */
    function getSignedMintValidationParams(
        address signer
    ) external view returns (SignedMintValidationParams memory) {
        return _signedMintValidationParams[signer];
    }

    /**
     * @notice Returns the allowed payers.
     */
    function getPayers() external view returns (address[] memory) {
        return _enumeratedPayers;
    }

    /**
     * @notice Returns the allowed token gated drop tokens.
     */
    function getTokenGatedAllowedTokens()
        external
        view
        returns (address[] memory)
    {
        return _enumeratedTokenGatedTokens;
    }

    /**
     * @notice Returns the token gated drop data for the token gated nft.
     */
    function getTokenGatedDrop(
        address allowedNftToken
    ) external view returns (TokenGatedDropStage memory) {
        return _tokenGatedDrops[allowedNftToken];
    }

    /**
     * @notice Returns the redeemed count for a token id for a
     *         token gated drop.
     *
     * @param allowedNftToken   The token gated nft token.
     * @param allowedNftTokenId The token gated nft token id to check.
     */
    function getAllowedNftTokenIdRedeemedCount(
        address allowedNftToken,
        uint256 allowedNftTokenId
    ) external view returns (uint256) {
        return _tokenGatedRedeemed[allowedNftToken][allowedNftTokenId];
    }

    /**
     * @notice Emits an event to notify update of the drop URI.
     *
     *         Only the owner can use this function.
     *
     * @param dropURI The new drop URI.
     */
    function updateDropURI(string calldata dropURI) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Emit an event with the update.
        emit DropURIUpdated(dropURI);
    }

    /**
     * @notice Updates the public drop data and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Revert if the fee basis points is greater than 10_000.
        if (publicDrop.feeBps > 10_000) {
            revert InvalidFeeBps(publicDrop.feeBps);
        }

        // Set the public drop data.
        _publicDrop = publicDrop;

        // Emit an event with the update.
        emit PublicDropUpdated(publicDrop);
    }

    /**
     * @notice Updates the allow list merkle root for the nft contract
     *         and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Track the previous root.
        bytes32 prevRoot = _allowListMerkleRoot;

        // Update the merkle root.
        _allowListMerkleRoot = allowListData.merkleRoot;

        // Emit an event with the update.
        emit AllowListUpdated(
            prevRoot,
            allowListData.merkleRoot,
            allowListData.publicKeyURIs,
            allowListData.allowListURI
        );
    }

    /**
     * @notice Updates the token gated drop stage for the nft contract
     *         and emits an event.
     *
     *         Only the owner can use this function.
     *
     *         Note: If two INonFungibleSeaDropToken tokens are doing
     *         simultaneous token gated drop promotions for each other,
     *         they can be minted by the same actor until
     *         `maxTokenSupplyForStage` is reached. Please ensure the
     *         `allowedNftToken` is not running an active drop during
     *         the `dropStage` time period.
     *
     * @param allowedNftToken The token gated nft token.
     * @param dropStage       The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Ensure the allowedNftToken is not the zero address.
        if (allowedNftToken == address(0)) {
            revert TokenGatedDropAllowedNftTokenCannotBeZeroAddress();
        }

        // Ensure the allowedNftToken is not the drop token itself.
        if (allowedNftToken == address(this)) {
            revert TokenGatedDropAllowedNftTokenCannotBeDropToken();
        }

        // Revert if the fee basis points are greater than 10_000.
        if (dropStage.feeBps > 10_000) {
            revert InvalidFeeBps(dropStage.feeBps);
        }

        // Use maxTotalMintableByWallet != 0 as a signal that this update should
        // add or update the drop stage, otherwise we will be removing.
        bool addOrUpdateDropStage = dropStage.maxTotalMintableByWallet != 0;

        // Get pointers to the token gated drop data and enumerated addresses.
        TokenGatedDropStage storage existingDropStageData = _tokenGatedDrops[
            allowedNftToken
        ];
        address[] storage enumeratedTokens = _enumeratedTokenGatedTokens;

        // Stage struct packs to a single slot, so load it
        // as a uint256; if it is 0, it is empty.
        bool dropStageDoesNotExist;
        assembly {
            dropStageDoesNotExist := iszero(sload(existingDropStageData.slot))
        }

        if (addOrUpdateDropStage) {
            _tokenGatedDrops[allowedNftToken] = dropStage;
            // Add to enumeration if it does not exist already.
            if (dropStageDoesNotExist) {
                enumeratedTokens.push(allowedNftToken);
            }
        } else {
            // Check we are not deleting a drop stage that does not exist.
            if (dropStageDoesNotExist) {
                revert TokenGatedDropStageNotPresent();
            }
            // Clear storage slot and remove from enumeration.
            delete _tokenGatedDrops[allowedNftToken];
            _removeFromEnumeration(allowedNftToken, enumeratedTokens);
        }

        // Emit an event with the update.
        emit TokenGatedDropStageUpdated(allowedNftToken, dropStage);
    }

    /**
     * @notice Updates the creator payouts and emits an event.
     *         The basis points must add up to 10_000 exactly.
     *
     *         Only the owner can use this function.
     *
     * @param creatorPayouts The creator payout address and basis points.
     */
    function updateCreatorPayouts(
        CreatorPayout[] calldata creatorPayouts
    ) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        // Reset the creator payout array.
        delete _creatorPayouts;

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
            _creatorPayouts.push(creatorPayout);

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
     *         Only the owner can use this function.
     *
     * @param feeRecipient The fee recipient.
     * @param allowed      If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(
        address feeRecipient,
        bool allowed
    ) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        if (feeRecipient == address(0)) {
            revert FeeRecipientCannotBeZeroAddress();
        }

        // Track the enumerated storage.
        address[] storage enumeratedStorage = _enumeratedFeeRecipients;
        mapping(address => bool)
            storage feeRecipientsMap = _allowedFeeRecipients;

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
            delete _allowedFeeRecipients[feeRecipient];
            _removeFromEnumeration(feeRecipient, enumeratedStorage);
        }

        // Emit an event with the update.
        emit AllowedFeeRecipientUpdated(feeRecipient, allowed);
    }

    /**
     * @notice Updates the allowed server-side signers and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param signer                     The signer to update.
     * @param signedMintValidationParams Minimum and maximum parameters
     *                                   to enforce for signed mints.
     */
    function updateSignedMintValidationParams(
        address signer,
        SignedMintValidationParams calldata signedMintValidationParams
    ) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

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

        // Revert if at least one payment token min mint price is not set.
        if (
            signedMintValidationParams.maxMaxTotalMintableByWallet != 0 &&
            signedMintValidationParams.minMintPrices.length == 0
        ) {
            revert SignedMintValidationParamsMinMintPriceNotSet();
        }

        // Track the enumerated storage.
        address[] storage enumeratedStorage = _enumeratedSigners;
        mapping(address => SignedMintValidationParams)
            storage signedMintValidationParamsMap = _signedMintValidationParams;
        SignedMintValidationParams
            storage existingSignedMintValidationParams = signedMintValidationParamsMap[
                signer
            ];

        bool signedMintValidationParamsDoNotExist;
        assembly {
            signedMintValidationParamsDoNotExist := iszero(
                sload(existingSignedMintValidationParams.slot)
            )
        }
        // Use maxMaxTotalMintableByWallet as sentry for add/update or delete.
        bool addOrUpdate = signedMintValidationParams
            .maxMaxTotalMintableByWallet != 0;

        if (addOrUpdate) {
            signedMintValidationParamsMap[signer] = signedMintValidationParams;
            if (signedMintValidationParamsDoNotExist) {
                enumeratedStorage.push(signer);
            }
        } else {
            if (
                existingSignedMintValidationParams
                    .maxMaxTotalMintableByWallet == 0
            ) {
                revert SignerNotPresent();
            }
            delete _signedMintValidationParams[signer];
            _removeFromEnumeration(signer, enumeratedStorage);
        }

        // Emit an event with the update.
        emit SignedMintValidationParamsUpdated(
            signer,
            signedMintValidationParams
        );
    }

    /**
     * @notice Updates the allowed payer and emits an event.
     *
     *         Only the owner can use this function.
     *
     * @param payer   The payer to add or remove.
     * @param allowed Whether to add or remove the payer.
     */
    function updatePayer(address payer, bool allowed) external {
        // Ensure the sender is only the owner or contract itself.
        _onlyOwnerOrSelf();

        if (payer == address(0)) {
            revert PayerCannotBeZeroAddress();
        }

        // Track the enumerated storage.
        address[] storage enumeratedStorage = _enumeratedPayers;
        mapping(address => bool) storage payersMap = _allowedPayers;

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
            delete _allowedPayers[payer];
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
        bytes32 mintParamsHashStruct = keccak256(
            abi.encode(
                _MINT_PARAMS_TYPEHASH,
                mintParams.startPrice,
                mintParams.endPrice,
                mintParams.paymentToken,
                mintParams.maxTotalMintableByWallet,
                mintParams.startTime,
                mintParams.endTime,
                mintParams.dropStageIndex,
                mintParams.maxTokenSupplyForStage,
                mintParams.feeBps,
                mintParams.restrictFeeRecipients
            )
        );
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _domainSeparator(),
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
     * @notice Returns a set of mint stats for the address.
     *         This assists in enforcing maxSupply, maxTotalMintableByWallet,
     *         and maxTokenSupplyForStage checks.
     *
     * @dev    NOTE: Implementing contracts should always update these numbers
     *         before transferring any tokens with _safeMint() to mitigate
     *         consequences of malicious onERC721Received() hooks.
     *
     * @param minter The minter address.
     */
    function getMintStats(
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
        minterNumMinted = _numberMinted(minter);
        currentTotalSupply = _totalMinted();
        maxSupply = _maxSupply;
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165, ERC721ContractMetadata)
        returns (bool)
    {
        return
            interfaceId == type(INonFungibleSeaDropToken).interfaceId ||
            // ERC721ContractMetadata returns supportsInterface true for
            //     ISeaDropTokenContractMetadata, EIP-2981
            // ERC721A returns supportsInterface true for
            //     ERC721, ERC721Metadata, ERC165
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Handle ERC-1155 safeTransferFrom for SeaDrop minting.
     *      When "from" is this contract, mint a quantity of tokens.
     *
     *      Only allowed Seaport or conduit can use this function.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external {
        // TODO decide if we need `nonReentrant` modifier in this function
        // Revert if caller or from is invalid.
        if (
            from != address(this) ||
            (msg.sender != _CONDUIT && !_allowedSeaport[msg.sender])
        ) {
            revert InvalidCallerOnlyAllowedSeaportOrConduit(msg.sender);
        }

        // Mint tokens with "value" representing the quantity.
        _mint(_mintRecipient, value);

        // Clear the mint recipient.
        _mintRecipient = address(0);
    }

    /**
     * @notice Configure multiple properties at a time.
     *
     *         Note: The individual configure methods should be used
     *         to unset or reset any properties to zero, as this method
     *         will ignore zero-value properties in the config struct.
     *
     * @param config The configuration struct.
     */
    function multiConfigure(
        MultiConfigureStruct calldata config
    ) external onlyOwner {
        if (config.maxSupply != 0) {
            this.setMaxSupply(config.maxSupply);
        }
        if (bytes(config.baseURI).length != 0) {
            this.setBaseURI(config.baseURI);
        }
        if (bytes(config.contractURI).length != 0) {
            this.setContractURI(config.contractURI);
        }
        if (
            _cast(config.publicDrop.startTime != 0) |
                _cast(config.publicDrop.endTime != 0) ==
            1
        ) {
            this.updatePublicDrop(config.publicDrop);
        }
        if (bytes(config.dropURI).length != 0) {
            this.updateDropURI(config.dropURI);
        }
        if (config.allowListData.merkleRoot != bytes32(0)) {
            this.updateAllowList(config.allowListData);
        }
        if (config.creatorPayouts.length != 0) {
            this.updateCreatorPayouts(config.creatorPayouts);
        }
        if (config.provenanceHash != bytes32(0)) {
            this.setProvenanceHash(config.provenanceHash);
        }
        if (config.allowedFeeRecipients.length != 0) {
            for (uint256 i = 0; i < config.allowedFeeRecipients.length; ) {
                this.updateAllowedFeeRecipient(
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
                this.updatePayer(config.allowedPayers[i], true);
                unchecked {
                    ++i;
                }
            }
        }
        if (config.disallowedPayers.length != 0) {
            for (uint256 i = 0; i < config.disallowedPayers.length; ) {
                this.updatePayer(config.disallowedPayers[i], false);
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
        // Find 32 bytes segments nb
        uint256 dataNb = data.length / 32;
        // Create an array of dataNb elements
        bytes32[] memory dataList = new bytes32[](dataNb);
        // Start array index at 0
        uint256 index = 0;
        // Loop all 32 bytes segments
        for (uint256 i = 32; i <= data.length; i = i + 32) {
            bytes32 temp;
            // Get 32 bytes from data
            assembly {
                temp := mload(add(data, i))
            }
            // Add extracted 32 bytes to list
            dataList[index] = temp;
            index++;
        }
        // Return data list
        return (dataList);
    }

    /**
     * @dev Internal view function to derive the current price of a stage
     *      based on the the starting price and ending price. If the start
     *      and end prices differ, the current price will be interpolated on
     *      a linear basis. Note that this function expects that the startTime
     *      is not greater than the current block timestamp and endTime is
     *      greater than the current block timestamp. If this condition is not
     *      upheld, duration / elapsed / remaining variables will underflow.
     *
     *      Since this function is only used for consideration items, it will
     *      round up.
     *
     * @param startPrice The starting price of the stage.
     * @param endPrice   The ending price of the stage.
     * @param startTime  The starting time of the stage.
     * @param endTime    The end time of the stage.
     *
     * @return price The current price.
     */
    function _currentPrice(
        uint256 startPrice,
        uint256 endPrice,
        uint256 startTime,
        uint256 endTime
    ) internal view returns (uint256 price) {
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
                // Subtract 1 from the numerator and add 1 to the result if
                // roundUp is true to get the proper rounding direction.
                // Division is performed with no zero check as duration
                // cannot be zero as long as startTime < endTime.
                add(div(sub(totalBeforeDivision, 1), duration), 1)
            )
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
}
