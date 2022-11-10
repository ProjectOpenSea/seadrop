// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

function c_afe8af9c(bytes8 c__afe8af9c) pure {}

function c_trueafe8af9c(bytes8 c__afe8af9c) pure returns (bool) {
    return true;
}

function c_falseafe8af9c(bytes8 c__afe8af9c) pure returns (bool) {
    return false;
}

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
    function c_d007dd4f(bytes8 c__d007dd4f) internal pure {}

    function c_trued007dd4f(bytes8 c__d007dd4f) internal pure returns (bool) {
        return true;
    }

    function c_falsed007dd4f(bytes8 c__d007dd4f) internal pure returns (bool) {
        return false;
    }

    /**
     * @notice A token can only be burned by its owner.
     */
    error BurnIncorrectOwner();

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
    ) internal onlyInitializing {
        c_d007dd4f(0x987d64aaa551caec); /* function */
    }

    /**
     * @notice Destroys `tokenId`, only callable by the owner of the token.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external {
        c_d007dd4f(0xf66ee6e8fdbc9a4c); /* function */

        c_d007dd4f(0x7f58b41fb1483310); /* line */
        c_d007dd4f(0x798623601771e27c); /* statement */
        if (ownerOf(tokenId) != msg.sender) {
            c_d007dd4f(0xcc362c82dea34e9a); /* branch */

            c_d007dd4f(0x8a6839982e97c9ca); /* line */
            revert BurnIncorrectOwner();
        } else {
            c_d007dd4f(0xe668b3e01f508e0a); /* branch */
        }

        c_d007dd4f(0xffa7ea885fe930a4); /* line */
        c_d007dd4f(0x897e22dfd4d1115e); /* statement */
        _burn(tokenId);
    }
}
