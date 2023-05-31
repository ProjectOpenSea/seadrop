// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1155SeaDrop } from "../ERC1155SeaDrop.sol";

contract ERC1155SeaDropWithBatchMint is ERC1155SeaDrop {
    constructor(
        string memory name_,
        string memory symbol_,
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport
    )
        ERC1155SeaDrop(
            name_,
            symbol_,
            allowedConfigurer,
            allowedConduit,
            allowedSeaport
        )
    {}

    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external {
        _batchMint(to, ids, amounts, data);
    }
}
