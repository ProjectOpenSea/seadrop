// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721SeaDropAdapter } from "./ERC721SeaDropAdapter.sol";

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

/// @dev The `totalSupply()` getter most ERC-721 contracts have.
interface IERC721Supply {
    function totalSupply() external view returns (uint256);
}

/**
 * @title  ERC721SeaDropMintAdapter
 * @author OpenSea
 * @notice A SeaDrop adapter that mints by calling a mint function on the
 *         target. Use it when the target lets its owner grant another
 *         address the right to mint, such as a minter role or an allowed
 *         minter list.
 *
 *         The mint function must take `(address to, uint256 quantity)` and
 *         mint `quantity` new tokens to `to`, for example
 *         `mint(address,uint256)` or `mintTo(address,uint256)`. Pass its
 *         selector to the constructor, then grant the adapter's address the
 *         right to call it on the target.
 *
 *         After each call the adapter checks that exactly `quantity` tokens
 *         were minted. It counts them by the target's `totalSupply()` when
 *         the target has one, which a recipient that forwards tokens in
 *         `onERC721Received` doesn't change, and otherwise by the minter's
 *         balance. A function whose second argument is a token ID mints one
 *         token, so purchases of two or more revert with
 *         `UnexpectedMintCount`. A single-token purchase passes the check,
 *         so the deployer must confirm the selector takes a quantity
 *         before deploying. A target with a different mint signature needs
 *         its own subclass of `ERC721SeaDropAdapter`.
 */
contract ERC721SeaDropMintAdapter is ERC721SeaDropAdapter {
    /// @notice Revert when the target minted a different number of tokens
    ///         to the minter than the drop asked for.
    error UnexpectedMintCount(uint256 expected, uint256 actual);

    /// @notice The selector of the target's
    ///         `(address to, uint256 quantity)` mint function.
    bytes4 public immutable mintSelector;

    /// @notice Whether mints are counted by the target's `totalSupply()`
    ///         rather than the minter's balance. Set at deployment by
    ///         probing the target.
    bool public immutable countsBySupply;

    /**
     * @notice Deploy the adapter. The deployer becomes the owner.
     *
     * @param targetContract   The existing ERC-721 contract to mint for.
     * @param targetMintSelector The selector of the target's mint function.
     * @param allowedSeaDrop   The SeaDrop addresses allowed to mint.
     */
    constructor(
        address targetContract,
        bytes4 targetMintSelector,
        address[] memory allowedSeaDrop
    ) ERC721SeaDropAdapter(targetContract, allowedSeaDrop) {
        mintSelector = targetMintSelector;

        (bool success, bytes memory returnData) =
            targetContract.staticcall(abi.encodeWithSignature("totalSupply()"));
        countsBySupply = success && returnData.length == 32;
    }

    /// @dev The target's total supply, or `minter`'s balance if the target
    ///      has no `totalSupply()`.
    function _mintCounter(address minter) internal view returns (uint256) {
        if (countsBySupply) {
            return IERC721Supply(target).totalSupply();
        }
        return IERC721(target).balanceOf(minter);
    }

    /**
     * @dev Call the target's mint function and check it minted exactly
     *      `quantity` tokens. Bubbles up the target's revert.
     */
    function _deliver(address minter, uint256 quantity) internal override {
        uint256 countBefore = _mintCounter(minter);

        (bool success, bytes memory returnData) =
            target.call(abi.encodeWithSelector(mintSelector, minter, quantity));
        if (!success) {
            assembly ("memory-safe") {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }

        uint256 countAfter = _mintCounter(minter);
        if (countAfter != countBefore + quantity) {
            revert UnexpectedMintCount(
                quantity,
                countAfter > countBefore ? countAfter - countBefore : 0
            );
        }
    }
}
