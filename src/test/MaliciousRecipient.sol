// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.16;

import { ISeaDrop } from "../SeaDrop.sol";

contract MaliciousRecipient {
    bool public startAttack;
    address public token;
    ISeaDrop public seaDrop;

    receive() external payable {
        if (startAttack) {
            startAttack = false;
            seaDrop.mintPublic{ value: 1 ether }({
                nftContract: token,
                feeRecipient: address(this),
                minterIfNotPayer: address(this),
                quantity: 1
            });
        }
    }

    // Call `attack` with at least 2 ether.
    function attack(ISeaDrop _seaDrop, address _token) external payable {
        token = _token;
        seaDrop = _seaDrop;
        startAttack = true;

        _seaDrop.mintPublic{ value: 1 ether }({
            nftContract: _token,
            feeRecipient: address(this),
            minterIfNotPayer: address(this),
            quantity: 1
        });

        token = address(0);
        seaDrop = ISeaDrop(address(0));
    }
}
