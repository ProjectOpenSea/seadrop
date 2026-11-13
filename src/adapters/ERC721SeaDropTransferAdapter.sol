// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721SeaDropAdapter } from "./ERC721SeaDropAdapter.sol";

import { IERC721 } from "openzeppelin-contracts/token/ERC721/IERC721.sol";

import {
    IERC721Receiver
} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";

/**
 * @title  ERC721SeaDropTransferAdapter
 * @author OpenSea
 * @notice A SeaDrop adapter that sells tokens the adapter already holds. Use
 *         it when the target has no way to let another address mint, but
 *         its owner can mint to any address.
 *
 *         The owner mints the drop's tokens to the adapter, or sends tokens
 *         it holds with `safeTransferFrom`. The adapter queues each token it
 *         receives from the owner, and each SeaDrop mint transfers the next
 *         queued tokens to the minter in the order they arrived. The drop
 *         can mint at most the lower of the max supply and the tokens
 *         received.
 *
 *         The owner can take back unsold tokens with `withdraw`, and any
 *         target token that reached the adapter without being queued with
 *         `rescue`.
 */
contract ERC721SeaDropTransferAdapter is ERC721SeaDropAdapter, IERC721Receiver {
    /// @notice Revert when a token not from the target arrives.
    error OnlyTarget();

    /// @notice Revert when a target token arrives from someone other than
    ///         the owner.
    error OnlyOwnerCanDeposit();

    /// @notice Revert when withdrawing more tokens than are queued.
    error NotEnoughQueuedTokens(uint256 requested, uint256 available);

    /// @notice Revert when rescuing a token that is queued for the drop.
    error TokenIsQueued(uint256 tokenId);

    /// @notice Emit when a token is queued for the drop.
    event TokenQueued(uint256 tokenId);

    /// @notice The queued token IDs, in the order they arrived.
    uint256[] internal _queue;

    /// @notice The index in `_queue` of the next token to deliver.
    uint256 internal _nextIndex;

    /// @notice Whether a token is queued and not yet delivered.
    mapping(uint256 => bool) internal _isQueued;

    /// @dev Set while the adapter transfers a token out, so a target that
    ///      calls back into the adapter can't queue a token mid-delivery.
    bool internal _delivering;

    /**
     * @notice Deploy the adapter. The deployer becomes the owner.
     *
     * @param targetContract The existing ERC-721 contract to sell tokens of.
     * @param allowedSeaDrop The SeaDrop addresses allowed to mint.
     */
    constructor(address targetContract, address[] memory allowedSeaDrop)
        ERC721SeaDropAdapter(targetContract, allowedSeaDrop)
    { }

    /**
     * @notice Queue a target token sent or minted to the adapter by the
     *         owner.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        if (msg.sender != target) {
            revert OnlyTarget();
        }
        address owner_ = owner();
        if (_delivering || (operator != owner_ && from != owner_)) {
            revert OnlyOwnerCanDeposit();
        }

        _queue.push(tokenId);
        _isQueued[tokenId] = true;
        emit TokenQueued(tokenId);

        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice The number of queued tokens not yet delivered.
    function queuedTokenCount() public view returns (uint256) {
        return _queue.length - _nextIndex;
    }

    /// @notice The queued token IDs not yet delivered, in delivery order.
    function queuedTokenIds() external view returns (uint256[] memory ids) {
        uint256 count = queuedTokenCount();
        ids = new uint256[](count);
        for (uint256 i = 0; i < count;) {
            ids[i] = _queue[_nextIndex + i];
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Send the last `quantity` queued tokens to `to`, lowering what
     *         the drop can sell. Only the owner can call.
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

        _delivering = true;
        for (uint256 i = 0; i < quantity;) {
            uint256 tokenId = _queue[_queue.length - 1];
            _queue.pop();
            _isQueued[tokenId] = false;
            IERC721(target).safeTransferFrom(address(this), to, tokenId);
            unchecked {
                ++i;
            }
        }
        _delivering = false;
    }

    /**
     * @notice Send a target token the adapter holds but hasn't queued, such
     *         as one sent with `transferFrom`, to `to`. Only the owner can
     *         call.
     */
    function rescue(uint256 tokenId, address to)
        external
        nonReentrant
        onlyOwner
    {
        if (_isQueued[tokenId]) {
            revert TokenIsQueued(tokenId);
        }
        _delivering = true;
        IERC721(target).safeTransferFrom(address(this), to, tokenId);
        _delivering = false;
    }

    /// @dev Cap the mintable supply at the tokens this drop can still sell.
    function _mintableSupply() internal view override returns (uint256) {
        uint256 available = _totalMinted + queuedTokenCount();
        return _maxSupply < available ? _maxSupply : available;
    }

    /// @dev Transfer the next `quantity` queued tokens to the minter.
    function _deliver(address minter, uint256 quantity) internal override {
        uint256 index = _nextIndex;
        _nextIndex = index + quantity;

        _delivering = true;
        for (uint256 i = 0; i < quantity;) {
            uint256 tokenId = _queue[index + i];
            _isQueued[tokenId] = false;
            IERC721(target).safeTransferFrom(address(this), minter, tokenId);
            unchecked {
                ++i;
            }
        }
        _delivering = false;
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
}
