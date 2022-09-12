// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ISeaDropTokenContractMetadata
} from "./interfaces/ISeaDropTokenContractMetadata.sol";

import { ERC721A } from "ERC721A/ERC721A.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

/**
 * @title  ERC721ContractMetadata
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721ContractMetadata is a token contract that extends ERC721A
 *         with additional metadata and ownership capabilities.
 */
contract ERC721ContractMetadata is
    ERC721A,
    TwoStepOwnable,
    ISeaDropTokenContractMetadata
{
    /// @notice Throw if the max supply exceeds uint64, a limit
    //          due to the storage of bit-packed variables in ERC721A.
    error CannotExceedMaxSupplyOfUint64(uint256 newMaxSupply);

    /// @notice Track the max supply.
    uint256 _maxSupply;

    /// @notice Track the base URI for token metadata.
    string _tokenBaseURI;

    /// @notice Track the contract URI for contract metadata.
    string _contractURI;

    /// @notice Track the provenance hash for guaranteeing metadata order
    ///         for random reveals.
    bytes32 _provenanceHash;

    /**
     * @notice Deploy the token contract with its name and symbol.
     */
    constructor(string memory name, string memory symbol)
        ERC721A(name, symbol)
    {}

    /**
     * @notice Returns the base URI for token metadata.
     */
    function baseURI() external view override returns (string memory) {
        return _baseURI();
    }

    /**
     * @notice Returns the contract URI for contract metadata.
     */
    function contractURI() external view override returns (string memory) {
        return _contractURI;
    }

    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI)
        external
        override
        onlyOwner
    {
        // Set the new contract URI.
        _contractURI = newContractURI;

        // Emit an event with the update.
        emit ContractURIUpdated(newContractURI);
    }

    /**
     * @notice Emit an event notifying metadata updates for
     *         a range of token ids.
     *
     * @param startTokenId The start token id.
     * @param endTokenId   The end token id.
     */
    function emitBatchTokenURIUpdated(uint256 startTokenId, uint256 endTokenId)
        external
        onlyOwner
    {
        // Emit an event with the update.
        emit TokenURIUpdated(startTokenId, endTokenId);
    }

    /**
     * @notice Returns the max token supply.
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @notice Returns the provenance hash.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     */
    function provenanceHash() external view override returns (bytes32) {
        return _provenanceHash;
    }

    /**
     * @notice Sets the provenance hash and emits an event.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     *         This function will revert after the first item has been minted.
     *
     * @param newProvenanceHash The new provenance hash to set.
     */
    function setProvenanceHash(bytes32 newProvenanceHash) external onlyOwner {
        // Revert if any items have been minted.
        if (_totalMinted() > 0) {
            revert ProvenanceHashCannotBeSetAfterMintStarted();
        }

        // Keep track of the old provenance hash for emitting with the event.
        bytes32 oldProvenanceHash = _provenanceHash;

        // Set the new provenance hash.
        _provenanceHash = newProvenanceHash;

        // Emit an event with the update.
        emit ProvenanceHashUpdated(oldProvenanceHash, newProvenanceHash);
    }

    /**
     * @notice Sets the max token supply and emits an event.
     *
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        // Ensure the max supply does not exceed the maximum value of uint64.
        if (newMaxSupply > 2**64 - 1) {
            revert CannotExceedMaxSupplyOfUint64(newMaxSupply);
        }

        // Set the new max supply.
        _maxSupply = newMaxSupply;

        // Emit an event with the update.
        emit MaxSupplyUpdated(newMaxSupply);
    }

    /**
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param newBaseURI The new base URI to set.
     */
    function setBaseURI(string calldata newBaseURI)
        external
        override
        onlyOwner
    {
        // Set the new base URI.
        _tokenBaseURI = newBaseURI;

        // Emit an event with the update.
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @notice Returns the base URI for the contract, which ERC721A uses
     *         to return tokenURI.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _tokenBaseURI;
    }
}
