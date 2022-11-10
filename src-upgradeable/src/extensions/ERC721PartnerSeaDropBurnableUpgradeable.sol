// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {
    ERC721PartnerSeaDropUpgradeable
} from "../ERC721PartnerSeaDropUpgradeable.sol";

/**
 * @title  ERC721PartnerSeaDropBurnable
 * @author James Wenzel (emo.eth)
 * @author Ryan Ghods (ralxz.eth)
 * @author Stephan Min (stephanm.eth)
 * @notice ERC721PartnerSeaDropBurnable is a token contract that extends
 *         ERC721PartnerSeaDrop to additionally provide a burn function.
 */
contract ERC721PartnerSeaDropBurnableUpgradeable is
    ERC721PartnerSeaDropUpgradeable
{
    /**
     * @notice A token can only be burned by its owner or approved address.
     */
    error BurnNotOwnerOrApproved();

    /**
     * @notice Deploy the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    function __ERC721PartnerSeaDropBurnable_init(
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
        __ERC721PartnerSeaDropBurnable_init_unchained(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        );
    }

    function __ERC721PartnerSeaDropBurnable_init_unchained(
        string memory,
        string memory,
        address,
        address[] memory
    ) internal onlyInitializing {}

    /**
     * @notice Destroys `tokenId`, only callable by the owner of the token.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (owner != _msgSenderERC721A()) {
            if (
                !isApprovedForAll(owner, _msgSenderERC721A()) &&
                getApproved(tokenId) != _msgSenderERC721A()
            ) {
                revert BurnNotOwnerOrApproved();
            }
        }

        _burn(tokenId);
    }
}
