// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { IERC721SeaDrop } from "./droplet/IERC721SeaDrop.sol";

import { ERC721A } from "./token/ERC721A.sol";

import { TwoStepAdministered } from "utility-contracts/TwoStepAdministered.sol";

import { SeaDrop } from "./droplet/SeaDrop.sol";

import { ISeaDrop } from "./droplet/ISeaDrop.sol";

import { SeaDropErrorsAndEvents } from "./droplet/SeaDropErrorsAndEvents.sol";

contract ERC721SeaDrop is ERC721A, TwoStepAdministered, IERC721SeaDrop {
    ISeaDrop internal immutable _SEADROP;

    constructor(
        string memory name,
        string memory symbol,
        address seadrop
    ) ERC721A(name, symbol) {
        _SEADROP = ISeaDrop(seadrop);
    }

    modifier onlySeaDrop() {
        if (msg.sender != address(_SEADROP)) {
            revert OnlySeaDrop();
        }
    }

    function mintSeaDrop(uint256 minter, uint256 amount)
        external
        payable
        onlySeaDrop
    {}

    function updatePublicDrop(PublicDrop calldata publicDrop)
        external
        virtual
        override
        onlyOwnerOrAdministrator
    {
        _SEADROP.updatePublicDrop(publicDrop);
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
        onlyOwnerOrAdminstrator
    {
        _SEADROP.updateSaleToken(saleToken);
    }

    function updateDropURI(string calldata dropURI)
        external
        virtual
        override
        onlyOwnerOrAdminstrator
    {
        _SEADROP.updateDropURI(dropURI);
    }

    function numberMinted(address minter) external view returns (uint256) {
        return _numberMinted(minter);
    }
}
