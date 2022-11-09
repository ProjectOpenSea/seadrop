// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;
import {TwoStepOwnable} from "../TwoStepOwnable.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC721} from "solmate/tokens/ERC721.sol";
import {IWithdrawable} from "./IWithdrawable.sol";

///@notice Ownable helper contract to withdraw ether or tokens from the contract address balance
contract Withdrawable is TwoStepOwnable, IWithdrawable {
    ///@notice Withdraw Ether from contract address. OnlyOwner.
    function withdraw() external virtual onlyOwner {
        uint256 balance = address(this).balance;
        SafeTransferLib.safeTransferETH(owner(), balance);
    }

    ///@notice Withdraw tokens from contract address. OnlyOwner.
    ///@param _token ERC20 smart contract address
    function withdrawERC20(address _token) external virtual onlyOwner {
        ERC20 token = ERC20(_token);
        uint256 balance = ERC20(_token).balanceOf(address(this));
        SafeTransferLib.safeTransfer(token, owner(), balance);
    }

    ///@notice Withdraw tokens from contract address. OnlyOwner.
    ///@param _token ERC721 smart contract address
    function withdrawERC721(address _token, uint256 tokenId)
        external
        virtual
        onlyOwner
    {
        ERC721 token = ERC721(_token);
        token.transferFrom(address(this), owner(), tokenId);
    }
}
