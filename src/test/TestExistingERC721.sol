// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721A } from "ERC721A/ERC721A.sol";

/**
 * @notice A stand-in for an ERC-721 deployed without SeaDrop support. Its
 *         owner can mint to any address and grant other addresses the right
 *         to mint.
 */
contract TestExistingERC721 is ERC721A {
    error NotMinter();

    address public immutable owner;

    mapping(address => bool) public isMinter;

    event MinterUpdated(address minter, bool allowed);

    constructor() ERC721A("Existing", "EXIST") {
        owner = msg.sender;
    }

    function setMinter(address minter, bool allowed) external {
        if (msg.sender != owner) revert NotMinter();
        // forge-lint: disable-next-line(missing-events-access-control)
        isMinter[minter] = allowed;
        emit MinterUpdated(minter, allowed);
    }

    /// @notice Mint `quantity` tokens. Owner or minters only.
    function mintTo(address to, uint256 quantity) external {
        if (msg.sender != owner && !isMinter[msg.sender]) revert NotMinter();
        _safeMint(to, quantity);
    }

    /// @notice Mint a token by ID, like OpenZeppelin's `safeMint`. Owner or
    ///         minters only.
    function mintTokenId(address to, uint256 tokenId) external {
        if (msg.sender != owner && !isMinter[msg.sender]) revert NotMinter();
        // ERC721A mints sequentially, so stand in for a by-ID mint by
        // minting a single token.
        tokenId;
        _safeMint(to, 1);
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
