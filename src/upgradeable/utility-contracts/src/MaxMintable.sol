// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import {TwoStepOwnable} from "./TwoStepOwnable.sol";

///@notice Ownable contract with restrictions on how many times an address can mint
abstract contract MaxMintable is TwoStepOwnable {
    uint256 public maxMintsPerWallet;

    error MaxMintedForWallet();

    constructor(uint256 _maxMintsPerWallet) {
        maxMintsPerWallet = _maxMintsPerWallet;
    }

    modifier checkMaxMintedForWallet(uint256 quantity) {
        uint256 numMinted = _numberMinted(msg.sender);
        if (numMinted + quantity > maxMintsPerWallet) {
            revert MaxMintedForWallet();
        }
        _;
    }

    ///@notice set maxMintsPerWallet. OnlyOwner
    function setMaxMintsPerWallet(uint256 maxMints) public onlyOwner {
        maxMintsPerWallet = maxMints;
    }

    function _numberMinted(address minter) internal virtual returns (uint256);
}
