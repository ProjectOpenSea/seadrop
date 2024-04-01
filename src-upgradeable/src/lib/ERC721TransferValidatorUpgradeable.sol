// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ICreatorToken } from "../interfaces/ICreatorToken.sol";

import { ERC721ContractMetadataStorage } from "../ERC721ContractMetadataStorage.sol";

/**
 * @title  ERC721TransferValidatorUpgradeable
 * @notice Functionality to use a transfer validator.
 */
abstract contract ERC721TransferValidatorUpgradeable is ICreatorToken {
    using ERC721ContractMetadataStorage for ERC721ContractMetadataStorage.Layout;

    /// @notice Revert with an error if the transfer validator is being set to the same address.
    error SameTransferValidator();

    /// @notice Returns the currently active transfer validator.
    ///         The null address means no transfer validator is set.
    function getTransferValidator() external view returns (address) {
        return ERC721ContractMetadataStorage.layout()._transferValidator;
    }

    /// @notice Set the transfer validator.
    ///         The external method that uses this must include access control.
    function _setTransferValidator(address newValidator) internal {
        address oldValidator = ERC721ContractMetadataStorage.layout()._transferValidator;
        if (oldValidator == newValidator) {
            revert SameTransferValidator();
        }
        ERC721ContractMetadataStorage.layout()._transferValidator = newValidator;
        emit TransferValidatorUpdated(oldValidator, newValidator);
    }
}
