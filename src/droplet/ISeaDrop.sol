// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    PublicDrop,
    AllowListMint,
    AllowListMintOption,
    AllowListData,
    UserData
} from "./SeaDropStructs.sol";
import { SeaDropErrorsAndEvents } from "./SeaDropErrorsAndEvents.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

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

    function publicDrops(address nftContract)
        external
        view
        returns (PublicDrop memory);

    function saleTokens(address nftContract) external view returns (address);

    function creatorPayoutAddresses(address nftContract)
        external
        view
        returns (address);

    function merkleRoots(address nftContract) external view returns (bytes32);

    function userData(address nftContract, address user)
        external
        view
        returns (UserData memory);

    // the following methods assume msg.sender is an nft contract; should check ERC165 when ingesting events

    /// @notice update public drop and emit PublicDropUpdated event
    function updatePublicDrop(PublicDrop calldata publicDrop) external; // onlyOwnerOrAdministrator - doesn't update fee

    /// @notice update merkle root and emit MerkleRootUpdated event
    function updateAllowList(AllowListData calldata allowListData) external; // onlyOwnerOrAdministrator

    /// @notice update sale token for nftContract and emit AllowListUpdated event
    function updateSaleToken(address saleToken) external; // onlyOwnerOrAdministrator - backend should filter on acceptable tokens

    /// @notice emit DropURIUpdated event
    function updateDropURI(string calldata dropURI) external; // onlyOwnerOrAdministrator

    function updateCreatorPayoutAddress(address payoutAddress) external;
    // onlyOwner - primary sale payout address
}
