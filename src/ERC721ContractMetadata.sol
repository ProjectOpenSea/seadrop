// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import { ERC721A } from "./token/ERC721A.sol";
import { MaxMintable } from "utility-contracts/MaxMintable.sol";
import { DropEventsAndErrors } from "./DropEventsAndErrors.sol";
import {
    TwoStepAdministered,
    TwoStepOwnable
} from "utility-contracts/TwoStepAdministered.sol";
import { AllowList } from "utility-contracts/AllowList.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {
    ECDSA
} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {
    ConstructorInitializable
} from "utility-contracts/ConstructorInitializable.sol";
import {
    IERC721ContractMetadata
} from "./interfaces/IERC721ContractMetadata.sol";

contract ERC721ContractMetadata is
    ERC721A,
    TwoStepAdministered,
    IERC721ContractMetadata
{
    uint256 _maxSupply;
    string baseURI;
    bytes32 _provenanceHash;

    constructor(
        string memory name,
        string memory symbol,
        address administrator
    ) ERC721A(name, symbol) TwoStepAdministered(administrator) {}

    // IContractMetadata
    function contractURI() external pure override returns (string memory) {
        return "";
    }

    function setContractURI(string calldata newContractURI) external override {
        emit ContractURIUpdated(newContractURI);
    }

    function setBatchTokenURIs(
        uint256 startTokenId,
        uint256 endTokenId,
        string calldata
    ) external {
        emit TokenURIUpdated(startTokenId, endTokenId);
    }

    function maxSupply() external view returns (uint256) {
        return _maxSupply;
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        _maxSupply = newMaxSupply;
    }

    function setBaseURI(string calldata newBaseURI) external override {
        baseURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function totalSupply()
        public
        view
        virtual
        override(ERC721A, IERC721ContractMetadata)
        returns (uint256)
    {
        return ERC721A.totalSupply();
    }

    function provenanceHash() external view override returns (bytes32) {
        return _provenanceHash;
    }
}
