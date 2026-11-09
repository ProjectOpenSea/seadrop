// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ISeaDropTokenV3 } from "./interfaces/ISeaDropTokenV3.sol";

import { TwoStepOwnable } from "utility-contracts/TwoStepOwnable.sol";

/**
 * @title  SeaDropTokenV3Base
 * @notice What both v3 tokens share: an owner, the minters it allows and
 *         an ERC-7572 contract URI. Drop configuration lives in the
 *         minter.
 */
abstract contract SeaDropTokenV3Base is TwoStepOwnable, ISeaDropTokenV3 {
    /// @notice Contracts allowed to call `mintSeaDrop`.
    mapping(address minter => bool allowed) public allowedMinters;

    string internal _contractURI;

    event AllowedMinterUpdated(address indexed minter, bool allowed);

    /// @dev ERC-7572.
    event ContractURIUpdated();

    /// @dev ERC-4906.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    error OnlyAllowedMinter(address caller);

    /// @dev Same selector as SeaDropMinter's, so a supply failure reads the
    ///      same whichever contract catches it.
    error MintQuantityExceedsMaxSupply(uint256 total, uint256 maxSupply);

    constructor(address minter) {
        if (minter != address(0)) _setAllowedMinter(minter, true);
    }

    /// @notice Allow or disallow a minter.
    function setAllowedMinter(address minter, bool allowed) external onlyOwner {
        _setAllowedMinter(minter, allowed);
    }

    /// @notice Set the contract metadata URI.
    function setContractURI(string calldata newContractURI) external onlyOwner {
        _contractURI = newContractURI;
        emit ContractURIUpdated();
    }

    /// @notice The contract metadata URI, per ERC-7572.
    function contractURI() external view returns (string memory) {
        return _contractURI;
    }

    /// @notice Renouncing also cancels a pending transfer, so a pending
    ///         owner can't claim the token afterwards.
    function renounceOwnership() public override onlyOwner {
        cancelOwnershipTransfer();
        super.renounceOwnership();
    }

    function _setAllowedMinter(address minter, bool allowed) internal {
        allowedMinters[minter] = allowed;
        emit AllowedMinterUpdated(minter, allowed);
    }

    function _checkMinter() internal view {
        if (!allowedMinters[msg.sender]) revert OnlyAllowedMinter(msg.sender);
    }
}
