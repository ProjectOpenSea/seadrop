// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import {
    AllowListData,
    Conduit,
    MintParams,
    PaymentValidation,
    PublicDrop,
    TokenGatedDropStage,
    TokenGatedMintParams
} from "./lib/SeaDropStructs.sol";

import { IERC721SeaDrop } from "./interfaces/IERC721SeaDrop.sol";

import { ERC20, SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";

import {
    IERC721
} from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import {
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import {
    ECDSA
} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import { ConduitTransfer } from "seaport/conduit/lib/ConduitStructs.sol";

import { ConduitItemType } from "seaport/conduit/lib/ConduitEnums.sol";

import {
    ConduitControllerInterface
} from "seaport/interfaces/ConduitControllerInterface.sol";

import { ConduitInterface } from "seaport/interfaces/ConduitInterface.sol";

contract SeaDrop is ISeaDrop {
    using ECDSA for bytes32;

    // Track the public drops.
    mapping(address => PublicDrop) private _publicDrops;

    // Track the drop URIs.
    mapping(address => string) private _dropURIs;

    // Track the sale tokens.
    mapping(address => ERC20) private _saleTokens;

    // Track the creator payout addresses.
    mapping(address => address) private _creatorPayoutAddresses;

    // Track the allow list merkle roots.
    mapping(address => bytes32) private _allowListMerkleRoots;

    // Track the allowed fee recipients.
    mapping(address => mapping(address => bool)) private _allowedFeeRecipients;

    // Track the allowed signers for server side drops.
    mapping(address => mapping(address => bool)) private _signers;

    // Track the signers for each server side drop.
    mapping(address => address[]) private _enumeratedSigners;

    // Track token gated drop stages.
    mapping(address => mapping(address => TokenGatedDropStage))
        private _tokenGatedDrops;

    // Track the tokens for token gated drops.
    mapping(address => address[]) private _enumeratedTokenGatedTokens;

    // Track redeemed token IDs for token gated drop stages.
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private _tokenGatedRedeemed;

    // EIP-712: Typed structured data hashing and signing
    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public immutable MINT_DATA_TYPEHASH;

    /**
     * @notice Ensure only tokens implementing IERC721SeaDrop can
     *         call the update methods.
     */
    modifier onlyIERC721SeaDrop() virtual {
        if (
            !IERC165(msg.sender).supportsInterface(
                type(IERC721SeaDrop).interfaceId
            )
        ) {
            revert OnlyIERC721SeaDrop(msg.sender);
        }
        _;
    }

    /**
     * @notice Constructor for the contract deployment.
     */
    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("SeaDrop")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        MINT_DATA_TYPEHASH = keccak256(
            "MintParams(address minter, uint256 mintPrice, uint256 maxTotalMintableByWallet, uint256 startTime, uint256 endTime, uint256 dropStageIndex, uint256 feeBps, bool restrictFeeRecipients)"
        );
    }

    /**
     * @notice Mint a public drop.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param numToMint The number of tokens to mint.
     * @param conduit If paying with an ERC20 token,
     *                optionally specify a conduit to use.
     */
    function mintPublic(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        Conduit calldata conduit
    ) external payable override {
        // Get the public drop data.
        PublicDrop memory publicDrop = _publicDrops[nftContract];

        // Ensure that the drop has started.
        if (block.timestamp < publicDrop.startTime) {
            revert NotActive(
                block.timestamp,
                publicDrop.startTime,
                type(uint64).max
            );
        }

        // Validate correct payment.
        address conduitAddress;
        // Use the conduit if provided.
        if (conduit.conduitController != address(0)) {
            conduitAddress = _getConduit(conduit);
        }
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, publicDrop.mintPrice);
        _checkCorrectPayment(nftContract, payments, conduitAddress);

        // Check that the wallet is allowed to mint the desired quantity.
        _checkNumberToMint(
            nftContract,
            numToMint,
            publicDrop.maxMintsPerWallet,
            0
        );

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            nftContract,
            feeRecipient,
            publicDrop.restrictFeeRecipients
        );

        // Split the payout, mint the token, emit an event.
        _payAndMint(
            nftContract,
            numToMint,
            publicDrop.mintPrice,
            0,
            publicDrop.feeBps,
            feeRecipient,
            conduitAddress
        );
    }

    /**
     * @notice Mint from an allow list.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param numToMint The number of tokens to mint.
     * @param mintParams The mint parameters.
     * @param proof The proof for the leaf of the allow list.
     * @param conduit If paying with an ERC20 token,
     *                optionally specify a conduit to use.
     */
    function mintAllowList(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes32[] calldata proof,
        Conduit calldata conduit
    ) external payable override {
        // Check that the drop stage is active.
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Validate correct payment.
        address conduitAddress;
        // Use the conduit if provided.
        if (conduit.conduitController != address(0)) {
            conduitAddress = _getConduit(conduit);
        }
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, mintParams.mintPrice);
        _checkCorrectPayment(nftContract, payments, conduitAddress);

        // Check that the wallet is allowed to mint the desired quantity.
        _checkNumberToMint(
            nftContract,
            numToMint,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTokenSupplyForStage
        );

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            nftContract,
            feeRecipient,
            mintParams.restrictFeeRecipients
        );

        // Verify the proof.
        if (
            !MerkleProofLib.verify(
                proof,
                _allowListMerkleRoots[nftContract],
                keccak256(abi.encode(msg.sender, mintParams))
            )
        ) {
            revert InvalidProof();
        }

        // Split the payout, mint the token, emit an event.
        _payAndMint(
            nftContract,
            numToMint,
            mintParams.mintPrice,
            mintParams.dropStageIndex,
            mintParams.feeBps,
            feeRecipient,
            conduitAddress
        );
    }

    /**
     * @notice Mint with a server side signature.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param numToMint The number of tokens to mint.
     * @param mintParams The mint parameters.
     * @param signature The server side signature, must be an allowed signer.
     * @param conduit If paying with an ERC20 token,
     *                optionally specify a conduit to use.
     */
    function mintSigned(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes calldata signature,
        Conduit calldata conduit
    ) external payable override {
        // Check that the drop stage is active.
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Validate correct payment.
        address conduitAddress;
        // Use the conduit if provided.
        if (conduit.conduitController != address(0)) {
            conduitAddress = _getConduit(conduit);
        }
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, mintParams.mintPrice);
        _checkCorrectPayment(nftContract, payments, conduitAddress);

        // Check that the wallet is allowed to mint the desired quantity.
        _checkNumberToMint(
            nftContract,
            numToMint,
            mintParams.maxTotalMintableByWallet,
            mintParams.maxTokenSupplyForStage
        );

        // Check that the fee recipient is allowed if restricted.
        _checkFeeRecipientIsAllowed(
            nftContract,
            feeRecipient,
            mintParams.restrictFeeRecipients
        );

        // Verify EIP-712 signature by recreating the data structure
        // that we signed on the client side, and then using that to recover
        // the address that signed the signature for this data.
        bytes32 digest = keccak256(
            abi.encodePacked(
                bytes2(0x1901),
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(MINT_DATA_TYPEHASH, msg.sender, mintParams)
                )
            )
        );

        // Use the recover method to see what address was used to create
        // the signature on this data.
        // Note that if the digest doesn't exactly match what was signed we'll
        // get a random recovered address.
        address recoveredAddress = digest.recover(signature);
        if (!_signers[nftContract][recoveredAddress]) {
            revert InvalidSignature(recoveredAddress);
        }

        // Split the payout, mint the token, emit an event.
        _payAndMint(
            nftContract,
            numToMint,
            mintParams.mintPrice,
            mintParams.dropStageIndex,
            mintParams.feeBps,
            feeRecipient,
            conduitAddress
        );
    }

    /**
     * @notice Mint as an allowed token holder.
     *         This will mark the token id as reedemed and will revert if the
     *         same token id is attempted to be redeemed twice.
     *
     * @param nftContract The nft contract to mint.
     * @param feeRecipient The fee recipient.
     * @param tokenGatedMintParams The token gated mint params.
     * @param conduit If paying with an ERC20 token,
     *                optionally specify a conduit to use.
     */
    function mintAllowedTokenHolder(
        address nftContract,
        address feeRecipient,
        TokenGatedMintParams[] calldata tokenGatedMintParams,
        Conduit calldata conduit
    ) external payable override {
        // Track total mint cost to compare against value sent with tx.
        PaymentValidation[] memory totalPayments = new PaymentValidation[](
            tokenGatedMintParams.length
        );

        address conduitAddress;
        // Use the conduit if provided.
        if (conduit.conduitController != address(0)) {
            conduitAddress = _getConduit(conduit);
        }

        // Iterate through each allowedNftToken.
        for (uint256 i = 0; i < tokenGatedMintParams.length; ) {
            // Set the mintParams to a variable.
            TokenGatedMintParams calldata mintParams = tokenGatedMintParams[i];

            // Set the dropStage to a variable.
            TokenGatedDropStage storage dropStage = _tokenGatedDrops[
                nftContract
            ][mintParams.allowedNftToken];

            // Validate that the dropStage is active.
            _checkActive(dropStage.startTime, dropStage.endTime);

            // Put the number of items to mint on the stack.
            uint256 numToMint = mintParams.allowedNftTokenIds.length;

            // Add to totalPayments.
            totalPayments[i] = PaymentValidation(
                numToMint,
                dropStage.mintPrice
            );

            // Check that the wallet is allowed to mint the desired quantity.
            _checkNumberToMint(
                nftContract,
                numToMint,
                dropStage.maxTotalMintableByWallet,
                dropStage.maxTokenSupplyForStage
            );

            // Check that the fee recipient is allowed if restricted.
            _checkFeeRecipientIsAllowed(
                nftContract,
                feeRecipient,
                dropStage.restrictFeeRecipients
            );

            // Iterate through each allowedNftTokenId
            // to ensure it is not already reedemed.
            for (uint256 j = 0; j < numToMint; ) {
                // Put the tokenId on the stack.
                uint256 tokenId = mintParams.allowedNftTokenIds[j];

                // Check that the sender is the owner of the allowedNftTokenId.
                if (
                    IERC721(mintParams.allowedNftToken).ownerOf(tokenId) !=
                    msg.sender
                ) {
                    revert TokenGatedNotTokenOwner(
                        nftContract,
                        mintParams.allowedNftToken,
                        tokenId
                    );
                }

                // Check that the token id has not already been redeemed.
                bool redeemed = _tokenGatedRedeemed[nftContract][
                    mintParams.allowedNftToken
                ][tokenId];

                if (redeemed == true) {
                    revert TokenGatedTokenIdAlreadyRedeemed(
                        nftContract,
                        mintParams.allowedNftToken,
                        tokenId
                    );
                }

                // Mark the token id as reedemed.
                redeemed = true;

                unchecked {
                    ++j;
                }
            }

            // Split the payout, mint the token, emit an event.
            _payAndMint(
                nftContract,
                numToMint,
                dropStage.mintPrice,
                dropStage.dropStageIndex,
                dropStage.feeBps,
                feeRecipient,
                conduitAddress
            );

            unchecked {
                ++i;
            }
        }

        // Validate correct payment.
        _checkCorrectPayment(nftContract, totalPayments, conduitAddress);
    }

    /**
     * @notice Returns the conduit address from controller and key.
     *
     * @param conduit The conduit.
     */
    function _getConduit(Conduit calldata conduit)
        internal
        view
        returns (address conduitAddress)
    {
        (conduitAddress, ) = ConduitControllerInterface(
            conduit.conduitController
        ).getConduit(conduit.conduitKey);
    }

    /**
     * @notice Check that the wallet is allowed to mint the desired quantity.
     *
     * @param numberToMint The number of tokens to mint.
     * @param maxMintsPerWallet The allowed max mints per wallet.
     * @param nftContract The nft contract.
     */
    function _checkNumberToMint(
        address nftContract,
        uint256 numberToMint,
        uint256 maxMintsPerWallet,
        uint256 maxTokenSupplyForStage
    ) internal view {
        // Get the mint stats.
        (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply
        ) = IERC721SeaDrop(nftContract).getMintStats(msg.sender);

        // Ensure amount doesn't exceed maxMintsPerWallet.
        if (numberToMint + minterNumMinted > maxMintsPerWallet) {
            revert AmountExceedsMaxMintedPerWallet(
                numberToMint + minterNumMinted,
                maxMintsPerWallet
            );
        }

        // Ensure amount doesn't exceed maxSupply.
        if (numberToMint + currentTotalSupply > maxSupply) {
            revert AmountExceedsMaxSupply(
                numberToMint + currentTotalSupply,
                maxSupply
            );
        }

        // Ensure amount doesn't exceed maxTokenSupplyForStage (if provided).
        if (maxTokenSupplyForStage != 0) {
            if (numberToMint + currentTotalSupply > maxTokenSupplyForStage) {
                revert AmountExceedsMaxTokenSupplyForStage(
                    numberToMint + currentTotalSupply,
                    maxTokenSupplyForStage
                );
            }
        }
    }

    /**
     * @notice Check that the fee recipient is allowed.
     *
     * @param nftContract The nft contract.
     * @param feeRecipient The fee recipient.
     * @param restrictFeeRecipients If the fee recipients are restricted.
     */
    function _checkFeeRecipientIsAllowed(
        address nftContract,
        address feeRecipient,
        bool restrictFeeRecipients
    ) internal view {
        // Ensure the fee recipient is not the zero address.
        if (feeRecipient == address(0)) {
            revert FeeRecipientCannotBeZeroAddress();
        }

        // Revert if the fee recipient is restricted and not allowed.
        if (
            restrictFeeRecipients == true &&
            _allowedFeeRecipients[nftContract][feeRecipient] == false
        ) {
            revert FeeRecipientNotAllowed();
        }
    }

    /**
     * @notice For native sale token, check that the correct payment
     *         was sent with the tx. For ERC20 sale token, check
     *         that the sender has sufficient balance and allowance.
     *
     * @param nftContract The nft contract.
     * @param payments The payments to validate.
     * @param conduitAddress If paying with an ERC20 token,
     *                       optionally specify a conduit address to use.
     */
    function _checkCorrectPayment(
        address nftContract,
        PaymentValidation[] memory payments,
        address conduitAddress
    ) internal view {
        // Keep track of the total cost of payments.
        uint256 totalCost;

        // Iterate through the payments and add to total cost.
        for (uint256 i = 0; i < payments.length; ) {
            totalCost += payments[i].numberToMint * payments[i].mintPrice;
            unchecked {
                ++i;
            }
        }

        // Retrieve the sale token.
        ERC20 saleToken = _saleTokens[nftContract];

        // The zero address means the sale token is the native token.
        if (address(saleToken) == address(0)) {
            // Revert if the tx's value doesn't match the total cost.
            if (msg.value != totalCost) {
                revert IncorrectPayment(msg.value, totalCost);
            }
        } else {
            // Revert if msg.value > 0 when payment is in a saleToken.
            if (msg.value > 0) {
                revert MsgValueNonZeroForERC20SaleToken();
            }

            // Revert if the sender does not have sufficient token balance.
            uint256 balance = saleToken.balanceOf(msg.sender);
            if (balance < totalCost) {
                revert InsufficientSaleTokenBalance(
                    address(saleToken),
                    balance,
                    totalCost
                );
            }

            // Revert if the sender does not have sufficient token allowance.
            // Use the conduit if provided.
            address allowanceFor = conduitAddress != address(0)
                ? conduitAddress
                : address(this);
            uint256 allowance = saleToken.allowance(msg.sender, allowanceFor);
            if (allowance < totalCost) {
                revert InsufficientSaleTokenAllowance(
                    address(saleToken),
                    allowance,
                    totalCost
                );
            }
        }
    }

    /**
     * @notice Check that the drop stage is active.
     *
     * @param startTime The drop stage start time.
     * @param endTime The drop stage end time.
     */
    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        if (block.timestamp < startTime || block.timestamp > endTime) {
            // Revert if the drop stage is not active.
            revert NotActive(block.timestamp, startTime, endTime);
        }
    }

    /**
     * @notice Splits the payment, mints a number of tokens,
     *         and emits an event.
     *
     * @param nftContract The nft contract.
     * @param numToMint The number of tokens to mint.
     * @param mintPrice The mint price.
     * @param dropStageIndex The drop stage index.
     * @param feeBps The fee basis points.
     * @param feeRecipient The fee recipient.
     * @param conduitAddress If paying with an ERC20 token,
     *                       optionally specify a conduit address to use.
     */
    function _payAndMint(
        address nftContract,
        uint256 numToMint,
        uint256 mintPrice,
        uint256 dropStageIndex,
        uint256 feeBps,
        address feeRecipient,
        address conduitAddress
    ) internal {
        // Get the sale token.
        ERC20 saleToken = _saleTokens[nftContract];

        // Split the payment between the creator and fee recipient.
        _splitPayout(
            nftContract,
            feeRecipient,
            feeBps,
            address(saleToken),
            conduitAddress
        );

        // Mint the token(s).
        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);

        // Emit an event for the mint.
        emit SeaDropMint(
            nftContract,
            msg.sender,
            feeRecipient,
            numToMint,
            mintPrice,
            address(saleToken),
            feeBps,
            dropStageIndex
        );
    }

    /**
     * @notice Split the payment payout for the creator and fee recipient.
     *
     * @param nftContract The nft contract.
     * @param feeRecipient The fee recipient.
     * @param feeBps The fee basis points.
     * @param saleToken Optionally, the ERC20 sale token.
     * @param conduitAddress If paying with an ERC20 token,
     *                       optionally specify a conduit address to use.
     */
    function _splitPayout(
        address nftContract,
        address feeRecipient,
        uint256 feeBps,
        address saleToken,
        address conduitAddress
    ) internal {
        // Get the creator payout address.
        address creatorPayoutAddress = _creatorPayoutAddresses[nftContract];

        // Ensure the creator payout address is not the zero address.
        if (creatorPayoutAddress == address(0)) {
            revert CreatorPayoutAddressCannotBeZeroAddress();
        }

        // Get the fee amount.
        uint256 feeAmount = (msg.value * feeBps) / 10_000;

        // Get the creator payout amount.
        uint256 payoutAmount = msg.value - feeAmount;

        // If the saleToken is the zero address, transfer the
        // native chain currency.
        if (saleToken == address(0)) {
            // Transfer native currency to the fee recipient.
            SafeTransferLib.safeTransferETH(feeRecipient, feeAmount);

            // Transfer native currency to the creator.
            SafeTransferLib.safeTransferETH(creatorPayoutAddress, payoutAmount);
        } else {
            // Use the conduit if specified.
            if (conduitAddress != address(0)) {
                // Initialize an array for the conduit transfers.
                ConduitTransfer[]
                    memory conduitTransfers = new ConduitTransfer[](2);

                // Set ERC20 conduit transfer for the fee recipient.
                conduitTransfers[0] = ConduitTransfer(
                    ConduitItemType.ERC20,
                    saleToken,
                    msg.sender,
                    feeRecipient,
                    0,
                    feeAmount
                );

                // Set ERC20 conduit transfer for the creator.
                conduitTransfers[1] = ConduitTransfer(
                    ConduitItemType.ERC20,
                    saleToken,
                    msg.sender,
                    creatorPayoutAddress,
                    0,
                    payoutAmount
                );

                // Execute the conduit transfers.
                ConduitInterface(conduitAddress).execute(conduitTransfers);
            } else {
                // Transfer ERC20 to the fee recipient.
                SafeTransferLib.safeTransferFrom(
                    ERC20(saleToken),
                    msg.sender,
                    feeRecipient,
                    feeAmount
                );

                // Transfer ERC20 to the creator.
                SafeTransferLib.safeTransferFrom(
                    ERC20(saleToken),
                    msg.sender,
                    creatorPayoutAddress,
                    payoutAmount
                );
            }
        }
    }

    /**
     * @notice Returns the drop URI for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getDropURI(address nftContract)
        external
        view
        returns (string memory)
    {
        return _dropURIs[nftContract];
    }

    /**
     * @notice Returns the public drop data for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getPublicDrop(address nftContract)
        external
        view
        returns (PublicDrop memory)
    {
        return _publicDrops[nftContract];
    }

    /**
     * @notice Update the sale token for the nft contract
     *         and emit an event.
     *         A zero address means the sale token is denominated
     *         in the chain's native currency (e.g. ETH, MATIC, etc.)
     *
     * @param saleToken The ERC20 token address.
     */
    function updateSaleToken(address saleToken) external onlyIERC721SeaDrop {
        // Set the sale token.
        _saleTokens[msg.sender] = ERC20(saleToken);

        // Emit an event with the update.
        emit SaleTokenUpdated(msg.sender, saleToken);
    }

    /**
     * @notice Returns the sale token for the nft contract.
     *         A zero address means the sale token is denominated
     *         in the chain's native currency (e.g. ETH, MATIC, etc.)
     *
     * @param nftContract The nft contract.
     */
    function getSaleToken(address nftContract) external view returns (address) {
        return address(_saleTokens[nftContract]);
    }

    /**
     * @notice Returns the creator payout address for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getCreatorPayoutAddress(address nftContract)
        external
        view
        returns (address)
    {
        return _creatorPayoutAddresses[nftContract];
    }

    /**
     * @notice Returns the allow list merkle root for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getAllowListMerkleRoot(address nftContract)
        external
        view
        returns (bytes32)
    {
        return _allowListMerkleRoots[nftContract];
    }

    /**
     * @notice Returns if the specified fee recipient is allowed
     *         for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getFeeRecipientIsAllowed(address nftContract, address feeRecipient)
        external
        view
        returns (bool)
    {
        return _allowedFeeRecipients[nftContract][feeRecipient];
    }

    /**
     * @notice Returns the server side signers for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getSigners(address nftContract)
        external
        view
        returns (address[] memory)
    {
        return _enumeratedSigners[nftContract];
    }

    /**
     * @notice Updates the public drop for the nft contract and emits an event.
     *
     * @param publicDrop The public drop data.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        override
        onlyIERC721SeaDrop
    {
        // Set the public drop data.
        _publicDrops[msg.sender] = publicDrop;

        // Emit an event with the update.
        emit PublicDropUpdated(msg.sender, publicDrop);
    }

    /**
     * @notice Updates the allow list merkle root for the nft contract
     *         and emits an event.
     *
     * @param allowListData The allow list data.
     */
    function updateAllowList(AllowListData calldata allowListData)
        external
        override
        onlyIERC721SeaDrop
    {
        // Track the previous root.
        bytes32 prevRoot = _allowListMerkleRoots[msg.sender];

        // Update the merkle root.
        _allowListMerkleRoots[msg.sender] = allowListData.merkleRoot;

        // Emit an event with the update.
        emit AllowListUpdated(
            msg.sender,
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
     * @param nftContract The nft contract.
     * @param allowedNftToken The token gated nft token.
     * @param dropStage The token gated drop stage data.
     */
    function updateTokenGatedDrop(
        address nftContract,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external override onlyIERC721SeaDrop {
        // Set the drop stage.
        _tokenGatedDrops[nftContract][allowedNftToken] = dropStage;

        // If the maxTotalMintableByWallet is greater than zero
        // then we are setting an active drop stage.
        if (dropStage.maxTotalMintableByWallet > 0) {
            // Add allowedNftToken to enumerated list if not present.
            bool allowedNftTokenExistsInEnumeration = false;

            // Iterate through enumerated token gated tokens for nft contract.
            for (
                uint256 i = 0;
                i < _enumeratedTokenGatedTokens[nftContract].length;

            ) {
                if (
                    _enumeratedTokenGatedTokens[nftContract][i] ==
                    allowedNftToken
                ) {
                    // Set the bool to true if found.
                    allowedNftTokenExistsInEnumeration = true;
                }
                unchecked {
                    ++i;
                }
            }

            // Add allowedNftToken to enumerated list if not present.
            if (allowedNftTokenExistsInEnumeration == false) {
                _enumeratedTokenGatedTokens[nftContract].push(allowedNftToken);
            }
        }

        // Emit an event with the update.
        emit TokenGatedDropStageUpdated(
            nftContract,
            allowedNftToken,
            dropStage
        );
    }

    /**
     * @notice Returns the allowed token gated drop tokens for the nft contract.
     *
     * @param nftContract The nft contract.
     */
    function getTokenGatedAllowedTokens(address nftContract)
        external
        view
        returns (address[] memory)
    {
        return _enumeratedTokenGatedTokens[nftContract];
    }

    /**
     * @notice Returns the token gated drop data for the nft contract
     *         and token gated nft.
     *
     * @param nftContract The nft contract.
     * @param allowedNftToken The token gated nft token.
     */
    function getTokenGatedDrop(address nftContract, address allowedNftToken)
        external
        view
        returns (TokenGatedDropStage memory)
    {
        return _tokenGatedDrops[nftContract][allowedNftToken];
    }

    /**
     * @notice Updates the drop URI and emits an event.
     *
     * @param newDropURI The new drop URI.
     */
    function updateDropURI(string calldata newDropURI)
        external
        onlyIERC721SeaDrop
    {
        // Set the new drop URI.
        _dropURIs[msg.sender] = newDropURI;

        // Emit an event with the update.
        emit DropURIUpdated(msg.sender, newDropURI);
    }

    /**
     * @notice Updates the creator payout address and emits an event.
     *
     * @param _payoutAddress The creator payout address.
     */
    function updateCreatorPayoutAddress(address _payoutAddress)
        external
        onlyIERC721SeaDrop
    {
        // Set the creator payout address.
        _creatorPayoutAddresses[msg.sender] = _payoutAddress;

        // Emit an event with the update.
        emit CreatorPayoutAddressUpdated(msg.sender, _payoutAddress);
    }

    /**
     * @notice Updates the allowed fee recipient and emits an event.
     *
     * @param feeRecipient The fee recipient.
     * @param allowed If the fee recipient is allowed.
     */
    function updateAllowedFeeRecipient(address feeRecipient, bool allowed)
        external
        onlyIERC721SeaDrop
    {
        // Set the allowed fee recipient.
        _allowedFeeRecipients[msg.sender][feeRecipient] = allowed;

        // Emit an event with the update.
        emit AllowedFeeRecipientUpdated(msg.sender, feeRecipient, allowed);
    }

    /**
     * @notice Updates the allowed server side signers and emits an event.
     *
     * @param newSigners The new list of signers.
     */
    function updateSigners(address[] calldata newSigners)
        external
        onlyIERC721SeaDrop
    {
        // Track the enumerated storage.
        address[] storage enumeratedStorage = _enumeratedSigners[msg.sender];

        // Track the old signers.
        address[] memory oldSigners = enumeratedStorage;

        // Delete old enumeration.
        delete _enumeratedSigners[msg.sender];

        // Add new enumeration.
        for (uint256 i = 0; i < newSigners.length; ) {
            enumeratedStorage.push(newSigners[i]);
            unchecked {
                ++i;
            }
        }

        // Create a mapping of the signers.
        mapping(address => bool) storage signersMap = _signers[msg.sender];

        // Delete old signers.
        for (uint256 i = 0; i < oldSigners.length; ) {
            signersMap[oldSigners[i]] = false;
            unchecked {
                ++i;
            }
        }
        // Add new signers.
        for (uint256 i = 0; i < newSigners.length; ) {
            signersMap[newSigners[i]] = true;
            unchecked {
                ++i;
            }
        }

        // Emit an event with the update.
        emit SignersUpdated(msg.sender, oldSigners, newSigners);
    }
}
