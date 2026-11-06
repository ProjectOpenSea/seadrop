// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDropUpgradeable } from "../ERC721SeaDropUpgradeable.sol";
import {
    ERC721SeaDropRandomOffsetStorage
} from "./ERC721SeaDropRandomOffsetStorage.sol";
import {
    ERC721ContractMetadataStorage
} from "../ERC721ContractMetadataStorage.sol";

/**
 * @title  ERC721SeaDropRandomOffset
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721SeaDropRandomOffset is a token contract that extends
 *         ERC721SeaDrop to apply a randomOffset to the tokenURI,
 *         to enable fair metadata reveals.
 */
contract ERC721SeaDropRandomOffsetUpgradeable is ERC721SeaDropUpgradeable {
    using ERC721SeaDropRandomOffsetStorage for ERC721SeaDropRandomOffsetStorage
        .Layout;
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage
        .Layout;

    /// @notice Revert when setting the randomOffset if already set.
    error AlreadyRevealed();

    /// @notice Revert when setting the randomOffset if the collection is
    ///         not yet fully minted.
    error NotFullyMinted();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    function __ERC721SeaDropRandomOffset_init(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) internal onlyInitializing {
        __ERC721SeaDrop_init(name, symbol, allowedSeaDrop);
    }

    /**
     * @notice Set the random offset, for a fair metadata reveal. Only callable
     *         by the owner one time when the total number of minted tokens
     *         equals the max supply. Should be called immediately before
     *         reveal.
     */
    function setRandomOffset() external onlyOwner {
        if (ERC721SeaDropRandomOffsetStorage.layout().revealed) {
            revert AlreadyRevealed();
        }

        uint256 maxSupply = ERC721ContractMetadataStorage.layout()._maxSupply;

        // Revert if the collection is not yet fully minted, or has no
        // tokens to reveal.
        if (maxSupply == 0 || _totalMinted() != maxSupply) {
            revert NotFullyMinted();
        }

        // tokenURI shifts each token's metadata id by randomOffset + 1
        // (mod maxSupply), so randomOffset = maxSupply - 1 would leave every
        // token on its own metadata. Draw randomOffset from
        // [0, maxSupply - 2] so the shift is uniform over the maxSupply - 1
        // shifts that move every token. A single token can only keep its
        // own metadata.
        // block.difficulty returns PREVRANDAO on Ethereum post-merge
        // NOTE: do not use this on other chains
        if (maxSupply > 1) {
            ERC721SeaDropRandomOffsetStorage.layout().randomOffset = uint256(
                keccak256(abi.encode(block.difficulty))
            ) % (maxSupply - 1);
        }

        ERC721SeaDropRandomOffsetStorage.layout().revealed = true;

        // Emit an event for the reveal, which moves every token's metadata.
        emit BatchMetadataUpdate(_startTokenId(), _nextTokenId() - 1);
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

        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            // If there is no baseURI set, return an empty string.
            return "";
        } else {
            if (!ERC721SeaDropRandomOffsetStorage.layout().revealed) {
                // If the baseURI is set but the collection is not revealed yet,
                // return just the baseURI.
                return base;
            } else {
                // If the baseURI is set and the collection is revealed,
                // return the tokenURI offset by the randomOffset.
                return string.concat(
                    base,
                    _toString(
                        ((tokenId
                                    + ERC721SeaDropRandomOffsetStorage.layout()
                                    .randomOffset)
                                % ERC721ContractMetadataStorage.layout()
                                ._maxSupply) + _startTokenId()
                    )
                );
            }
        }
    }

    function randomOffset() public view returns (uint256) {
        return ERC721SeaDropRandomOffsetStorage.layout().randomOffset;
    }

    function revealed() public view returns (bool) {
        return ERC721SeaDropRandomOffsetStorage.layout().revealed;
    }
}
