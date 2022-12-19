// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { IERC2981 } from "openzeppelin-contracts/interfaces/IERC2981.sol";

interface ISeaDropTokenContractMetadata is IERC2981 {
    /**
     * @notice Throw if the max supply exceeds uint64, a limit
     *         due to the storage of bit-packed variables in ERC721A.
     */
    error CannotExceedMaxSupplyOfUint64(uint256 newMaxSupply);

    /**
     * @dev Revert with an error when attempting to set the provenance
     *      hash after the mint has started.
     */
    error ProvenanceHashCannotBeSetAfterMintStarted();

    /**
     * @dev Revert if the royalty basis points is greater than 10_000.
     */
    error InvalidRoyaltyBasisPoints(uint256 basisPoints);

    /**
     * @dev Revert if the royalty address is being set to the zero address.
     */
    error RoyaltyAddressCannotBeZeroAddress(address wallet);

    /**
     * @dev Emit an event for full token metadata reveals/updates.
     *
     * @param baseURI The base URI.
     */
    event BaseURIUpdated(string baseURI);

    /**
     * @dev Emit an event when the URI for the collection-level metadata
     *      is updated.
     */
    event ContractURIUpdated(string newContractURI);

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
     * @dev Emit an event when the royalties address is updated.
     */
    event RoyaltyAddressUpdated(address wallet);

    /**
     * @dev Emit an event when the royalties basis points (out of 10_000)
     *      is updated.
     */
    event RoyaltyBasisPointsUpdated(uint256 bps);

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
     * @notice Sets the base URI for the token metadata and emits an event.
     *
     * @param tokenURI The new base URI to set.
     */
    function setBaseURI(string calldata tokenURI) external;

    /**
     * @notice Sets the contract URI for contract metadata.
     *
     * @param newContractURI The new contract URI.
     */
    function setContractURI(string calldata newContractURI) external;

    /**
     * @notice Sets the max supply and emits an event.
     *
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 newMaxSupply) external;

    /**
     * @notice Sets the provenance hash and emits an event.
     *
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it has not been
     *         modified after mint started.
     *
     *         This function will revert after the first item has been minted.
     *
     * @param newProvenanceHash The new provenance hash to set.
     */
    function setProvenanceHash(bytes32 newProvenanceHash) external;

    /**
     * @notice Sets the address to receive royalties.
     *
     * @param newWallet The new wallet address.
     */
    function setRoyaltyAddress(address newWallet) external;

    /**
     * @notice Sets the royalty basis points out of 10_000.
     *
     * @param newBps The value as an integer (e.g. 500 for 5%)
     */
    function setRoyaltyBasisPoints(uint256 newBps) external;

    /**
     * @notice Returns the base URI for token metadata.
     */
    function baseURI() external view returns (string memory);

    /**
     * @notice Returns the contract URI.
     */
    function contractURI() external view returns (string memory);

    /**
     * @notice Returns the max token supply.
     */
    function maxSupply() external view returns (uint256);

    /**
     * @notice Returns the provenance hash.
     *         The provenance hash is used for random reveals, which
     *         is a hash of the ordered metadata to show it is unmodified
     *         after mint has started.
     */
    function provenanceHash() external view returns (bytes32);

    /**
     * @notice Returns the address that receives royalties.
     */
    function royaltyAddress() external view returns (address);

    /**
     * @notice Returns the royalty basis points out of 10_000.
     */
    function royaltyBasisPoints() external view returns (uint256);
}
