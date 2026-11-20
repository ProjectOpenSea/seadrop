// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721SeaDropV3Adapter } from "./ERC721SeaDropV3Adapter.sol";

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

/// @dev The `totalSupply()` getter most ERC-721 contracts have.
interface IERC721Supply {
    function totalSupply() external view returns (uint256);
}

/**
 * @title  ERC721SeaDropV3MintAdapter
 * @notice An adapter that mints by calling a mint function on the target.
 *         Use it when the target lets its owner grant another address the
 *         right to mint, such as a minter role or an allowed minter list.
 *
 *         The mint function must take `(address to, uint256 quantity)` and
 *         mint `quantity` new tokens to `to`, for example
 *         `mint(address,uint256)` or `mintTo(address,uint256)`. Pass its
 *         selector to the constructor, then grant the adapter's address the
 *         right to call it on the target.
 *
 *         After each call the adapter checks that exactly `quantity` tokens
 *         were minted, and reverts the whole mint otherwise, payment
 *         included. It counts by the target's `totalSupply()` when the
 *         target has one, which a recipient that forwards tokens in
 *         `onERC721Received` doesn't change, and otherwise by the
 *         recipient's balance. On a target without `totalSupply()`, a
 *         recipient that forwards or burns the token in that callback
 *         shows no balance change, so its mint reverts with the payment
 *         refunded. Such a recipient mints to another address instead.
 *         A function whose second argument is a token
 *         id mints one token, so purchases of two or more revert with
 *         `UnexpectedMintCount`. A single-token purchase passes the check,
 *         so the deployer confirms the selector takes a quantity before
 *         deploying. A target with another mint signature needs its own
 *         subclass of `ERC721SeaDropV3Adapter`.
 */
contract ERC721SeaDropV3MintAdapter is ERC721SeaDropV3Adapter {
    /// @notice The selector of the target's
    ///         `(address to, uint256 quantity)` mint function.
    bytes4 public immutable mintSelector;

    /// @notice Whether mints are counted by the target's `totalSupply()`
    ///         rather than the recipient's balance. Set at deployment by
    ///         probing the target.
    bool public immutable countsBySupply;

    /// @notice The target minted a different number of tokens than the
    ///         drop asked for.
    error UnexpectedMintCount(uint256 expected, uint256 actual);

    /**
     * @param targetContract     The existing ERC-721 contract to mint for.
     * @param targetMintSelector The selector of the target's mint function.
     * @param minter             The chain's SeaDropMinter.
     * @param initialOwner       The adapter's owner.
     */
    constructor(
        address targetContract,
        bytes4 targetMintSelector,
        address minter,
        address initialOwner
    ) ERC721SeaDropV3Adapter(targetContract, minter, initialOwner) {
        mintSelector = targetMintSelector;

        (bool success, bytes memory data) = targetContract.staticcall(
            abi.encodeCall(IERC721Supply.totalSupply, ())
        );
        countsBySupply = success && data.length == 32;
    }

    /**
     * @dev Call the target's mint function and check it minted exactly
     *      `quantity` tokens. Bubbles up the target's revert.
     */
    function _deliver(address to, uint256 quantity) internal override {
        uint256 countBefore = _mintCount(to);

        (bool success, bytes memory data) =
            target.call(abi.encodeWithSelector(mintSelector, to, quantity));
        if (!success) {
            assembly ("memory-safe") {
                revert(add(data, 0x20), mload(data))
            }
        }

        uint256 countAfter = _mintCount(to);
        if (countAfter != countBefore + quantity) {
            revert UnexpectedMintCount(
                quantity,
                countAfter > countBefore ? countAfter - countBefore : 0
            );
        }
    }

    /// @dev The target's total supply, or `to`'s balance if the target has
    ///      no `totalSupply()`.
    function _mintCount(address to) internal view returns (uint256) {
        if (countsBySupply) return IERC721Supply(target).totalSupply();
        return IERC721(target).balanceOf(to);
    }
}
