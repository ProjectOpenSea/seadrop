// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {
    IERC721SeaDrop,
    IERC721ContractMetadata
} from "./droplet/IERC721SeaDrop.sol";
import {
    ERC721ContractMetadata,
    IERC721ContractMetadata
} from "./ERC721ContractMetadata.sol";

import { ERC721A } from "./token/ERC721A.sol";

import { TwoStepAdministered } from "utility-contracts/TwoStepAdministered.sol";

import { SeaDrop } from "./droplet/SeaDrop.sol";

import { ISeaDrop } from "./droplet/ISeaDrop.sol";

import { SeaDropErrorsAndEvents } from "./droplet/SeaDropErrorsAndEvents.sol";
import { PublicDrop, AllowListData } from "./droplet/SeaDropStructs.sol";

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
        _mint(minter, amount);
    }

    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        virtual
        override
        onlyOwner
    {
        PublicDrop memory retrieved = _SEADROP.publicDrops(address(this));
        PublicDrop memory supplied = publicDrop;
        supplied.feeBps = retrieved.feeBps;
        _SEADROP.updatePublicDrop(supplied);
    }

    function updatePublicDropFee(uint16 feeBps)
        external
        virtual
        onlyAdministrator
    {
        PublicDrop memory retrieved = _SEADROP.publicDrops(address(this));
        retrieved.feeBps = feeBps;
        _SEADROP.updatePublicDrop(retrieved);
    }

    function updateAllowList(AllowListData calldata allowListData)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        _SEADROP.updateAllowList(allowListData);
    }

    function updateSaleToken(address saleToken)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        _SEADROP.updateSaleToken(saleToken);
    }

    function updateDropURI(string calldata dropURI)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        _SEADROP.updateDropURI(dropURI);
    }

    function numberMinted(address minter) external view returns (uint256) {
        return _numberMinted(minter);
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

    function getSeaDrop() external view override returns (address) {
        return address(_SEADROP);
    }
}
