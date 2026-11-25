// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ISeaDropTokenV3 } from "../interfaces/ISeaDropTokenV3.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

import { IERC2981 } from "openzeppelin-contracts/interfaces/IERC2981.sol";

import {
    IERC165
} from "openzeppelin-contracts/utils/introspection/IERC165.sol";

/**
 * @title  ERC721SeaDropV3Adapter
 * @notice Runs a SeaDropMinter drop for an ERC-721 contract that was
 *         deployed without SeaDrop support (the target).
 *
 *         The minter treats the adapter as the drop's token. Stages, payout
 *         recipients, wallet counts and `SeaDropMint` events are all keyed
 *         by the adapter's address, and the adapter delivers each mint on
 *         the target. Subclasses decide how: by calling a mint function the
 *         target lets the adapter call (`ERC721SeaDropV3MintAdapter`), or
 *         by transferring tokens the adapter holds
 *         (`ERC721SeaDropV3TransferAdapter`).
 *
 *         The adapter's owner configures the drop on the minter directly,
 *         as a token's owner does, since the minter checks the token's
 *         `owner()`. The adapter's max supply caps this drop only, and
 *         `mintStats` counts this drop's mints only, so stage supply caps
 *         ignore tokens the target minted before. Token metadata and
 *         royalties stay on the target.
 *
 *         The adapter isn't an ERC-721 itself, so the minter doesn't limit
 *         its stages to id 0. `mintSeaDrop` rejects any other id instead,
 *         so stages at other ids can't mint and can't give a wallet a
 *         second wallet limit.
 */
abstract contract ERC721SeaDropV3Adapter is TwoStepOwnable, ISeaDropTokenV3 {
    /// @notice The ERC-721 contract this adapter delivers mints on.
    address public immutable target;

    /// @notice Contracts allowed to call `mintSeaDrop`.
    mapping(address minter => bool allowed) public allowedMinters;

    /// @notice The most tokens this drop can mint.
    uint256 public maxSupply;

    /// @notice The number of tokens this drop has minted.
    uint256 public totalMinted;

    string internal _contractURI;

    /// @dev Set while `mintSeaDrop`, or a subclass's nonReentrant function,
    ///      runs.
    bool internal transient _entered;

    /**
     * @notice Emitted on deployment, naming the contract the adapter mints
     *         for. OpenSea reads it to show the drop on that contract's
     *         collection instead of on the adapter's own.
     */
    event SeaDropShimDeployed(address indexed tokenContract);

    event AllowedMinterUpdated(address indexed minter, bool allowed);

    event MaxSupplyUpdated(uint256 maxSupply);

    /// @dev ERC-7572.
    event ContractURIUpdated();

    error TargetHasNoCode(address target);
    error OnlyAllowedMinter(address caller);
    error IdNotZero(uint256 id);
    error QuantityIsZero();
    error Reentrancy();
    error MaxSupplyBelowTotalMinted(uint256 maxSupply, uint256 totalMinted);

    /// @dev Same selector as SeaDropMinter's and the v3 tokens', so a
    ///      supply failure reads the same whichever contract catches it.
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);

    /**
     * @param targetContract The existing ERC-721 contract to mint for.
     * @param minter         The first allowed minter, the chain's
     *                       SeaDropMinter, or address(0) for none.
     * @param initialOwner   The adapter's owner, who configures the drop.
     *                       Passed in so a CREATE2 deployer doesn't end up
     *                       owning it.
     */
    constructor(address targetContract, address minter, address initialOwner) {
        if (targetContract.code.length == 0) {
            revert TargetHasNoCode(targetContract);
        }
        target = targetContract;
        if (initialOwner == address(0)) revert NewOwnerIsZeroAddress();
        _transferOwnership(initialOwner);
        if (minter != address(0)) _setAllowedMinter(minter, true);

        emit SeaDropShimDeployed(targetContract);
    }

    /**
     * @dev Deliver `quantity` of the target's tokens to `to`. Called by
     *      `mintSeaDrop` after the supply check and count update.
     *      Implementations revert unless exactly `quantity` were delivered.
     */
    function _deliver(address to, uint256 quantity) internal virtual;

    /// @dev The most this drop can mint right now: the max supply, which
    ///      the transfer adapter also caps at the tokens it holds.
    function _mintableSupply() internal view virtual returns (uint256) {
        return maxSupply;
    }

    /**
     * @inheritdoc ISeaDropTokenV3
     * @dev Only id 0. The minter calls this after collecting payment and
     *      before paying out, under its own reentrancy guard.
     */
    function mintSeaDrop(address to, uint256 id, uint256 quantity)
        external
        nonReentrant
    {
        if (!allowedMinters[msg.sender]) {
            revert OnlyAllowedMinter(msg.sender);
        }
        if (id != 0) revert IdNotZero(id);
        if (quantity == 0) revert QuantityIsZero();

        uint256 total = totalMinted + quantity;
        uint256 mintable = _mintableSupply();
        if (total > mintable) {
            revert MintQuantityExceedsMaxSupply(total, mintable);
        }
        totalMinted = total;

        _deliver(to, quantity);
    }

    /**
     * @inheritdoc ISeaDropTokenV3
     * @dev Counts this drop's mints only, not the target's, so stage
     *      supply caps compare against this drop. Every id reads the same.
     */
    function mintStats(uint256)
        external
        view
        returns (uint256 totalMinted_, uint256 maxSupply_)
    {
        return (totalMinted, _mintableSupply());
    }

    /// @notice Allow or disallow a minter.
    function setAllowedMinter(address minter, bool allowed) external onlyOwner {
        _setAllowedMinter(minter, allowed);
    }

    /// @notice Set the most tokens this drop can mint. It can't go below
    ///         what the drop minted.
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        if (newMaxSupply < totalMinted) {
            revert MaxSupplyBelowTotalMinted(newMaxSupply, totalMinted);
        }
        maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }

    /// @notice Set the drop's contract metadata URI.
    function setContractURI(string calldata newContractURI) external onlyOwner {
        _contractURI = newContractURI;
        emit ContractURIUpdated();
    }

    /// @notice The drop's contract metadata URI, per ERC-7572.
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /// @notice Renouncing also cancels a pending transfer, so a pending
    ///         owner can't claim the adapter afterwards.
    function renounceOwnership() public virtual override onlyOwner {
        cancelOwnershipTransfer();
        super.renounceOwnership();
    }

    /**
     * @notice The target's EIP-2981 royalty, or none if the target doesn't
     *         answer with one.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        // A raw staticcall, so a target without EIP-2981 returns no royalty
        // even when its fallback succeeds with empty or short returndata.
        (bool success, bytes memory data) = target.staticcall(
            abi.encodeCall(IERC2981.royaltyInfo, (tokenId, salePrice))
        );
        if (success && data.length >= 64) {
            (receiver, royaltyAmount) = abi.decode(data, (address, uint256));
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        returns (bool)
    {
        return interfaceId == type(ISeaDropTokenV3).interfaceId
            || interfaceId == type(IERC2981).interfaceId
            || interfaceId == type(IERC165).interfaceId;
    }

    function _setAllowedMinter(address minter, bool allowed) internal {
        allowedMinters[minter] = allowed;
        emit AllowedMinterUpdated(minter, allowed);
    }

    modifier nonReentrant() {
        if (_entered) revert Reentrancy();
        _entered = true;
        _;
        _entered = false;
    }
}
