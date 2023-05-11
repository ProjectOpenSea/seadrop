// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    ISeaDropTokenContractMetadata
} from "./ISeaDropTokenContractMetadata.sol";

interface IERC1155ContractMetadata is ISeaDropTokenContractMetadata {
    /**
     * @dev The token does not exist.
     */
    error URIQueryForNonexistentToken();

    /**
     * @dev Emit an event when the max token supply for a token id is updated.
     */
    event MaxSupplyUpdated(uint256 tokenId, uint256 newMaxSupply);

    /**
     * @dev Emit an event if the user has insufficient balance for a token id.
     *
     * @param tokenId The token id the user has insufficient balance for.
     */
    event InsufficientBalance(uint256 tokenId);

    /**
     * @dev Emit an event if the user is not authorized to interact with
     *      an addresses' tokens.
     */
    event NotAuthorized();

    /**
     * @notice Sets the max supply for a token id and emits an event.
     *
     * @param tokenId      The token id to set the max supply for.
     * @param newMaxSupply The new max supply to set.
     */
    function setMaxSupply(uint256 tokenId, uint256 newMaxSupply) external;

    /**
     * @notice Returns the max token supply for a token id.
     */
    function maxSupply(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the total supply for a token id.
     */
    function totalSupply(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Returns the total minted for a token id.
     */
    function totalMinted(uint256 tokenId) external view returns (uint256);
}
