// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721SeaDropUpgradeable} from "./ERC721SeaDropUpgradeable.sol";

import {
PublicDrop
} from "./lib/SeaDropStructsUpgradeable.sol";

library WalterTheRabbitStorage {
    struct Layout {
        /// @notice The only address that can burn tokens on this contract.
        address burnAddress;
    }

    bytes32 internal constant STORAGE_SLOT =
    keccak256("seaDrop.contracts.storage.walterTheRabbit");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

/*
 * @notice This contract uses ERC721SeaDrop,
 *         an ERC721A token contract that is compatible with SeaDrop.
 *         The set burn address is the only sender that can burn tokens.
 */
contract WalterTheRabbit is ERC721SeaDropUpgradeable {
    using WalterTheRabbitStorage for WalterTheRabbitStorage.Layout;

    /**
    * @notice Initialize the token contract with its name, symbol,
     *         administrator, and allowed SeaDrop addresses.
     */
    function initialize(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop
    ) external override initializer initializerERC721A {
        ERC721SeaDropUpgradeable.__ERC721SeaDrop_init(
            name,
            symbol,
            allowedSeaDrop
        );
    }

    /**
     * @notice A token can only be burned by the set burn address.
     */
    error BurnIncorrectSender();

    function setBurnAddress(address newBurnAddress) external onlyOwner {
        WalterTheRabbitStorage.layout().burnAddress = newBurnAddress;
    }

    function getBurnAddress() public view returns (address) {
        return WalterTheRabbitStorage.layout().burnAddress;
    }

    /**
     * @notice Destroys `tokenId`, only callable by the set burn address.
     *
     * @param tokenId The token id to burn.
     */
    function burn(uint256 tokenId) external override {
        if (msg.sender != WalterTheRabbitStorage.layout().burnAddress) {
            revert BurnIncorrectSender();
        }

        _burn(tokenId);
    }

    // @dev mint multiple tokens
    // @param quantity quantity of token to mint
    // @param delegateAddress address to mint to
    function mint(
        address seadrop,
        uint256 quantity,
        address delegateAddress
    ) external payable {
//        console.log("mint seadrop: %s to contract address: %s", seadrop, address(this));

        // Get the public drop data.
        PublicDrop memory publicDrop = getPublicDrop(seadrop, address(this));

        // Ensure that the drop has started.
        //_checkActive(publicDrop.startTime, publicDrop.endTime);
        // Put the mint price on the stack.
        uint256 mintPrice = publicDrop.mintPrice;

//        console.log("mint quantity: %s price: %s. value: %s", quantity, mintPrice, msg.value);


        require(
            _totalMinted() + quantity <= maxSupply(),
            "Exceed Total Supply"
        );

        require(msg.value == quantity * mintPrice, "Invalid ETH Amount for quantity");

//        console.log("after require", msg.value);
//        console.log("minting qty:", quantity);

        _mint(delegateAddress, quantity);
    }
}
