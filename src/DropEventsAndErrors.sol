// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface DropEventsAndErrors {
    error NotActive(
        uint256 currentTimestamp,
        uint256 startTimestamp,
        uint256 endTimestamp
    );
    error AmountExceedsAllowed(uint256 amount, uint256 allowed);
    error AllowListRedeemed();
    error IncorrectPayment(uint256 got, uint256 want);
}
