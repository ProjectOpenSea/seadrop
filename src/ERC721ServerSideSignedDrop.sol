// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.11;

// import { ERC721A } from "./token/ERC721A.sol";
// import { DropEventsAndErrors } from "./DropEventsAndErrors.sol";
// import {
//     ECDSA
// } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
// import {
//     IERC721ServerSideSignedDrop
// } from "./interfaces/IERC721ServerSideSignedDrop.sol";
// import { ERC721Drop, IERC721ContractMetadata } from "./ERC721Drop.sol";
// import { MaxMintable } from "utility-contracts/MaxMintable.sol";
// import { DropEventsAndErrors } from "./DropEventsAndErrors.sol";

// contract ERC721ServerSideSignedDrop is ERC721Drop, IERC721ServerSideSignedDrop {
//     using ECDSA for bytes32;

//     error SigningNotEnabled();
//     error InvalidSignature(address got);
//     error CallerIsNotMinter(address got, address want);

//     address internal commissionAddress;
//     uint256 internal commissionPayout;
//     bytes32 public immutable DOMAIN_SEPARATOR;

//     address[] signers;
//     mapping(address => bool) public isSigner;

//     bytes32 public constant MINT_DATA_TYPEHASH =
//         keccak256(
//             "MintData(address wallet, bool allowList, uint256 mintPrice, uint256 maxNumberMinted, uint256 startTimeStamp, uint256 endTimestamp, uint256 feeBps)"
//         );

//     modifier requiresValidSigner(
//         MintData calldata mintData,
//         bytes calldata signature
//     ) {
//         {
//             if (signers.length == 0) {
//                 revert SigningNotEnabled();
//             }
//             // Verify EIP-712 signature by recreating the data structure
//             // that we signed on the client side, and then using that to recover
//             // the address that signed the signature for this data.
//             bytes32 digest = keccak256(
//                 abi.encodePacked(
//                     bytes2(0x1901),
//                     DOMAIN_SEPARATOR,
//                     keccak256(
//                         abi.encode(MINT_DATA_TYPEHASH, msg.sender, mintData)
//                     )
//                 )
//             );
//             // Use the recover method to see what address was used to create
//             // the signature on this data.
//             // Note that if the digest doesn't exactly match what was signed we'll
//             // get a random recovered address.
//             address recoveredAddress = digest.recover(signature);
//             if (!isSigner[recoveredAddress]) {
//                 revert InvalidSignature(recoveredAddress);
//             }
//         }
//         _;
//     }

//     constructor(
//         string memory name,
//         string memory symbol,
//         PublicDrop memory publicDrop,
//         address administrator,
//         address saleToken,
//         address signer
//     ) ERC721Drop(name, symbol, administrator, publicDrop, saleToken) {
//         // TODO: work this into immutable
//         DOMAIN_SEPARATOR = keccak256(
//             abi.encode(
//                 keccak256(
//                     "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
//                 ),
//                 keccak256(bytes("SignatureDrop")),
//                 keccak256(bytes("1")),
//                 block.chainid,
//                 address(this)
//             )
//         );
//         _addSigner(signer);
//         // signingAddress = signer;
//     }

//     modifier allowListNotRedeemed(bool allowList) {
//         {
//             if (allowList) {
//                 if (isAllowListRedeemed(msg.sender)) {
//                     revert AllowListRedeemed();
//                 }
//             }
//         }
//         _;
//     }

//     function mint(
//         uint256 numberToMint,
//         MintData calldata mintData,
//         bytes calldata signature
//     )
//         public
//         payable
//         override
//         requiresValidSigner(mintData, signature)
//         isActive(mintData.startTimestamp, mintData.endTimestamp)
//         allowListNotRedeemed(mintData.allowList)
//         // checkMaxMintedForWallet(numberToMint, 0)
//         includesCorrectPayment(numberToMint, mintData.mintPrice)
//     {
//         // if (numberToMint > mintData.maxNumberMinted) {
//         //     revert AmountExceedsAllowed(numberToMint, mintData.maxNumberMinted);
//         // }
//         _mint(msg.sender, numberToMint);
//     }

//     function setSigners(address[] memory newSigners)
//         external
//         override
//         onlyAdministrator
//     {
//         address[] memory oldSigners = signers;
//         delete signers;
//         for (uint256 i = 0; i < oldSigners.length; i++) {
//             isSigner[oldSigners[i]] = false;
//         }
//         for (uint256 i = 0; i < newSigners.length; i++) {
//             isSigner[newSigners[i]] = true;
//             signers.push(newSigners[i]);
//         }
//         emit SignersUpdated(oldSigners, newSigners);
//     }

//     function addSigner(address newSigner) external override onlyAdministrator {
//         _addSigner(newSigner);
//     }

//     function _addSigner(address newSigner) internal {
//         address[] memory oldSigners = signers;
//         address[] memory newSigners = new address[](oldSigners.length + 1);
//         for (uint256 i = 0; i < oldSigners.length; i++) {
//             newSigners[i] = oldSigners[i];
//         }
//         newSigners[oldSigners.length] = newSigner;
//         signers.push(newSigner);
//         isSigner[newSigner] = true;
//         emit SignersUpdated(oldSigners, newSigners);
//     }

//     function getSigners() external view override returns (address[] memory) {
//         return signers;
//     }

//     function removeSigner(address signer) external override {}

//     function setAllowListRedeemed(address minter) internal {
//         _setAux(minter, 1);
//     }

//     function isAllowListRedeemed(address minter) internal view returns (bool) {
//         return _getAux(minter) & 1 == 1;
//     }

//     function totalSupply()
//         public
//         view
//         virtual
//         override(ERC721Drop, IERC721ContractMetadata)
//         returns (uint256)
//     {
//         return ERC721A.totalSupply();
//     }
// }
