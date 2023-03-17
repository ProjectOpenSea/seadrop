// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ERC721PartnerSeaDropUpgradeable
} from "../ERC721PartnerSeaDropUpgradeable.sol";
import {
    ERC721PartnerSeaDropRandomOffsetStorage
} from "./ERC721PartnerSeaDropRandomOffsetStorage.sol";
import {
    ERC721ContractMetadataStorage
} from "../ERC721ContractMetadataStorage.sol";

/**
 * @title  ERC721PartnerSeaDropRandomOffset
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerSeaDropRandomOffset is a token contract that extends
 *         ERC721PartnerSeaDrop to apply a randomOffset to the tokenURI,
 *         to enable fair metadata reveals.
 */
contract ERC721PartnerSeaDropRandomOffsetUpgradeable is
    ERC721PartnerSeaDropUpgradeable
{
    using ERC721PartnerSeaDropRandomOffsetStorage for ERC721PartnerSeaDropRandomOffsetStorage.Layout;
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage.Layout;

    /// @notice Revert when setting the randomOffset if already set.
    error AlreadyRevealed();

    /// @notice Revert when setting the randomOffset if the collection is
    ///         not yet fully minted.
    error NotFullyMinted();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    function __ERC721PartnerSeaDropRandomOffset_init(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
        __ReentrancyGuard_init_unchained();
        __ERC721SeaDrop_init_unchained(name, symbol, allowedSeaDrop);
        __TwoStepAdministered_init_unchained(administrator);
        __ERC721PartnerSeaDrop_init_unchained(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        );
        __ERC721PartnerSeaDropRandomOffset_init_unchained(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        );
    }

    function __ERC721PartnerSeaDropRandomOffset_init_unchained(
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
        if (ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed) {
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
        ERC721PartnerSeaDropRandomOffsetStorage.layout().randomOffset =
            (uint256(keccak256(abi.encode(block.difficulty))) %
                (ERC721ContractMetadataStorage.layout()._maxSupply - 1)) +
            1;

        ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed = true;
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
            if (!ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed) {
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
                                ERC721PartnerSeaDropRandomOffsetStorage
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
        return ERC721PartnerSeaDropRandomOffsetStorage.layout().randomOffset;
    }

    function revealed() public view returns (bool) {
        return ERC721PartnerSeaDropRandomOffsetStorage.layout().revealed;
    }
}
