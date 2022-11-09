// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import {Withdrawable} from "./Withdrawable.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

///@notice Ownable helper contract to withdraw ether or tokens from the contract address balance
contract CommissionWithdrawable is Withdrawable {
    address internal immutable commissionPayoutAddress;
    uint256 internal immutable commissionBps;

    error CommissionPayoutAddressIsZeroAddress();
    error CommissionBpsTooLarge();

    constructor(address _commissionPayoutAddress, uint256 _commissionBps) {
        if (_commissionPayoutAddress == address(0)) {
            revert CommissionPayoutAddressIsZeroAddress();
        }
        if (_commissionBps > 10_000) {
            revert CommissionBpsTooLarge();
        }
        commissionPayoutAddress = _commissionPayoutAddress;
        commissionBps = _commissionBps;
    }

    ////////////////////////
    // Withdrawal methods //
    ////////////////////////

    ///@notice Withdraw Ether from contract address. OnlyOwner.
    function withdraw() external override onlyOwner {
        uint256 balance = address(this).balance;
        (
            uint256 ownerShareMinusCommission,
            uint256 commissionFee
        ) = calculateOwnerShareAndCommissionFee(balance);
        SafeTransferLib.safeTransferETH(owner(), ownerShareMinusCommission);
        SafeTransferLib.safeTransferETH(commissionPayoutAddress, commissionFee);
    }

    ///@notice Withdraw tokens from contract address. OnlyOwner.
    ///@param _token ERC20 smart contract address
    function withdrawERC20(address _token) external override onlyOwner {
        ERC20 token = ERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        (
            uint256 ownerShareMinusCommission,
            uint256 commissionFee
        ) = calculateOwnerShareAndCommissionFee(balance);
        SafeTransferLib.safeTransfer(token, owner(), ownerShareMinusCommission);
        SafeTransferLib.safeTransfer(
            token,
            commissionPayoutAddress,
            commissionFee
        );
    }

    function calculateOwnerShareAndCommissionFee(uint256 balance)
        private
        view
        returns (uint256, uint256)
    {
        uint256 commissionFee;
        // commissionBps is max 10000 which is ~2^14; will only overflow if balance is > ~2^242
        if (balance < (1 << 242)) {
            commissionFee = (balance * commissionBps) / 10000;
        } else {
            // worst case this drops 99_990_000, neglibible if balance is > 2^242
            commissionFee = (balance / 10000) * commissionBps;
        }
        uint256 ownerShareMinusCommission = balance - commissionFee;
        return (ownerShareMinusCommission, commissionFee);
    }
}
