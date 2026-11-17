// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721 } from "solmate/tokens/ERC721.sol";

/**
 * @notice A stand-in for an existing ERC-721 without `totalSupply()`. Anyone
 *         can mint, which is enough for the adapter tests.
 */
contract TestMinimalERC721 is ERC721("Minimal", "MIN") {
    uint256 internal _nextId = 1;

    function mintTo(address to, uint256 quantity) external {
        for (uint256 i = 0; i < quantity; ++i) {
            _safeMint(to, _nextId++);
        }
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }
}
