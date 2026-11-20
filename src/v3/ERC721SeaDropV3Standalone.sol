// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721SeaDropV3 } from "./ERC721SeaDropV3.sol";

/// @notice A directly deployed SeaDrop ERC-721. The constructor configures
///         the token atomically. Token ids start at 1, as on factory clones.
contract ERC721SeaDropV3Standalone is ERC721SeaDropV3 {
    constructor(
        address initialOwner,
        address minter,
        string memory name_,
        string memory symbol_,
        address conduit
    ) ERC721SeaDropV3(conduit) initializerERC721A {
        _initializeStandalone(initialOwner, minter);
        __ERC721A_init_unchained(name_, symbol_);
    }
}
