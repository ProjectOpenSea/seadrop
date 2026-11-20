// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

/**
 * @title  SeaDropTokenV3Base
 * @notice What both v3 tokens share: an owner, the minters it allows, a
 *         preapproved conduit and an ERC-7572 contract URI. Drop
 *         configuration lives in the minter.
 *
 *         Tokens are EIP-1167 clones that `SeaDropTokenFactory` deploys
 *         and initializes. The implementation is deployed by the factory,
 *         which fixes the conduit and the factory in its bytecode, so every
 *         clone of it shares them and only the factory can initialize one.
 *         The implementation itself can never be initialized.
 *
 *         This contract's state is in ERC-7201 namespaced storage.
 *         TwoStepOwnable's owner and pending owner aren't, and sit in the
 *         sequential slots after the token's base contract.
 */
abstract contract SeaDropTokenV3Base is TwoStepOwnable, ISeaDropTokenV3 {
    /// @custom:storage-location erc7201:seadrop.v3.SeaDropTokenV3Base
    struct BaseStorage {
        bool initialized;
        mapping(address minter => bool allowed) allowedMinters;
        mapping(address holder => bool revoked) conduitRevoked;
        string contractURI;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256(
    ///      "seadrop.v3.SeaDropTokenV3Base")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant BASE_STORAGE_SLOT =
        0x1cefbe2c3ccb7feb740a1ec48f16b0ca795114b40813c3af6640cac9f1a78d00;

    /**
     * @notice The conduit every holder's tokens are approved for until the
     *         holder revokes it, or address(0) for none. The factory sets it
     *         in the implementation's bytecode, so no clone's creator can
     *         choose it and no one can change it later. OpenSea's conduit
     *         differs by chain, so each chain's factory is deployed with
     *         that chain's.
     */
    address public immutable preapprovedConduit;

    /// @notice The factory, the only caller that can initialize a clone.
    address public immutable factory;

    event AllowedMinterUpdated(address indexed minter, bool allowed);

    /// @dev ERC-7572.
    event ContractURIUpdated();

    /// @dev ERC-4906.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    error OnlyAllowedMinter(address caller);
    error OnlyFactory(address caller);

    /// @dev Same selector as SeaDropMinter's, so a supply failure reads the
    ///      same whichever contract catches it.
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);

    /**
     * @dev Runs once, for the implementation. It fixes the conduit and the
     *      factory, marks the implementation initialized so no one can
     *      initialize it, and gives up the ownership TwoStepOwnable's
     *      constructor assigned.
     */
    constructor(address conduit) {
        preapprovedConduit = conduit;
        factory = msg.sender;
        _baseStorage().initialized = true;
        _transferOwnership(address(0));
    }

    /// @notice Allow or disallow a minter.
    function setAllowedMinter(address minter, bool allowed) external onlyOwner {
        _setAllowedMinter(minter, allowed);
    }

    /// @notice Whether `minter` can call `mintSeaDrop`.
    function allowedMinters(address minter) external view returns (bool) {
        return _baseStorage().allowedMinters[minter];
    }

    /// @notice Set the contract metadata URI.
    function setContractURI(string calldata newContractURI) external onlyOwner {
        _baseStorage().contractURI = newContractURI;
        emit ContractURIUpdated();
    }

    /// @notice The contract metadata URI, per ERC-7572.
    function contractURI() external view returns (string memory) {
        return _baseStorage().contractURI;
    }

    /// @notice Renouncing also cancels a pending transfer, so a pending
    ///         owner can't claim the token afterwards.
    function renounceOwnership() public override onlyOwner {
        cancelOwnershipTransfer();
        super.renounceOwnership();
    }

    /**
     * @dev Initializes a clone: only the factory can call it, and only
     *      once. Sets the owner and allows the minter. A second call
     *      reverts with ConstructorInitializable's `AlreadyInitialized`.
     */
    function _initializeBase(address initialOwner, address minter) internal {
        if (msg.sender != factory) revert OnlyFactory(msg.sender);
        BaseStorage storage $ = _baseStorage();
        if ($.initialized) revert AlreadyInitialized();
        $.initialized = true;
        _setOwnerAndMinter(initialOwner, minter);
    }

    error MinterIsZeroAddress();

    /// @dev Standalone constructors run after the base locks initialization.
    function _initializeStandalone(address initialOwner, address minter)
        internal
    {
        if (initialOwner == address(0)) revert NewOwnerIsZeroAddress();
        if (minter == address(0)) revert MinterIsZeroAddress();
        _setOwnerAndMinter(initialOwner, minter);
    }

    function _setOwnerAndMinter(address initialOwner, address minter) internal {
        _transferOwnership(initialOwner);
        _setAllowedMinter(minter, true);
    }

    function _setAllowedMinter(address minter, bool allowed) internal {
        _baseStorage().allowedMinters[minter] = allowed;
        emit AllowedMinterUpdated(minter, allowed);
    }

    /// @dev Whether `operator` is the preapproved conduit.
    function _isConduit(address operator) internal view returns (bool) {
        return operator != address(0) && operator == preapprovedConduit;
    }

    /// @dev Whether `holder` revoked the conduit's preapproval.
    function _conduitRevoked(address holder) internal view returns (bool) {
        return _baseStorage().conduitRevoked[holder];
    }

    function _setConduitRevoked(address holder, bool revoked) internal {
        _baseStorage().conduitRevoked[holder] = revoked;
    }

    function _checkMinter() internal view {
        if (!_baseStorage().allowedMinters[msg.sender]) {
            revert OnlyAllowedMinter(msg.sender);
        }
    }

    function _baseStorage() internal pure returns (BaseStorage storage $) {
        assembly {
            $.slot := BASE_STORAGE_SLOT
        }
    }
}
