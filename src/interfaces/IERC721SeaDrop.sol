// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISeaDropToken } from "./ISeaDropToken.sol";

import { PublicDrop } from "../lib/ERC721SeaDropStructs.sol";

/**
 * @dev A helper interface to get and set parameters for ERC721SeaDrop.
 *      The token does not expose these methods as part of its external
 *      interface to optimize contract size, but does implement them.
 */
interface IERC721SeaDrop is ISeaDropToken {
    /**
     * @notice Update the SeaDrop public drop parameters.
     *
     * @param publicDrop The new public drop parameters.
     */
    function updatePublicDrop(PublicDrop calldata publicDrop) external;

    /**
     * @notice Returns the public drop stage parameters.
     */
    function getPublicDrop() external view returns (PublicDrop memory);

    /**
     * @notice Returns a set of mint stats for the address.
     *         This assists SeaDrop in enforcing maxSupply,
     *         maxTotalMintableByWallet, and maxTokenSupplyForStage checks.
     *
     * @dev    NOTE: Implementing contracts should always update these numbers
     *         before transferring any tokens with _safeMint() to mitigate
     *         consequences of malicious onERC721Received() hooks.
     *
     * @param minter The minter address.
     */
    function getMintStats(
        address minter
    )
        external
        view
        returns (
            uint256 minterNumMinted,
            uint256 totalMinted,
            uint256 maxSupply
        );
}
