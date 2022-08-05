// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    IERC721SeaDrop,
    IERC721ContractMetadata
} from "./interfaces/IERC721SeaDrop.sol";
import {
    ERC721ContractMetadata,
    IERC721ContractMetadata
} from "./ERC721ContractMetadata.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

import { TwoStepAdministered } from "utility-contracts/TwoStepAdministered.sol";

import { SeaDrop } from "./SeaDrop.sol";

import { ISeaDrop } from "./interfaces/ISeaDrop.sol";

import { SeaDropErrorsAndEvents } from "./lib/SeaDropErrorsAndEvents.sol";
import { PublicDrop, AllowListData } from "./lib/SeaDropStructs.sol";

contract ERC721SeaDrop is
    ERC721ContractMetadata,
    IERC721SeaDrop,
    SeaDropErrorsAndEvents
{
    ISeaDrop internal immutable _SEADROP;

    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address seadrop
    ) ERC721ContractMetadata(name, symbol, administrator) {
        _SEADROP = ISeaDrop(seadrop);
    }

    modifier onlySeaDrop() {
        if (msg.sender != address(_SEADROP)) {
            revert OnlySeaDrop();
        }
        _;
    }

    function mintSeaDrop(address minter, uint256 amount)
        external
        payable
        override
        onlySeaDrop
    {
        // use ConsecutiveTransfer event
        _mintERC2309(minter, amount);
    }

    function updatePublicDrop(address, PublicDrop calldata publicDrop)
        external
        virtual
        override
        onlyOwner
    {
        PublicDrop memory retrieved = _SEADROP.getPublicDrop(address(this));
        PublicDrop memory supplied = publicDrop;
        // only administrator (OpenSea) should be able to set feeBps
        supplied.feeBps = retrieved.feeBps;
        retrieved.restrictFeeRecipients = true;
        _SEADROP.updatePublicDrop(supplied);
    }

    function updatePublicDropFee(uint16 feeBps)
        external
        virtual
        onlyAdministrator
    {
        PublicDrop memory retrieved = _SEADROP.getPublicDrop(address(this));
        retrieved.feeBps = feeBps;
        retrieved.restrictFeeRecipients = true;
        _SEADROP.updatePublicDrop(retrieved);
    }

    function updateAllowList(address, AllowListData calldata allowListData)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        _SEADROP.updateAllowList(allowListData);
    }

    function updateDropURI(address, string calldata dropURI)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        _SEADROP.updateDropURI(dropURI);
    }

    /// @notice only owner should be able to set payout address
    function updateCreatorPayoutAddress(address, address payoutAddress)
        external
        onlyOwner
    {
        _SEADROP.updateCreatorPayoutAddress(payoutAddress);
    }

    function updateAllowedFeeRecipient(
        address,
        address feeRecipient,
        bool allowed
    ) external onlyAdministrator {
        _SEADROP.updateAllowedFeeRecipient(feeRecipient, allowed);
    }

    function updateSigners(address, address[] calldata newSigners)
        external
        virtual
        override
        onlyOwner
    {
        _SEADROP.updateSigners(newSigners);
    }

    function numberMinted(address minter) external view returns (uint256) {
        return _numberMinted(minter);
    }

    function getMintStats(address minter)
        external
        view
        returns (
            uint256 minterNumMinted,
            uint256 currentTotalSupply,
            uint256 maxSupply_
        )
    {
        minterNumMinted = _numberMinted(minter);
        currentTotalSupply = totalSupply();
        maxSupply_ = _maxSupply;
    }

    function totalSupply()
        public
        view
        virtual
        override(IERC721ContractMetadata, ERC721ContractMetadata)
        returns (uint256)
    {
        return ERC721A.totalSupply();
    }
}
