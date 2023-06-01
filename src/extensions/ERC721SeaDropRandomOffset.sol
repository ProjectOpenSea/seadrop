// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

/**
 * @title  ERC721SeaDropRandomOffset
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @author Michael Cohen (notmichael.eth)
 * @notice ERC721SeaDropRandomOffset is a token contract that extends
 *         ERC721SeaDrop to apply a randomOffset to the tokenURI,
 *         to enable fair metadata reveals.
 */
contract ERC721SeaDropRandomOffset is ERC721SeaDrop {
    /// @notice The random offset, between 1 and the MAX_SUPPLY at the time of
    ///         being set.
    uint256 public randomOffset;

    /// @notice If the collection has been revealed and the randomOffset has
    ///         been set. 1=False, 2=True.
    uint256 public revealed = _REVEALED_FALSE;

    /// @dev For gas efficiency, uint is used instead of bool for revealed.
    uint256 private constant _REVEALED_FALSE = 1;
    uint256 private constant _REVEALED_TRUE = 2;

    /// @notice Revert when setting the randomOffset if already set.
    error AlreadyRevealed();

    /// @notice Revert when setting the randomOffset if the collection is
    ///         not yet fully minted.
    error NotFullyMinted();

    /**
     * @notice Deploy the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters. Also contains SeaDrop
     *                          implementation code.
     * @param allowedConduit    The address of the conduit contract allowed to
     *                          interact.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name              The name of the token.
     * @param symbol            The symbol of the token.
     */
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        address allowedConduit,
        string memory name,
        string memory symbol
    )
        ERC721SeaDrop(
            allowedConfigurer,
            allowedConduit,
            allowedSeaport,
            name,
            symbol
        )
    {}

    /**
     * @notice Set the random offset, for a fair metadata reveal. Only callable
     *         by the owner one time when the total number of minted tokens
     *         equals the max supply. Should be called immediately before
     *         reveal.
     */
    // solhint-disable-next-line comprehensive-interface
    function setRandomOffset() external {
        // Ensure the sender is only the owner or configurer contract.
        _onlyOwnerOrConfigurer();

        // Revert setting the offset if already revealed.
        if (revealed == _REVEALED_TRUE) {
            revert AlreadyRevealed();
        }

        // Put maxSupply on the stack, since reading a state variable
        // costs more gas than reading a local variable.
        uint256 maxSupply = _maxSupply;

        // Revert if the collection is not yet fully minted.
        if (_totalMinted() != maxSupply) {
            revert NotFullyMinted();
        }

        // block.difficulty returns PREVRANDAO on Ethereum post-merge
        // NOTE: do not use this on other chains
        // randomOffset returns between 1 and MAX_SUPPLY
        randomOffset =
            (uint256(keccak256(abi.encode(block.prevrandao))) %
                (maxSupply - 1)) +
            1;

        // Set revealed to true.
        revealed = _REVEALED_TRUE;

        // Emit an event with the update.
        emit BatchMetadataUpdate(1, _nextTokenId() - 1);
    }

    /**
     * @notice The token URI, offset by randomOffset, to enable fair metadata
     *         reveals.
     *
     * @param tokenId The token id
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        if (!_exists(tokenId)) {
            revert URIQueryForNonexistentToken();
        }

        string memory base = _baseURI();
        if (bytes(base).length == 0) {
            // If there is no baseURI set, return an empty string.
            return "";
        } else if (revealed == _REVEALED_FALSE) {
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
                        ((tokenId + randomOffset) % _maxSupply) +
                            _startTokenId()
                    )
                );
        }
    }
}
