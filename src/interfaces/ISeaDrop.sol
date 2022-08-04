// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    PublicDrop,
    MintParams,
    AllowListData,
    UserData,
    TokenGatedDropStage,
    TokenGatedMintParams
} from "../lib/SeaDropStructs.sol";
import { SeaDropErrorsAndEvents } from "../lib/SeaDropErrorsAndEvents.sol";

interface ISeaDrop is SeaDropErrorsAndEvents {
    function mintPublic(
        address nftContract,
        address feeRecipient,
        uint256 numToMint
    ) external payable;

    function mintAllowList(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes32[] calldata proof
    ) external payable;

    function mintSigned(
        address nftContract,
        address feeRecipient,
        uint256 numToMint,
        MintParams calldata mintParams,
        bytes calldata signature
    ) external payable;

    function mintApprovedTokenHolder(
        address nftContract,
        address feeRecipient,
        TokenGatedMintParams[] calldata tokenGatedMintParams
    ) external payable;

    function getPublicDrop(address nftContract)
        external
        view
        returns (PublicDrop memory);

    function getCreatorPayoutAddress(address nftContract)
        external
        view
        returns (address);

    function getMerkleRoot(address nftContract) external view returns (bytes32);

    function getAllowedFeeRecipient(address nftContract, address feeRecipient)
        external
        view
        returns (bool);

    function getSigners(address nftContract)
        external
        view
        returns (address[] memory);

    // the following methods assume msg.sender is an nft contract; should check ERC165 of sender when ingesting events

    /// @notice update public drop and emit PublicDropUpdated event
    function updatePublicDrop(PublicDrop calldata publicDrop) external; // onlyOwnerOrAdministrator - doesn't update fee

    /// @notice update merkle root and emit AllowListUpdated event
    function updateAllowList(AllowListData calldata allowListData) external; // onlyOwnerOrAdministrator

    /// @notice emit DropURIUpdated event
    function updateDropURI(string calldata dropURI) external;

    /// @notice set creator payout address and emit CreatorPayoutAddressUpdated event
    function updateCreatorPayoutAddress(address payoutAddress) external;

    /// @notice set allowed for fee recipient and emit AllowedFeeRecipientUpdated event
    function updateAllowedFeeRecipient(address feeRecipient, bool allowed)
        external;

    /// @notice set signers and emit SignersUpdated event
    function updateSigners(address[] calldata signers) external;

    /// @notice update a token gated drop stage
    function updateTokenGatedDropStage(
        address nftContract,
        address allowedNftToken,
        TokenGatedDropStage calldata dropStage
    ) external;

    /// @notice remove a token gated drop stage
    function removeTokenGatedDropStage(
        address nftContract,
        address allowedNftTokenToRemove
    ) external;

    function getTokenGatedDrop(address nftContract, address allowedNftToken)
        external
        view
        returns (TokenGatedDropStage memory);
}
