// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ICreatorToken {
    event TransferValidatorUpdated(address oldValidator, address newValidator);

    function getTransferValidator() external view returns (address validator);

    function setTransferValidator(address validator) external;
}
