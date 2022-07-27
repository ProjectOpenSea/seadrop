// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {ERC721A} from "./token/ERC721A.sol";
import {MaxMintable} from "utility-contracts/MaxMintable.sol";
import {DropEventsAndErrors} from "./DropEventsAndErrors.sol";
import {TwoStepAdministered, TwoStepOwnable} from "utility-contracts/TwoStepAdministered.sol";
import {AllowList} from "utility-contracts/AllowList.sol";

contract Drop is
    ERC721A,
    TwoStepAdministered,
    MaxMintable,
    DropEventsAndErrors
{
    bytes32 public merkleRoot;
    address internal commissionAddress;
    address internal payoutAddress;
    DropStage public dropStage;

    struct DropStage {
        uint32 startTimestamp;
        uint32 endTimestamp;
        uint80 mintPrice;
        uint80 allowListMintPrice;
        uint16 mintLimit;
        uint16 commissionBps;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxNumMintable,
        address administrator
    )
        ERC721A(name, symbol)
        MaxMintable(maxNumMintable)
        TwoStepAdministered(administrator)
    {}

    function setMerkleRoot(bytes32 newMerkleRoot) public onlyAdministrator {
        merkleRoot = newMerkleRoot;
    }

    function _numberMinted(address minter)
        internal
        view
        virtual
        override(MaxMintable, ERC721A)
        returns (uint256)
    {
        return ERC721A._numberMinted(minter);
    }

    function _mint(
        address to,
        uint256 amount,
        DropStage memory dropStage
    ) internal {
        // The Tai Lopez

        _mint(to, amount);
    }
}
