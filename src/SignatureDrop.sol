// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {ERC721A} from "./token/ERC721A.sol";
import {MaxMintable} from "utility-contracts/MaxMintable.sol";
import {DropEventsAndErrors} from "./DropEventsAndErrors.sol";
import {TwoStepAdministered, TwoStepOwnable} from "utility-contracts/TwoStepAdministered.sol";
import {AllowList} from "utility-contracts/AllowList.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ConstructorInitializable} from "utility-contracts/ConstructorInitializable.sol";

contract SignatureDrop is
    ERC721A,
    TwoStepAdministered,
    MaxMintable,
    DropEventsAndErrors
{
    using ECDSA for bytes32;

    error SigningNotEnabled();
    error InvalidSignature(address got, address want);
    error CallerIsNotMinter(address got, address want);

    struct MintData {
        bool allowList;
        uint256 mintPrice;
        uint256 maxNumberMinted;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 feeBps;
    }

    address internal commissionAddress;
    uint256 internal commissionPayout;
    address public signingAddress;
    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 public constant MINT_DATA_TYPEHASH =
        keccak256(
            "MintData(address wallet, bool allowList, uint256 mintPrice, uint256 maxNumberMinted, uint256 startTimeStamp, uint256 endTimestamp, uint256 feeBps)"
        );

    modifier requiresValidSigner(
        MintData calldata mintData,
        bytes calldata signature
    ) {
        {
            if (signingAddress == address(0)) {
                revert SigningNotEnabled();
            }
            // Verify EIP-712 signature by recreating the data structure
            // that we signed on the client side, and then using that to recover
            // the address that signed the signature for this data.
            bytes32 digest = keccak256(
                abi.encodePacked(
                    bytes2(0x1901),
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            MINT_DATA_TYPEHASH,
                            msg.sender,
                            mintData.allowList,
                            mintData.mintPrice,
                            mintData.maxNumberMinted,
                            mintData.startTimestamp,
                            mintData.endTimestamp,
                            mintData.feeBps
                        )
                    )
                )
            );
            // Use the recover method to see what address was used to create
            // the signature on this data.
            // Note that if the digest doesn't exactly match what was signed we'll
            // get a random recovered address.
            address recoveredAddress = digest.recover(signature);
            if (recoveredAddress != signingAddress) {
                revert InvalidSignature(recoveredAddress, signingAddress);
            }
        }
        _;
    }

    modifier isActive(uint256 startTimestamp, uint256 endTimestamp) {
        {
            if (
                block.timestamp < startTimestamp ||
                block.timestamp > endTimestamp
            ) {
                revert NotActive(block.timestamp, startTimestamp, endTimestamp);
            }
        }

        _;
    }

    modifier allowListNotRedeemed(bool allowList) {
        {
            if (allowList) {
                if (isAllowListRedeemed(msg.sender)) {
                    revert AllowListRedeemed();
                }
            }
        }
        _;
    }

    modifier includesCorrectPayment(uint256 numberToMint, uint256 mintPrice) {
        {
            if (numberToMint * mintPrice != msg.value) {
                revert IncorrectPayment(msg.value, numberToMint * mintPrice);
            }
        }
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxNumMintable,
        address administrator,
        address signer
    )
        ERC721A(name, symbol)
        MaxMintable(maxNumMintable)
        TwoStepAdministered(administrator)
    {
        // TODO: work this into immutable
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
        signingAddress = signer;
    }

    function mint(
        uint256 numberToMint,
        MintData calldata mintData,
        bytes calldata signature
    )
        public
        payable
        requiresValidSigner(mintData, signature)
        isActive(mintData.startTimestamp, mintData.endTimestamp)
        allowListNotRedeemed(mintData.allowList)
        checkMaxMintedForWallet(numberToMint)
        includesCorrectPayment(numberToMint, mintData.mintPrice)
    {
        if (numberToMint > mintData.maxNumberMinted) {
            revert AmountExceedsAllowed(numberToMint, mintData.maxNumberMinted);
        }
        _mint(msg.sender, numberToMint);
    }

    function setAllowListRedeemed(address minter) internal {
        _setAux(minter, 1);
    }

    function isAllowListRedeemed(address minter) internal view returns (bool) {
        return _getAux(minter) & 1 == 1;
    }

    function setSigningAddress(address newSigner) public onlyAdministrator {
        signingAddress = newSigner;
    }

    function setCommissionAddress(address newCommissionAddress)
        public
        onlyAdministrator
    {
        commissionAddress = newCommissionAddress;
    }

    function _numberMinted(address minter)
        internal
        view
        virtual
        override(MaxMintable, ERC721A)
        returns (uint256)
    {
        return ERC721A._numberMinted(minter);
    }
}
