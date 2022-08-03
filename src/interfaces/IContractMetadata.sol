// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IContractMetadata {
    event ContractURIUpdated(string newContractURI);

    event TokenURIUpdated(
        uint256 indexed startTokenId,
        uint256 indexed endTokenId
    );
    event BaseURIUpdated(string baseURI);

    function contractURI() external view returns (string memory);

    function setContractURI(string calldata newContractURI) external;

    function setBaseURI(string calldata tokenURI) external;

    function setBatchTokenURIs(
        uint256 startTokenId,
        uint256 endTokenId,
        string calldata tokenURI
    ) external;
}

interface IERC721ContractMetadata is IContractMetadata {
    event MaxSupplyUpdated(uint256 newMaxSupply);

    function maxSupply() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function provenanceHash() external view returns (bytes32);
}
