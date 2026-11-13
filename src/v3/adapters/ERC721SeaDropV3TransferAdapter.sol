// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721SeaDropV3Adapter } from "./ERC721SeaDropV3Adapter.sol";

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

import {
    IERC721Receiver
} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title  ERC721SeaDropV3TransferAdapter
 * @notice An adapter that sells tokens it already holds. Use it when the
 *         target has no way to let another address mint, but its owner can
 *         mint to any address.
 *
 *         The adapter's owner mints the drop's tokens to the adapter, or
 *         sends tokens it holds with `safeTransferFrom`. The adapter queues
 *         each target token that arrives from its owner, and each mint
 *         transfers the next queued tokens to the recipient in arrival
 *         order. The drop can mint at most the lower of the max supply and
 *         the tokens it has received.
 *
 *         The owner takes back unsold tokens with `withdraw`, and any target
 *         token that reached the adapter without being queued with
 *         `rescue`.
 *
 *         The adapter approves no operator for its tokens, but custody
 *         still depends on the target. An operator the target approves for
 *         every holder, such as a preapproved conduit, is approved for the
 *         adapter's tokens too. With OpenSea's conduit, Seaport moves a
 *         holder's tokens only for an order the holder signed or
 *         validated, which the adapter can't do. Any other operator or
 *         conduit channel the target trusts can move them.
 */
contract ERC721SeaDropV3TransferAdapter is
    ERC721SeaDropV3Adapter,
    IERC721Receiver
{
    /// @dev The queued token ids, in arrival order.
    uint256[] internal _queue;

    /// @dev The index in `_queue` of the next token to deliver.
    uint256 internal _nextIndex;

    /// @notice Whether a token is queued and not yet delivered.
    mapping(uint256 tokenId => bool queued) public isQueued;

    event TokenQueued(uint256 tokenId);

    error OnlyTarget(address caller);
    error OnlyOwnerCanDeposit(address operator, address from);
    error DepositDuringTransfer();
    error NotEnoughQueuedTokens(uint256 requested, uint256 available);
    error TokenIsQueued(uint256 tokenId);
    error StillHoldsTokens(uint256 balance);

    /**
     * @param targetContract The existing ERC-721 contract to sell tokens of.
     * @param minter         The chain's SeaDropMinter.
     * @param initialOwner   The adapter's owner, who deposits the tokens.
     */
    constructor(address targetContract, address minter, address initialOwner)
        ERC721SeaDropV3Adapter(targetContract, minter, initialOwner)
    { }

    /**
     * @notice Queue a target token its owner minted or sent to the adapter.
     *         Tokens from anyone else are rejected, and so is any deposit
     *         while the adapter is transferring tokens out.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        if (msg.sender != target) {
            revert OnlyTarget(msg.sender);
        }
        if (_entered) revert DepositDuringTransfer();
        address owner_ = owner();
        if (operator != owner_ && from != owner_) {
            revert OnlyOwnerCanDeposit(operator, from);
        }

        _queue.push(tokenId);
        isQueued[tokenId] = true;
        emit TokenQueued(tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice The number of queued tokens not yet delivered.
    function queuedTokenCount() public view returns (uint256) {
        return _queue.length - _nextIndex;
    }

    /// @notice The queued token ids not yet delivered, in delivery order.
    function queuedTokenIds() external view returns (uint256[] memory ids) {
        uint256 count = queuedTokenCount();
        ids = new uint256[](count);
        for (uint256 i; i < count; ++i) {
            ids[i] = _queue[_nextIndex + i];
        }
    }

    /**
     * @notice Send the last `quantity` queued tokens to `to`, lowering what
     *         the drop can sell. Only the owner can call this.
     */
    function withdraw(address to, uint256 quantity)
        external
        nonReentrant
        onlyOwner
    {
        uint256 available = queuedTokenCount();
        if (quantity > available) {
            revert NotEnoughQueuedTokens(quantity, available);
        }

        for (uint256 i; i < quantity; ++i) {
            uint256 tokenId = _queue[_queue.length - 1];
            _queue.pop();
            isQueued[tokenId] = false;
            IERC721(target).safeTransferFrom(address(this), to, tokenId);
        }
    }

    /**
     * @notice Send a target token the adapter holds but hasn't queued, such
     *         as one sent with `transferFrom`, to `to`. Only the owner can
     *         call this.
     */
    function rescue(uint256 tokenId, address to)
        external
        nonReentrant
        onlyOwner
    {
        if (isQueued[tokenId]) revert TokenIsQueued(tokenId);
        IERC721(target).safeTransferFrom(address(this), to, tokenId);
    }

    /**
     * @notice Renounce ownership, which also cancels a pending transfer.
     *         Only `withdraw` and `rescue` get tokens out other than a
     *         mint, and only the owner can call them, so this reverts
     *         while the adapter holds any of the target's tokens.
     */
    function renounceOwnership() public override {
        uint256 balance = IERC721(target).balanceOf(address(this));
        if (balance != 0) revert StillHoldsTokens(balance);
        super.renounceOwnership();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IERC721Receiver).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @dev Cap the mintable supply at the tokens this drop can still sell.
    function _mintableSupply() internal view override returns (uint256) {
        uint256 available = totalMinted + queuedTokenCount();
        return maxSupply < available ? maxSupply : available;
    }

    /// @dev Transfer the next `quantity` queued tokens to `to`.
    function _deliver(address to, uint256 quantity) internal override {
        uint256 index = _nextIndex;
        _nextIndex = index + quantity;

        for (uint256 i; i < quantity; ++i) {
            uint256 tokenId = _queue[index + i];
            isQueued[tokenId] = false;
            IERC721(target).safeTransferFrom(address(this), to, tokenId);
        }
    }
}
