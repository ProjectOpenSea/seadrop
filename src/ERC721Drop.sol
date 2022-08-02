// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { DropEventsAndErrors } from "./DropEventsAndErrors.sol";
import { IERC721Drop } from "./interfaces/IERC721Drop.sol";
import {
    ERC721ContractMetadata,
    IERC721ContractMetadata
} from "./ERC721ContractMetadata.sol";
import { ERC721A } from "./token/ERC721A.sol";

contract ERC721Drop is
    ERC721ContractMetadata,
    DropEventsAndErrors,
    IERC721Drop
{
    string public dropURI;
    address feeRecipient;
    PublicDrop publicDrop;
    address public immutable saleToken;

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

    /**
     * @notice Modifier that checks numberToMint against maxPerTransaction and publicDrop.maxMintsPerWallet
     */
    modifier checkNumberToMint(
        uint256 numberToMint,
        uint256 maxPerTransaction
    ) {
        {
            if (numberToMint > maxPerTransaction) {
                revert AmountExceedsMaxPerTransaction(
                    numberToMint,
                    maxPerTransaction
                );
            }
            uint256 maxMintsPerWallet = publicDrop.maxMintsPerWallet;
            if (
                (numberToMint + _numberMinted(msg.sender) > maxMintsPerWallet)
            ) {
                revert AmountExceedsMaxPerWallet(
                    numberToMint + _numberMinted(msg.sender),
                    maxMintsPerWallet
                );
            }
        }
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        PublicDrop memory _publicDrop,
        address _saleToken
    ) ERC721ContractMetadata(name, symbol, administrator) {
        saleToken = _saleToken;
        publicDrop = _publicDrop;
    }

    function publicMint(uint256 numToMint) public payable {
        _publicMint(numToMint);
    }

    function publicMint(uint256, uint256 numToMint) public payable {
        _publicMint(numToMint);
    }

    // todo: see if solidity optimizes these SLOADs
    // todo: support ERC20
    function _publicMint(uint256 numToMint)
        internal
        isActive(publicDrop.startTime, publicDrop.endTime)
        checkNumberToMint(numToMint, publicDrop.maxMintsPerTransaction)
        includesCorrectPayment(numToMint, publicDrop.mintPrice)
    {
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
