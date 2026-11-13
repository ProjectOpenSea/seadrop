// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

/**
 * @notice A wallet that forwards each ERC-721 it receives to a vault, the
 *         way some smart wallets and staking contracts do.
 */
contract TestForwardingReceiver {
    address public immutable vault;

    constructor(address vault_) {
        vault = vault_;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        IERC721(msg.sender).transferFrom(address(this), vault, tokenId);
        return this.onERC721Received.selector;
    }
}
