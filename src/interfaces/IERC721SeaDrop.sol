// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    IERC721ContractMetadata
} from "../interfaces/IERC721ContractMetadata.sol";
import {
    PublicDrop,
    AllowListData,
    TokenGatedDropStage
} from "../lib/SeaDropStructs.sol";

import {
    IERC165
} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

interface IERC721SeaDrop is IERC721ContractMetadata, IERC165 {
    error OnlySeaDrop();

    // doing `maxMintsPerWallet` check here may be cheaper
    function mintSeaDrop(address minter, uint256 amount) external payable;

    // to enforce maxMintsPerWallet checks - should SeaDrop track this?
    function numberMinted(address minter) external view returns (uint256);

    // These methods can all consist of a single line: seaDropImpl.updateFunction(params);

    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external;

    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    ) external;

    function updateTokenGatedDropStage(
        address nftContract,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external;

    function removeTokenGatedDropStage(
        address nftContract,
        address allowedNftTokenToRemove
    ) external;

    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external;

    function updateCreatorPayoutAddress(
        address seaDropImpl,
        address payoutAddress
    ) external;

    function updateAllowedFeeRecipient(
        address seaDropImpl,
        address feeRecipient,
        bool allowed
    ) external;

    function updateSigners(address seaDropImpl, address[] calldata signers)
        external;
}
