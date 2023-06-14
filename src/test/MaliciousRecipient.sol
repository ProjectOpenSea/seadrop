// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RaribleDrop } from "../RaribleDrop.sol";

contract MaliciousRecipient {
    bool public startAttack;
    address public token;
    RaribleDrop public raribleDrop;

    receive() external payable {
        if (startAttack) {
            startAttack = false;
            raribleDrop.mintPublic{ value: 1 ether }({
                nftContract: token,
                feeRecipient: address(this),
                minterIfNotPayer: address(this),
                quantity: 1
            });
        }
    }

    // Also receive some eth in the process
    function setStartAttack() public payable {
        startAttack = true;
    }

    function attack(RaribleDrop _raribleDrop, address _token) external payable {
        token = _token;
        raribleDrop = _raribleDrop;

        _raribleDrop.mintPublic{ value: 1 ether }({
            nftContract: _token,
            feeRecipient: address(this),
            minterIfNotPayer: address(this),
            quantity: 1
        });

        token = address(0);
        raribleDrop = RaribleDrop(address(0));
    }
}
