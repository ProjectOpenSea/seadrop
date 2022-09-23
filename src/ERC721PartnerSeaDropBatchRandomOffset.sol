// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721PartnerSeaDrop } from "./ERC721PartnerSeaDrop.sol";

import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title  ERC721PartnerSeaDropBatchRandomOffset
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerSeaDropBatchRandomOffset is a token contract that extends
 *         ERC721PartnerSeaDrop a apply a randomOffset to the tokenURI,
 *         to enable fair metadata reveals.
 */
contract ERC721PartnerSeaDropBatchRandomOffset is ERC721PartnerSeaDrop {
    BatchOffset[] public batchOffsets;
    uint64 constant MIN_BATCH_SIZE = 1000;
    string public defaultURI;

    struct BatchOffset {
        uint64 inclusiveStartId;
        uint64 exclusiveEndId;
        uint64 randomOffset;
    }

    error BatchSizeTooSmall(uint64 batchSize);
    error AllBatchesRevealed();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop,
        string memory _defaultURI
    ) ERC721PartnerSeaDrop(name, symbol, administrator, allowedSeaDrop) {
        defaultURI = _defaultURI;
    }

    function setDefaultURI(string memory _defaultURI) external onlyOwner {
        defaultURI = _defaultURI;
    }

    /**
     * @notice Set the random offset, for a fair metadata reveal. Only callable
     *         by the owner one time when the total number of minted tokens
     *         equals the max supply. Should be called at the time of reveal.
     *         of reveal after secondary market trading pre-reveal.
     */
    function revealBatch() external onlyOwner {
        BatchOffset[] storage offsets = batchOffsets;
        uint256 inclusiveStartId;
        if (offsets.length == 0) {
            inclusiveStartId = _startTokenId();
        } else {
            BatchOffset memory batchOffset = batchOffsets[
                batchOffsets.length - 1
            ];
            // start tokenid of next batch is exclusive end tokenid of previous batch
            inclusiveStartId = batchOffset.exclusiveEndId;
            // check if all batches have been revealed
            if (batchOffset.exclusiveEndId == _maxSupply + _startTokenId()) {
                revert AllBatchesRevealed();
            }
        }
        uint256 exclusiveEndId = _nextTokenId();

        // validate batch size
        uint256 batchSize = exclusiveEndId - inclusiveStartId;
        if (batchSize < MIN_BATCH_SIZE) {
            revert BatchSizeTooSmall(uint64(batchSize));
        }

        uint64 randomOffset = uint64(block.difficulty % batchSize);
        offsets.push(
            BatchOffset(
                // These are limited to 64-bits by our supply checks for ERC721A
                uint64(inclusiveStartId),
                uint64(exclusiveEndId),
                randomOffset
            )
        );
    }

    /**
     * @notice The token URI, offset by randomOffset, to enable fair metadata
     *         reveals.
     *
     * @param tokenId The token id
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) {
            revert URIQueryForNonexistentToken();
        }
        BatchOffset[] storage offsets = batchOffsets;
        bool revealed;
        if (offsets.length == 0) {
            revealed = false;
        } else {
            BatchOffset memory batchOffset = offsets[offsets.length - 1];
            revealed = tokenId < batchOffset.exclusiveEndId;
        }

        string memory base = _baseURI();
        if (bytes(base).length == 0) {
            // If there is no baseURI set, return an empty string.
            return "";
        } else if (revealed) {
            for (uint256 i = 0; i < offsets.length; i++) {
                BatchOffset memory batchOffset = offsets[i];
                if (
                    tokenId >= batchOffset.inclusiveStartId &&
                    tokenId < batchOffset.exclusiveEndId
                ) {
                    uint256 batchSize = batchOffset.exclusiveEndId -
                        batchOffset.inclusiveStartId;
                    // add random offset to (tokenId - inclusiveStartId)
                    // mod batchSize to get its new offset from batch start
                    uint256 tokenOffsetFromBatchStart = ((tokenId -
                        batchOffset.inclusiveStartId) +
                        batchOffset.randomOffset) % batchSize;
                    // add tokenOffsetFromBatchStart to inclusiveStartId to get new tokenId
                    uint256 offsetTokenId = tokenOffsetFromBatchStart +
                        batchOffset.inclusiveStartId;
                    return
                        string.concat(
                            base,
                            "/",
                            Strings.toString(offsetTokenId)
                        );
                }
            }
        }
        return defaultURI;
    }
}
