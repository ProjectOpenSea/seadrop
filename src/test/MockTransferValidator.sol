// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.17;

import { ITransferValidator } from "../interfaces/ITransferValidator.sol";

contract MockTransferValidator is ITransferValidator {
    bool internal _revertOnValidate;

    constructor(bool revertOnValidate) {
        _revertOnValidate = revertOnValidate;
    }

    function validateTransfer(
        address,
        /* caller */
        address,
        /* from */
        address,
        /* to */
        uint256 /* tokenId */
    ) external view {
        if (_revertOnValidate) {
            revert("MockTransferValidator: always reverts");
        }
    }

    function validateTransfer(
        address, /* caller */
        address, /* from */
        address, /* to */
        uint256, /* tokenId */
        uint256 /* amount */
    ) external view {
        if (_revertOnValidate) {
            revert("MockTransferValidator: always reverts");
        }
    }
}
