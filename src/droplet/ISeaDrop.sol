// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    PublicDrop,
    AllowListMint,
    AllowListMintOption,
    AllowListData
} from "./SeaDropStructs.sol";
import { SeaDropErrorsAndEvents } from "./SeaDropErrorsAndEvents.sol";

interface ISeaDrop is SeaDropErrorsAndEvents {
    function mintPublic(
        address nftContract,
        address feeRecipient,
        uint256 amount
    ) external payable;

    function mintPublicOption(
        address nftContract,
        address feeRecipient,
        uint256 amount,
        uint256 tokenOrOptionId
    ) external payable;

    function mintAllowList(
        address nftContract,
        address feeRecipient,
        AllowListMint calldata mintParams
    ) external payable;

    function mintAllowListOption(
        address nftContract,
        address feeRecipient,
        uint256 tokenOrOptionId,
        AllowListMint calldata mintParams
    ) external payable;

    // the following methods assume msg.sender is an nft contract; should check ERC165 when ingesting events

    /// @notice update public drop and emit PublicDropUpdated event
    function updatePublicDrop(PublicDrop calldata publicDrop) external; // onlyOwnerOrAdministrator - doesn't update fee

    /// @notice update merkle root and emit MerkleRootUpdated event
    function updateAllowList(AllowListData calldata allowListData) external; // onlyOwnerOrAdministrator

    /// @notice update sale token for nftContract and emit AllowListUpdated event
    function updateSaleToken(address saleToken) external; // onlyOwnerOrAdministrator - backend should filter on acceptable tokens

    /// @notice emit DropURIUpdated event
    function updateDropURI(string calldata dropURI) external; // onlyOwnerOrAdministrator

    function updateCreatorPayoutAddress(address payoutAddress) external; // onlyOwner - primary sale payout address
}
