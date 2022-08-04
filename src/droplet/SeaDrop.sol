// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { ISeaDrop } from "./ISeaDrop.sol";

import {
    PublicDrop,
    MintParams,
    AllowListData,
    UserData
} from "./SeaDropStructs.sol";
import { ERC20, SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { DropEventsAndErrors } from "../DropEventsAndErrors.sol";
import { IERC721SeaDrop } from "./IERC721SeaDrop.sol";
import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";

import {
    ECDSA
} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

contract SeaDrop is ISeaDrop, DropEventsAndErrors {
    using ECDSA for bytes32;

    mapping(address => PublicDrop) private _publicDrops;
    mapping(address => ERC20) private _saleTokens;
    mapping(address => address) private _creatorPayoutAddresses;
    mapping(address => bytes32) private _merkleRoots;
    mapping(address => mapping(address => bool)) private _allowedFeeRecipients;
    mapping(address => mapping(address => bool)) private _signers;
    mapping(address => address[]) private _enumeratedSigners;
    // mapping(address => mapping(address => UserData)) public _userData;

    bytes32 public immutable DOMAIN_SEPARATOR;
    bytes32 public immutable MINT_DATA_TYPEHASH;

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

    /**
     * @notice Modifier that checks numberToMint against maxPerTransaction and publicDrop.maxMintsPerWallet
     */
    modifier checkNumberToMint(
        IERC721SeaDrop nftToken,
        uint256 numberToMint,
        PublicDrop memory publicDrop // todo: we may be able to trust AllowListMint's maxTotalMintsForWallet - but we might not want to
    ) {
        {
            // if (numberToMint > publicDrop.maxMintsPerTransaction) {
            //     revert AmountExceedsMaxPerTransaction(
            //         numberToMint,
            //         publicDrop.maxMintsPerTransaction
            //     );
            // }
        }
        _;
    }

    modifier isAllowListed(
        bytes32 leaf,
        bytes32 merkleRoot,
        bytes32[] calldata proof
    ) {
        {
            if (!MerkleProofLib.verify(proof, merkleRoot, leaf)) {
                revert InvalidProof();
            }
        }
        _;
    }

    function mintPublic(
        address nftContract,
        address feeRecipient,
        uint256 numToMint
    )
        external
        payable
        override
        checkNumberToMint(
            IERC721SeaDrop(nftContract),
            numToMint,
            _publicDrops[nftContract]
        )
    {
        PublicDrop memory publicDrop = _publicDrops[nftContract];
        if (block.timestamp < publicDrop.startTime) {
            revert NotActive(
                block.timestamp,
                publicDrop.startTime,
                type(uint64).max
            );
        }
        _checkCorrectPayment(numToMint, publicDrop.mintPrice);
        _checkNumberToMint(
            numToMint,
            publicDrop.maxMintsPerWallet,
            nftContract
        );
        IERC721SeaDrop(nftContract).mintSeaDrop(msg.sender, numToMint);
        _splitPayout(nftContract, feeRecipient, publicDrop.feeBps);
    }

    function mintAllowList(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes32[] calldata proof
    ) external payable override {
        _checkActive(mintParams.startTime, mintParams.endTime);
        _checkCorrectPayment(numToMint, mintParams.mintPrice);
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
    }

    function mintSigned(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes calldata signature
    ) external payable override {
        _checkActive(mintParams.startTime, mintParams.endTime);
        _checkCorrectPayment(numToMint, mintParams.mintPrice);
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

    function _checkCorrectPayment(uint256 numberToMint, uint256 mintPrice)
        internal
        view
    {
        if (numberToMint * mintPrice != msg.value) {
            revert IncorrectPayment(msg.value, numberToMint * mintPrice);
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

    // function getUserData(address nftContract, address user)
    //     external
    //     view
    //     returns (UserData memory)
    // {
    //     return _userData[nftContract][user];
    // }

    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        override
    {
        _publicDrops[msg.sender] = publicDrop;
        emit PublicDropUpdated(msg.sender, publicDrop);
    }

    function updateAllowList(AllowListData calldata allowListData)
        external
        override
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

    /// @notice emit DropURIUpdated event
    function updateDropURI(string calldata dropURI) external {
        emit DropURIUpdated(msg.sender, dropURI);
    }

    function updateCreatorPayoutAddress(address _payoutAddress) external {
        _creatorPayoutAddresses[msg.sender] = _payoutAddress;
        emit CreatorPayoutAddressUpdated(msg.sender, _payoutAddress);
    }

    function updateAllowedFeeRecipient(
        address allowedFeeRecipient,
        bool allowed
    ) external {
        _allowedFeeRecipients[msg.sender][allowedFeeRecipient] = allowed;
        emit AllowedFeeRecipientUpdated(
            msg.sender,
            allowedFeeRecipient,
            allowed
        );
    }

    function updateSigners(address[] calldata newSigners) external {
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
