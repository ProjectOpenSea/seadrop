// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { MaxMintable } from "utility-contracts/MaxMintable.sol";
import { DropEventsAndErrors } from "./DropEventsAndErrors.sol";
import { IERC721Drop } from "./interfaces/IERC721Drop.sol";
import {
    ERC721ContractMetadata,
    IERC721ContractMetadata
} from "./ERC721ContractMetadata.sol";
import { ERC721A } from "./token/ERC721A.sol";

contract ERC721Drop is
    ERC721ContractMetadata,
    MaxMintable,
    DropEventsAndErrors,
    IERC721Drop
{
    string public dropURI;
    address feeRecipient;
    PublicDrop publicDrop;

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
        address administrator,
        uint256 maxNumMintable
    )
        ERC721ContractMetadata(name, symbol, administrator)
        MaxMintable(maxNumMintable)
    {}

    function mint(uint256 numToMint) external payable {
        PublicDrop memory _publicDrop = publicDrop;
        require(block.timestamp >= _publicDrop.startTime, "Drop not started");
        require(block.timestamp <= _publicDrop.endTime, "Drop has ended");
        require(
            numToMint * _publicDrop.mintPrice == msg.value,
            "Incorrect Payment"
        );
        require(
            numToMint <= _publicDrop.maxNumberMinted,
            "Exceeds max number mintable"
        );

        _mint(msg.sender, numToMint);
    }

    function setPublicDrop(PublicDrop memory newPublicDrop) public {
        publicDrop = newPublicDrop;
        emit PublicDropUpdated(newPublicDrop);
    }

    function setDropURI(string memory newDropURI) public override onlyOwner {
        dropURI = newDropURI;
        emit DropURIUpdated(newDropURI);
    }

    function setFeeRecipient(address newFeeRecipient) public onlyAdministrator {
        feeRecipient = newFeeRecipient;
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

    function totalSupply()
        public
        view
        virtual
        override(ERC721ContractMetadata, IERC721ContractMetadata)
        returns (uint256)
    {
        return ERC721A.totalSupply();
    }

    function getPublicDrop()
        external
        view
        override
        returns (PublicDrop memory)
    {
        return publicDrop;
    }
}
