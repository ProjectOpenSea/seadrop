// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1155SeaDrop } from "../ERC1155SeaDrop.sol";

import { ERC8451Lockable, LockMode } from "../lib/ERC8451Lockable.sol";

import { IERC6982 } from "../interfaces/IERC6982.sol";

import { IERC8451 } from "../interfaces/IERC8451.sol";

/**
 * @title  ERC1155SeaDropLockable
 * @author Ryan Ghods (ralxz.eth)
 * @notice ERC1155SeaDrop with lockable tokens (ERC-6982) and permanent
 *         locks (ERC-8451). Lock status applies per token id. Deploy with
 *         `LockMode.Locked` to pause trading until the owner unlocks it, or
 *         with `LockMode.PermanentlyLocked` for tokens that can never be
 *         transferred.
 *
 *         Locks restrict holder transfers only. Minting continues while
 *         tokens are locked, and the holder or an approved operator can
 *         still burn. Approvals work as usual until the lock is permanent.
 *         After that, new approvals revert, and existing approvals can
 *         still be revoked.
 *
 *         A token id exists while its total supply is greater than zero.
 */
contract ERC1155SeaDropLockable is ERC1155SeaDrop, ERC8451Lockable {
    /**
     * @notice Deploy the token contract.
     *
     * @param allowedConfigurer The address of the contract allowed to
     *                          configure parameters. Also contains SeaDrop
     *                          implementation code.
     * @param allowedSeaport    The address of the Seaport contract allowed to
     *                          interact.
     * @param name_             The name of the token.
     * @param symbol_           The symbol of the token.
     * @param lockMode          The lock status to start with: Unlocked (0),
     *                          Locked (1), or PermanentlyLocked (2).
     */
    constructor(
        address allowedConfigurer,
        address allowedSeaport,
        string memory name_,
        string memory symbol_,
        LockMode lockMode
    )
        ERC1155SeaDrop(allowedConfigurer, allowedSeaport, name_, symbol_)
        ERC8451Lockable(lockMode)
    {}

    /**
     * @notice Approve or remove `operator` as an operator for the caller.
     *         Granting an approval reverts once the lock is permanent.
     *         Removing one always works.
     */
    function setApprovalForAll(
        address operator,
        bool isApproved
    ) public virtual override {
        if (isApproved) {
            _revertIfPermanentlyLocked();
        }

        super.setApprovalForAll(operator, isApproved);
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC6982).interfaceId ||
            interfaceId == type(IERC8451).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Reverts holder transfers of locked token ids with `TokenLocked`.
     *      Mints and burns are not holder transfers and are not affected.
     *      The lock is checked before the transfer validator.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        if (from != address(0) && to != address(0)) {
            // Put the length on the stack for more efficient access.
            uint256 idsLength = ids.length;

            for (uint256 i = 0; i < idsLength; ) {
                _revertIfTokenLocked(ids[i]);

                unchecked {
                    ++i;
                }
            }
        }

        super._beforeTokenTransfer(from, to, ids, amounts, data);
    }

    /**
     * @dev Only the owner can update the lock.
     */
    function _authorizeLockUpdate() internal view override {
        _checkOwner();
    }

    /**
     * @dev A token id exists while its total supply is greater than zero.
     */
    function _lockableTokenExists(
        uint256 tokenId
    ) internal view override returns (bool) {
        return _tokenSupply[tokenId].totalSupply != 0;
    }
}
