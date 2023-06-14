// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721PartnerRaribleDropUpgradeable
} from "../ERC721PartnerRaribleDropUpgradeable.sol";

/**
 * @title  ERC721PartnerRaribleDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerRaribleDropBurnable is a token contract that extends
 *         ERC721PartnerRaribleDrop to additionally provide a burn function.
 */
contract ERC721PartnerRaribleDropBurnableUpgradeable is
    ERC721PartnerRaribleDropUpgradeable
{
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed RaribleDrop addresses.
     */
    function __ERC721PartnerRaribleDropBurnable_init(
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
        __ERC721PartnerRaribleDropBurnable_init_unchained(
            name,
            symbol,
            administrator,
            allowedRaribleDrop
        );
    }

    function __ERC721PartnerRaribleDropBurnable_init_unchained(
        string memory,
        string memory,
        address,
        address[] memory
    ) internal onlyInitializing {}

    /**
     * @notice Burns `tokenId`. The caller must own `tokenId` or be an
     *         approved operator.
     *
     * @param tokenId The token id to burn.
     */
    // solhint-disable-next-line comprehensive-interface
    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }
}
