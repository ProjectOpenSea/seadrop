// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

/**
 * @title  ISeaDropTokenV3
 * @notice The one interface SeaDropMinter calls on a v3 token, for ERC-721
 *         and ERC-1155 alike. Tokens advertise it through ERC-165.
 */
interface ISeaDropTokenV3 {
    /**
     * @notice Mint tokens. Only minters the token's owner allowed can call
     *         this. The token enforces its own max supply.
     *
     * @param to       The address that receives the tokens.
     * @param id       The token id. ERC-721 tokens ignore it.
     * @param quantity The number of tokens to mint.
     */
    function mintSeaDrop(address to, uint256 id, uint256 quantity) external;

    /**
     * @notice The number of tokens minted so far and the max supply.
     *
     * @param id The token id. ERC-721 tokens ignore it.
     */
    function mintStats(uint256 id)
        external
        view
        returns (uint256 totalMinted, uint256 maxSupply);
}
