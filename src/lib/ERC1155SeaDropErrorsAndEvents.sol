// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { PublicDrop } from "./ERC1155SeaDropStructs.sol";

import { SeaDropErrorsAndEvents } from "./SeaDropErrorsAndEvents.sol";

interface ERC1155SeaDropErrorsAndEvents is SeaDropErrorsAndEvents {
    /**
     * @dev Revert with an error if an empty PublicDrop is provided
     *      for an already-empty public drop.
     */
    error PublicDropStageNotPresent();

    /**
     * @dev Revert with an error if the mint quantity exceeds the
     *      max minted per wallet for a certain token id.
     */
    error MintQuantityExceedsMaxMintedPerWalletForTokenId(
        uint256 tokenId,
        uint256 total,
        uint256 allowed
    );

    /**
     * @dev Revert with an error if the target token id to mint is not within
     *      the drop stage range.
     */
    error TokenIdNotWithinDropStageRange(
        uint256 tokenId,
        uint256 startTokenId,
        uint256 endTokenId
    );

    /**
     *  @notice Revert with an error if the number of maxSupplyAmounts doesn't
     *          match the number of maxSupplyTokenIds.
     */
    error MaxSupplyMismatch();

    /**
     * @notice Revert with an error if the mint order offer contains
     *         a duplicate tokenId.
     */
    error OfferContainsDuplicateTokenId(uint256 tokenId);

    /**
     * @dev Revert if the fromTokenId is greater than the toTokenId.
     */
    error InvalidFromAndToTokenId(uint256 fromTokenId, uint256 toTokenId);

    /**
     *  @notice Revert with an error if the number of publicDropIndexes doesn't
     *          match the number of publicDrops.
     */
    error PublicDropsMismatch();

    /**
     * @dev An event with updated public drop data.
     */
    event PublicDropUpdated(PublicDrop publicDrop, uint256 index);
}
