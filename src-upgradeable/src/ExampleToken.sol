// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ERC721PartnerSeaDropUpgradeable
} from "./ERC721PartnerSeaDropUpgradeable.sol";

library ExampleTokenStorage {
    struct Layout {
        /// @notice The only address that can burn tokens on this contract.
        address burnAddress;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256("seaDrop.contracts.storage.exampleToken");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

/*
 * @notice This contract uses ERC721PartnerSeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 *         The set burn address is the only sender that can burn tokens.
 */
contract ExampleToken is ERC721PartnerSeaDropUpgradeable {
    using ExampleTokenStorage for ExampleTokenStorage.Layout;

    /**
     * @notice A token can only be burned by the set burn address.
     */
    error BurnIncorrectSender();

    /**
     * @notice Initialize the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    function initialize(
        string memory name,
        string memory symbol,
        address administrator,
        address[] memory allowedSeaDrop
    ) external initializer initializerERC721A {
        ERC721PartnerSeaDropUpgradeable.__ERC721PartnerSeaDrop_init(
            name,
            symbol,
            administrator,
            allowedSeaDrop
        );
    }

    function setBurnAddress(address newBurnAddress) external onlyOwner {
        ExampleTokenStorage.layout().burnAddress = newBurnAddress;
    }

    function getBurnAddress() public view returns (address) {
        return ExampleTokenStorage.layout().burnAddress;
    }

    /**
     * @notice Destroys `tokenId`, only callable by the set burn address.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external {
        if (msg.sender != ExampleTokenStorage.layout().burnAddress) {
            revert BurnIncorrectSender();
        }

        _burn(tokenId);
    }
}
