// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

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
    /// @notice The random offset, between 0 and maxSupply - 2 at the time of
    ///         being set (0 when maxSupply is 1). tokenURI shifts each token's
    ///         metadata id by randomOffset + 1.
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
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) { }

    /**
     * @notice Set the random offset, for a fair metadata reveal. Only callable
     *         by the owner one time when the total number of minted tokens
     *         equals the max supply. Should be called immediately before
     *         reveal.
     */
    // solhint-disable-next-line comprehensive-interface
    function setRandomOffset() external onlyOwner {
        // Revert setting the offset if already revealed.
        if (revealed == _REVEALED_TRUE) {
            revert AlreadyRevealed();
        }

        // Put maxSupply on the stack, since reading a state variable
        // costs more gas than reading a local variable.
        uint256 maxSupply = _maxSupply;

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
            randomOffset = uint256(keccak256(abi.encode(block.difficulty)))
                % (maxSupply - 1);
        }

        // Set revealed to true.
        revealed = _REVEALED_TRUE;

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
        } else if (revealed == _REVEALED_FALSE) {
            // If the baseURI is set but the collection is not revealed yet,
            // return just the baseURI.
            return base;
        } else {
            // If the baseURI is set and the collection is revealed,
            // return the tokenURI offset by the randomOffset.
            return string.concat(
                base,
                _toString(
                    ((tokenId + randomOffset) % _maxSupply) + _startTokenId()
                )
            );
        }
    }
}
