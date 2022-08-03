// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { ISeaDrop } from "./ISeaDrop.sol";

import {
    PublicDrop,
    AllowListMint,
    AllowListData,
    UserData
} from "./SeaDropStructs.sol";
import { ERC20, SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { DropEventsAndErrors } from "../DropEventsAndErrors.sol";
import { IERC721SeaDrop } from "./IERC721SeaDrop.sol";

contract SeaDrop is ISeaDrop, DropEventsAndErrors {
    mapping(address => PublicDrop) public publicDrops;
    mapping(address => ERC20) public saleTokens;
    mapping(address => address) public payoutAddresses;
    mapping(address => bytes32) public merkleRoots;
    mapping(address => mapping(address => UserData)) public userData;

    modifier isActive(PublicDrop memory publicDrop) {
        {
            if (
                block.timestamp < publicDrop.startTime ||
                block.timestamp > publicDrop.endTime
            ) {
                revert NotActive(
                    block.timestamp,
                    publicDrop.startTime,
                    publicDrop.endTime
                );
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

    /**
     * @notice Modifier that checks numberToMint against maxPerTransaction and publicDrop.maxMintsPerWallet
     */
    modifier checkNumberToMint(
        IERC721SeaDrop saleToken,
        uint256 numberToMint,
        PublicDrop memory publicDrop
    ) {
        {
            if (numberToMint > publicDrop.maxMintsPerTransaction) {
                revert AmountExceedsMaxPerTransaction(
                    numberToMint,
                    publicDrop.maxMintsPerTransaction
                );
            }
            if (
                (numberToMint + saleToken.numberMinted(msg.sender) >
                    publicDrop.maxMintsPerWallet)
            ) {
                revert AmountExceedsMaxPerWallet(
                    numberToMint + saleToken.numberMinted(msg.sender),
                    publicDrop.maxMintsPerWallet
                );
            }
        }
        _;
    }

    function mintPublic(
        address nftContract,
        uint256 feeRecipient,
        uint256 amount
    ) external payable override {}

    function mintPublicOption(
        address nftContract,
        uint256 feeRecipient,
        uint256 amount,
        uint256 tokenOrOptionId
    ) external payable override {}

    function mintAllowList(
        address nftContract,
        address feeRecipient,
        AllowListMint calldata mintParams
    ) external payable override {}

    function mintAllowListOption(
        address nftContract,
        address feeRecipient,
        uint256 tokenOrOptionId,
        AllowListMint calldata mintParams
    ) external payable override {}

    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        override
    {
        publicDrops[msg.sender] = publicDrop;
        emit PublicDropUpdated(msg.sender, publicDrop);
    }

    function updateAllowList(AllowListData calldata allowListData)
        external
        override
    {
        merkleRoots[msg.sender] = allowListData.merkleRoot;
        emit AllowListUpdated(
            msg.sender,
            allowListData.leavesEncryptionPublicKey,
            allowListData.merkleRoot,
            allowListData.leavesHash,
            allowListData.leavesURI
        );
    }

    /// @notice update sale token for nftContract and emit AllowListUpdated event
    function updateSaleToken(address saleToken) external {
        saleTokens[msg.sender] = ERC20(saleToken);
        emit SaleTokenUpdated(msg.sender, saleToken);
    }

    /// @notice emit DropURIUpdated event
    function updateDropURI(string calldata dropURI) external {
        emit DropURIUpdated(msg.sender, dropURI);
    }

    function updatePayoutAddress(address _payoutAddress) external {
        payoutAddresses[msg.sender] = _payoutAddress;
        emit PayoutAddressUpdated(msg.sender, _payoutAddress);
    }
}
