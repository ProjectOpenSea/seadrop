// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import {
    PublicDrop,
    MintParams,
    AllowListData,
    TokenGatedDropStage,
    TokenGatedMintParams,
    PaymentValidation
} from "./lib/SeaDropStructs.sol";
import { ERC20, SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IERC721SeaDrop } from "./interfaces/IERC721SeaDrop.sol";
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

contract SeaDrop is ISeaDrop {
    using ECDSA for bytes32;

    // Track the public drops.
    mapping(address => PublicDrop) private _publicDrops;

    // Track the drop URIs.
    mapping(address => string) private _dropURI;

    // Track the sale tokens.
    mapping(address => ERC20) private _saleTokens;

    // Track the creator payout addresses.
    mapping(address => address) private _creatorPayoutAddresses;

    // Track the allow list merkle roots.
    mapping(address => bytes32) private _merkleRoots;

    // Track the allowed fee recipients.
    mapping(address => mapping(address => bool)) private _allowedFeeRecipients;

    // Track the allowed signers for server side drops.
    mapping(address => mapping(address => bool)) private _signers;

    // Track the signers for each server side drop.
    mapping(address => address[]) private _enumeratedSigners;

    // Track token gated drop stages.
    mapping(address => mapping(address => TokenGatedDropStage))
        private _tokenGatedDropStages;

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
     */
    function mintPublic(
        address nftContract,
        address feeRecipient,
        uint256 numToMint
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
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, publicDrop.mintPrice);
        _checkCorrectPayment(nftContract, payments);

        // Check that the wallet is allowed to mint the desired quantity.
        _checkNumberToMint(
            numToMint,
            publicDrop.maxMintsPerWallet,
            nftContract
        );

        // Mint the token(s).
        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);

        // Split the payment between the creator and fee recipient.
        _splitPayout(nftContract, feeRecipient, publicDrop.feeBps);

        // Emit an event for the mint.
        emit SeaDropMint(
            nftContract,
            msg.sender,
            feeRecipient,
            numToMint,
            publicDrop.mintPrice,
            publicDrop.feeBps,
            0
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
     */
    function mintAllowList(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes32[] calldata proof
    ) external payable override {
        // Check that the drop stage is active.
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Validate correct payment.
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, mintParams.mintPrice);
        _checkCorrectPayment(nftContract, payments);

        // Check that the wallet is allowed to mint the desired quantity.
        _checkNumberToMint(
            numToMint,
            mintParams.maxTotalMintableByWallet,
            nftContract
        );

        // Verify the proof.
        if (
            !MerkleProofLib.verify(
                proof,
                _merkleRoots[nftContract],
                keccak256(abi.encode(msg.sender, mintParams))
            )
        ) {
            revert InvalidProof();
        }

        // Mint the token(s).
        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);

        // Split the payment between the creator and fee recipient.
        _splitPayout(nftContract, feeRecipient, mintParams.feeBps);

        // Emit an event for the mint.
        emit SeaDropMint(
            nftContract,
            msg.sender,
            feeRecipient,
            numToMint,
            mintParams.mintPrice,
            mintParams.feeBps,
            mintParams.dropStageIndex
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
     */
    function mintSigned(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes calldata signature
    ) external payable override {
        // Check that the drop stage is active.
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Validate correct payment.
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, mintParams.mintPrice);
        _checkCorrectPayment(nftContract, payments);

        // Check that the wallet is allowed to mint the desired quantity.
        _checkNumberToMint(
            numToMint,
            mintParams.maxTotalMintableByWallet,
            nftContract
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

        // Mint the token(s).
        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);

        // Split the payment between the creator and fee recipient.
        _splitPayout(nftContract, feeRecipient, mintParams.feeBps);

        // Emit an event for the mint.
        emit SeaDropMint(
            nftContract,
            msg.sender,
            feeRecipient,
            numToMint,
            mintParams.mintPrice,
            mintParams.feeBps,
            mintParams.dropStageIndex
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
     */
    function mintAllowedTokenHolder(
        address nftContract,
        address feeRecipient,
        TokenGatedMintParams[] calldata tokenGatedMintParams
    ) external payable override {
        // Put the total number of tokenGatedMintParams on the stack.
        uint256 totalTokenGatedMintParams = tokenGatedMintParams.length;

        // Track total mint cost to compare against value sent with tx.
        PaymentValidation[] memory totalPayments = new PaymentValidation[](
            totalTokenGatedMintParams
        );

        // Iterate through each allowedNftToken.
        for (uint256 i = 0; i < totalTokenGatedMintParams; ) {
            // Set the mintParams to a variable.
            TokenGatedMintParams calldata mintParams = tokenGatedMintParams[i];

            // Set the dropStage to a variable.
            TokenGatedDropStage storage dropStage = _tokenGatedDropStages[
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
                numToMint,
                dropStage.maxTotalMintableByWallet,
                nftContract
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

                // Check that the token id has not already
                // been used to be redeemed.
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

            // Mint the tokens.
            IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);

            // Split the payment between the creator and fee recipient.
            _splitPayout(nftContract, feeRecipient, dropStage.feeBps);

            // Emit an event for the mint.
            emit SeaDropMint(
                nftContract,
                msg.sender,
                feeRecipient,
                numToMint,
                dropStage.mintPrice,
                dropStage.feeBps,
                0
            );

            unchecked {
                ++i;
            }
        }

        // Validate correct payment.
        _checkCorrectPayment(nftContract, totalPayments);
    }

    /**
     * @notice Check that the wallet is allowed to mint the desired quantity.
     *
     * @param numberToMint The number of tokens to mint.
     * @param maxMintsPerWallet The allowed max mints per wallet.
     * @param nftContract The nft contract.
     */
    function _checkNumberToMint(
        uint256 numberToMint,
        uint256 maxMintsPerWallet,
        address nftContract
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
    }

    /**
     * @notice For native sale token, check that the correct payment
     *         was sent with the tx. For ERC20 sale token, check
     *         that the sender has sufficient balance and allowance.
     *
     * @param payments The payments to validate.
     */
    function _checkCorrectPayment(
        address nftContract,
        PaymentValidation[] memory payments
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
            if (totalCost != msg.value) {
                revert IncorrectPayment(msg.value, totalCost);
            }
        } else {
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
            uint256 allowance = saleToken.allowance(msg.sender, address(this));
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
     * @notice Split the payment payout for the creator and fee recipient.
     *
     * @param nftContract The nft contract.
     * @param feeRecipient The fee recipient.
     * @param feeBps The fee basis points.
     */
    function _splitPayout(
        address nftContract,
        address feeRecipient,
        uint256 feeBps
    ) internal {
        // Get the fee amount.
        uint256 feeAmount = (msg.value * feeBps) / 10000;

        // Get the creator payout amount.
        uint256 payoutAmount = msg.value - feeAmount;

        // Get the sale token.
        ERC20 saleToken = _saleTokens[nftContract];

        // If the saleToken is the zero address, transfer the native currency.
        if (address(saleToken) == address(0)) {
            // Transfer native currency to the fee recipient.
            SafeTransferLib.safeTransferETH(feeRecipient, feeAmount);

            // Transfer native currency to the creator.
            SafeTransferLib.safeTransferETH(
                _creatorPayoutAddresses[nftContract],
                payoutAmount
            );
        } else {
            // Transfer ERC20 to the fee recipient.
            SafeTransferLib.safeTransferFrom(
                saleToken,
                msg.sender,
                feeRecipient,
                feeAmount
            );

            // Transfer ERC20 to the creator.
            SafeTransferLib.safeTransferFrom(
                saleToken,
                msg.sender,
                _creatorPayoutAddresses[nftContract],
                payoutAmount
            );
        }
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
    function getMerkleRoot(address nftContract)
        external
        view
        returns (bytes32)
    {
        return _merkleRoots[nftContract];
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
        bytes32 prevRoot = _merkleRoots[msg.sender];

        // Update the merkle root.
        _merkleRoots[msg.sender] = allowListData.merkleRoot;

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
    function updateTokenGatedDropStage(
        address nftContract,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external override onlyIERC721SeaDrop {
        // Set the drop stage.
        _tokenGatedDropStages[nftContract][allowedNftToken] = dropStage;

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
        return _tokenGatedDropStages[nftContract][allowedNftToken];
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
        _dropURI[msg.sender] = newDropURI;

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
