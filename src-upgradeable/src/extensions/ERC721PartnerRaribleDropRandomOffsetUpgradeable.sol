// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721PartnerRaribleDropUpgradeable
} from "../ERC721PartnerRaribleDropUpgradeable.sol";
import {
    ERC721PartnerRaribleDropRandomOffsetStorage
} from "./ERC721PartnerRaribleDropRandomOffsetStorage.sol";
import {
    ERC721ContractMetadataStorage
} from "../ERC721ContractMetadataStorage.sol";

/**
 * @title  ERC721PartnerRaribleDropRandomOffset
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerRaribleDropRandomOffset is a token contract that extends
 *         ERC721PartnerRaribleDrop to apply a randomOffset to the tokenURI,
 *         to enable fair metadata reveals.
 */
contract ERC721PartnerRaribleDropRandomOffsetUpgradeable is
    ERC721PartnerRaribleDropUpgradeable
{
    using ERC721PartnerRaribleDropRandomOffsetStorage for ERC721PartnerRaribleDropRandomOffsetStorage.Layout;
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage.Layout;

    /// @notice Revert when setting the randomOffset if already set.
    error AlreadyRevealed();

    /// @notice Revert when setting the randomOffset if the collection is
    ///         not yet fully minted.
    error NotFullyMinted();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed RaribleDrop addresses.
     */
    function __ERC721PartnerRaribleDropRandomOffset_init(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedRaribleDrop
    ) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
        __ReentrancyGuard_init_unchained();
        __ERC721RaribleDrop_init_unchained(name, symbol, allowedRaribleDrop);
        __TwoStepAdministered_init_unchained(administrator);
        __ERC721PartnerRaribleDrop_init_unchained(
            name,
            symbol,
            administrator,
            allowedRaribleDrop
        );
        __ERC721PartnerRaribleDropRandomOffset_init_unchained(
            name,
            symbol,
            administrator,
            allowedRaribleDrop
        );
    }

    function __ERC721PartnerRaribleDropRandomOffset_init_unchained(
        string memory,
        string memory,
        address,
        address[] memory
    ) internal onlyInitializing {}

    /**
     * @notice Set the random offset, for a fair metadata reveal. Only callable
     *         by the owner one time when the total number of minted tokens
     *         equals the max supply. Should be called immediately before
     *         reveal.
     */
    function setRandomOffset() external onlyOwner {
        if (ERC721PartnerRaribleDropRandomOffsetStorage.layout().revealed) {
            revert AlreadyRevealed();
        }

        if (
            _totalMinted() != ERC721ContractMetadataStorage.layout()._maxSupply
        ) {
            revert NotFullyMinted();
        }
        // block.difficulty returns PREVRANDAO on Ethereum post-merge
        // NOTE: do not use this on other chains
        // randomOffset returns between 1 and MAX_SUPPLY
        ERC721PartnerRaribleDropRandomOffsetStorage.layout().randomOffset =
            (uint256(keccak256(abi.encode(block.difficulty))) %
                (ERC721ContractMetadataStorage.layout()._maxSupply - 1)) +
            1;

        ERC721PartnerRaribleDropRandomOffsetStorage.layout().revealed = true;
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
            if (!ERC721PartnerRaribleDropRandomOffsetStorage.layout().revealed) {
                // If the baseURI is set but the collection is not revealed yet,
                // return just the baseURI.
                return base;
            } else {
                // If the baseURI is set and the collection is revealed,
                // return the tokenURI offset by the randomOffset.
                return
                    string.concat(
                        base,
                        _toString(
                            ((tokenId +
                                ERC721PartnerRaribleDropRandomOffsetStorage
                                    .layout()
                                    .randomOffset) %
                                ERC721ContractMetadataStorage
                                    .layout()
                                    ._maxSupply) + _startTokenId()
                        )
                    );
            }
        }
    }

    function randomOffset() public view returns (uint256) {
        return ERC721PartnerRaribleDropRandomOffsetStorage.layout().randomOffset;
    }

    function revealed() public view returns (bool) {
        return ERC721PartnerRaribleDropRandomOffsetStorage.layout().revealed;
    }
}
