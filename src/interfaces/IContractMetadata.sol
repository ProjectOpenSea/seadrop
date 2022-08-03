// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IContractMetadata {}

interface IERC721ContractMetadata is IContractMetadata {
    // just in case?
    event MaxSupplyUpdated(uint256 newMaxSupply);

    // just in case?
    event ProvenanceHashUpdated(bytes32 previousHash, bytes32 newHash);

    // for collection-level metadata
    event ContractURIUpdated(string newContractURI);

    // for partial reveals/updates - batch update implementation should be left to contract
    event TokenURIUpdated(
        uint256 indexed startTokenId,
        uint256 indexed endTokenId
    );

    // for full reveals/updates
    event BaseURIUpdated(string baseURI);

    function contractURI() external view returns (string memory);

    function setContractURI(string calldata newContractURI) external;

    function setBaseURI(string calldata tokenURI) external;

    function maxSupply() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    // for random reveals, hash all metadata and store result here
    function provenanceHash() external view returns (bytes32);
}
