// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import {
    PublicDrop,
    MintParams,
    AllowListData,
    UserData,
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

    mapping(address => PublicDrop) private _publicDrops;
    mapping(address => ERC20) private _saleTokens;
    mapping(address => address) private _creatorPayoutAddresses;
    mapping(address => bytes32) private _merkleRoots;
    mapping(address => mapping(address => bool)) private _allowedFeeRecipients;
    mapping(address => mapping(address => bool)) private _signers;
    mapping(address => address[]) private _enumeratedSigners;
    // mapping(address => mapping(address => UserData)) public _userData;
    mapping(address => mapping(address => TokenGatedDropStage))
        private _tokenGatedDropStages;
    mapping(address => mapping(address => mapping(uint256 => bool)))
        private _tokenGatedRedeemed;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public immutable MINT_DATA_TYPEHASH;

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

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("SignatureDrop")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );

        MINT_DATA_TYPEHASH = keccak256(
            "MintParams(address minter, bool mintPrice, uint256 maxTotalMintableByWallet, uint256 startTime, uint256 endTime, uint256 dropStage, uint256 feeBps)"
        );
    }

    function mintPublic(
        address nftContract,
        address feeRecipient,
        uint256 numToMint
    ) external payable override {
        PublicDrop memory publicDrop = _publicDrops[nftContract];

        // Validate drop has started.
        if (block.timestamp < publicDrop.startTime) {
            revert NotActive(
                block.timestamp,
                publicDrop.startTime,
                type(uint64).max
            );
        }

        // Validate payment.
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, publicDrop.mintPrice);
        _checkCorrectPayment(payments);

        _checkNumberToMint(
            numToMint,
            publicDrop.maxMintsPerWallet,
            nftContract
        );
        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);
        _splitPayout(nftContract, feeRecipient, publicDrop.feeBps);
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

    function mintAllowList(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes32[] calldata proof
    ) external payable override {
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Validate payment.
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, mintParams.mintPrice);
        _checkCorrectPayment(payments);

        _checkNumberToMint(
            numToMint,
            mintParams.maxTotalMintableByWallet,
            nftContract
        );

        if (
            !MerkleProofLib.verify(
                proof,
                _merkleRoots[nftContract],
                keccak256(abi.encode(msg.sender, mintParams))
            )
        ) {
            revert InvalidProof();
        }

        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);
        _splitPayout(nftContract, feeRecipient, mintParams.feeBps);
        emit SeaDropMint(
            nftContract,
            msg.sender,
            feeRecipient,
            numToMint,
            mintParams.mintPrice,
            mintParams.feeBps,
            mintParams.dropStage
        );
    }

    function mintSigned(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes calldata signature
    ) external payable override {
        _checkActive(mintParams.startTime, mintParams.endTime);

        // Validate payment.
        PaymentValidation[] memory payments = new PaymentValidation[](1);
        payments[0] = PaymentValidation(numToMint, mintParams.mintPrice);
        _checkCorrectPayment(payments);

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

        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);
        _splitPayout(nftContract, feeRecipient, mintParams.feeBps);
        emit SeaDropMint(
            nftContract,
            msg.sender,
            feeRecipient,
            numToMint,
            mintParams.mintPrice,
            mintParams.feeBps,
            mintParams.dropStage
        );
    }

    function mintAllowedTokenHolder(
        address nftContract,
        address feeRecipient,
        TokenGatedMintParams[] calldata tokenGatedMintParams
    ) external payable override {
        // Put the total number of tokenGatedMintParams on the stack.
        uint256 totalTokenGatedMintParams = tokenGatedMintParams.length;

        // Keep track of total payments to validate sent amount.
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

            // Validate number to mint.
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

            // Validate total cost.
            _checkCorrectPayment(totalPayments);

            // Mint the tokens.
            IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);

            // Split the payout.
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
    }

    function _checkNumberToMint(
        uint256 numberToMint,
        uint256 maxMintsPerWallet,
        address nftContract
    ) internal view {
        // TODO: should SeaDrop track mints per wallet per contract?
        if (
            (numberToMint +
                IERC721SeaDrop(nftContract).numberMinted(msg.sender) >
                maxMintsPerWallet)
        ) {
            revert AmountExceedsMaxPerWallet(
                numberToMint +
                    IERC721SeaDrop(nftContract).numberMinted(msg.sender),
                maxMintsPerWallet
            );
        }
    }

    function _checkCorrectPayment(PaymentValidation[] memory payments)
        internal
        view
    {
        // Keep track of the total cost of payments.
        uint256 totalCost;

        // Iterate through the payments and add to total cost.
        for (uint256 i = 0; i < payments.length; ) {
            totalCost += payments[i].numberToMint * payments[i].mintPrice;
            unchecked {
                ++i;
            }
        }

        // Revert if the tx's value doesn't match the total cost.
        if (totalCost != msg.value) {
            revert IncorrectPayment(msg.value, totalCost);
        }
    }

    function _checkActive(uint256 startTime, uint256 endTime) internal view {
        if (block.timestamp < startTime || block.timestamp > endTime) {
            revert NotActive(block.timestamp, startTime, endTime);
        }
    }

    function _splitPayout(
        address nftContract,
        address feeRecipient,
        uint256 feeBps
    ) internal {
        uint256 feeAmount = (msg.value * feeBps) / 10000;
        uint256 payoutAmount = msg.value - feeAmount;
        ERC20 saleToken = _saleTokens[nftContract];
        if (address(saleToken) == address(0)) {
            SafeTransferLib.safeTransferETH(feeRecipient, feeAmount);
            SafeTransferLib.safeTransferETH(
                _creatorPayoutAddresses[nftContract],
                payoutAmount
            );
        } else {
            SafeTransferLib.safeTransferFrom(
                saleToken,
                msg.sender,
                feeRecipient,
                feeAmount
            );
            SafeTransferLib.safeTransferFrom(
                saleToken,
                msg.sender,
                _creatorPayoutAddresses[nftContract],
                payoutAmount
            );
        }
    }

    function getPublicDrop(address nftContract)
        external
        view
        returns (PublicDrop memory)
    {
        return _publicDrops[nftContract];
    }

    function getSaleToken(address nftContract) external view returns (address) {
        return address(_saleTokens[nftContract]);
    }

    function getCreatorPayoutAddress(address nftContract)
        external
        view
        returns (address)
    {
        return _creatorPayoutAddresses[nftContract];
    }

    function getMerkleRoot(address nftContract)
        external
        view
        returns (bytes32)
    {
        return _merkleRoots[nftContract];
    }

    function getAllowedFeeRecipient(address nftContract, address feeRecipient)
        external
        view
        returns (bool)
    {
        return _allowedFeeRecipients[nftContract][feeRecipient];
    }

    function getSigners(address nftContract)
        external
        view
        returns (address[] memory)
    {
        return _enumeratedSigners[nftContract];
    }

    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        override
        onlyIERC721SeaDrop
    {
        _publicDrops[msg.sender] = publicDrop;
        emit PublicDropUpdated(msg.sender, publicDrop);
    }

    function updateAllowList(AllowListData calldata allowListData)
        external
        override
        onlyIERC721SeaDrop
    {
        _merkleRoots[msg.sender] = allowListData.merkleRoot;
        emit AllowListUpdated(
            msg.sender,
            allowListData.leavesEncryptionPublicKey,
            allowListData.merkleRoot,
            allowListData.leavesHash,
            allowListData.leavesURI
        );
    }

    function updateTokenGatedDropStage(
        address nftContract,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external override onlyIERC721SeaDrop {
        _tokenGatedDropStages[nftContract][allowedNftToken] = dropStage;
        emit TokenGatedDropStageUpdated(
            nftContract,
            allowedNftToken,
            dropStage
        );
    }

    function getTokenGatedDrop(address nftContract, address allowedNftToken)
        external
        view
        returns (TokenGatedDropStage memory)
    {
        return _tokenGatedDropStages[nftContract][allowedNftToken];
    }

    /// @notice emit DropURIUpdated event
    function updateDropURI(string calldata dropURI)
        external
        onlyIERC721SeaDrop
    {
        emit DropURIUpdated(msg.sender, dropURI);
    }

    function updateCreatorPayoutAddress(address _payoutAddress)
        external
        onlyIERC721SeaDrop
    {
        _creatorPayoutAddresses[msg.sender] = _payoutAddress;
        emit CreatorPayoutAddressUpdated(msg.sender, _payoutAddress);
    }

    function updateAllowedFeeRecipient(
        address allowedFeeRecipient,
        bool allowed
    ) external onlyIERC721SeaDrop {
        _allowedFeeRecipients[msg.sender][allowedFeeRecipient] = allowed;
        emit AllowedFeeRecipientUpdated(
            msg.sender,
            allowedFeeRecipient,
            allowed
        );
    }

    function updateSigners(address[] calldata newSigners)
        external
        onlyIERC721SeaDrop
    {
        address[] storage enumeratedStorage = _enumeratedSigners[msg.sender];
        address[] memory oldSigners = enumeratedStorage;
        // delete old enumeration
        delete _enumeratedSigners[msg.sender];

        // add new enumeration
        for (uint256 i = 0; i < newSigners.length; ) {
            enumeratedStorage.push(newSigners[i]);
            unchecked {
                ++i;
            }
        }

        mapping(address => bool) storage signersMap = _signers[msg.sender];
        // delete old signers
        for (uint256 i = 0; i < oldSigners.length; ) {
            signersMap[oldSigners[i]] = false;
            unchecked {
                ++i;
            }
        }
        // add new signers
        for (uint256 i = 0; i < newSigners.length; ) {
            signersMap[newSigners[i]] = true;
            unchecked {
                ++i;
            }
        }
        emit SignersUpdated(msg.sender, oldSigners, newSigners);
    }
}
