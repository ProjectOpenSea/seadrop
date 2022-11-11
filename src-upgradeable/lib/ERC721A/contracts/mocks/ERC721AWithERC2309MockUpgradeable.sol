// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creators: Chiru Labs

pragma solidity ^0.8.4;

import '../ERC721AUpgradeable.sol';
import '../ERC721A__Initializable.sol';

contract ERC721AWithERC2309MockUpgradeable is ERC721A__Initializable, ERC721AUpgradeable {
    function __ERC721AWithERC2309Mock_init(
        string memory name_,
        string memory symbol_,
        address to,
        uint256 quantity,
        bool mintInConstructor
    ) internal onlyInitializingERC721A {
        __ERC721A_init_unchained(name_, symbol_);
        __ERC721AWithERC2309Mock_init_unchained(name_, symbol_, to, quantity, mintInConstructor);
    }

    function __ERC721AWithERC2309Mock_init_unchained(
        string memory,
        string memory,
        address to,
        uint256 quantity,
        bool mintInConstructor
    ) internal onlyInitializingERC721A {
        if (mintInConstructor) {
            _mintERC2309(to, quantity);
        }
    }

    /**
     * @dev This function is only for gas comparison purposes.
     * Calling `_mintERC3201` outside of contract creation is non-compliant
     * with the ERC721 standard.
     */
    function mintOneERC2309(address to) public {
        _mintERC2309(to, 1);
    }

    /**
     * @dev This function is only for gas comparison purposes.
     * Calling `_mintERC3201` outside of contract creation is non-compliant
     * with the ERC721 standard.
     */
    function mintTenERC2309(address to) public {
        _mintERC2309(to, 10);
    }
}
