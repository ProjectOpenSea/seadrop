// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721SeaDropUpgradeable } from "../ERC721SeaDropUpgradeable.sol";

/**
 * @title  ERC721SeaDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721SeaDropBurnable is a token contract that extends
 *         ERC721SeaDrop to additionally provide a burn function.
 */
contract ERC721SeaDropBurnableUpgradeable is ERC721SeaDropUpgradeable {
    /**
     * @notice Deploy the token contract with its name, symbol,
     *         and allowed SeaDrop addresses.
     */
    function __ERC721SeaDropBurnable_init(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) internal onlyInitializing {
        __ERC721A_init_unchained(name, symbol);
        __ConstructorInitializable_init_unchained();
        __TwoStepOwnable_init_unchained();
        __ERC721ContractMetadata_init_unchained(name, symbol);
        __ReentrancyGuard_init_unchained();
        __ERC721SeaDrop_init_unchained(name, symbol, allowedSeaDrop);
        __ERC721SeaDrop_init_unchained(name, symbol, allowedSeaDrop);
        __ERC721SeaDropBurnable_init_unchained(name, symbol, allowedSeaDrop);
    }

    function __ERC721SeaDropBurnable_init_unchained(
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
