// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ISeaDropTokenContractMetadata {
    /**
     * @dev Emit an event when the max token supply is updated.
     */
    event MaxSupplyUpdated(uint256 newMaxSupply);

    /**
     * @dev Emit an event with the previous and new provenance hash after
     *      being updated.
     */
    event ProvenanceHashUpdated(bytes32 previousHash, bytes32 newHash);

    /**
     * @dev Emit an event when the URI for the collection-level metadata
     *      is updated.
     */
    event ContractURIUpdated(string newContractURI);

    /**
     * @dev Emit an event for partial reveals/updates.
     *      Batch update implementation should be left to contract.
     *
     * @param startTokenId The start token id.
     * @param endTokenId   The end token id.
     */
    event TokenURIUpdated(
        uint256 indexed startTokenId,
        uint256 indexed endTokenId
    );

    /**
     * @dev Emit an event for full token metadata reveals/updates.
     *
     * @param baseURI The base URI.
     */
    event BaseURIUpdated(string baseURI);

    /**
     * @notice Returns the contract URI.
     */
    function contractURI() external view returns (string memory);

    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI) external;

    /**
     * @notice Returns the base URI for token metadata.
     */
    function baseURI() external view returns (string memory);

    /**
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param tokenURI The new base URI to set.
     */
    function setBaseURI(string calldata tokenURI) external;

    /**
     * @notice Returns the max token supply.
     */
    function maxSupply() external view returns (uint256);

    /**
     * @notice Sets the max supply and emits an event.
     *
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 newMaxSupply) external;

    /**
     * @notice Returns the provenance hash.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     */
    function provenanceHash() external view returns (bytes32);

    /**
     * @notice Sets the provenance hash and emits an event.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     *         This function will revert after the first item has been minted.
     *
     * @param newProvenanceHash The new provenance hash to set.
     */
    function setProvenanceHash(bytes32 newProvenanceHash) external;

    /**
     * @dev Revert with an error when attempting to set the provenance
     *      hash after the mint has started.
     */
    error ProvenanceHashCannotBeSetAfterMintStarted();
}
