// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1155SeaDrop } from "../ERC1155SeaDrop.sol";

contract ERC1155SeaDropWithBatchMint is ERC1155SeaDrop {
    constructor(
        address allowedConfigurer,
        address allowedConduit,
        address allowedSeaport,
        string memory name_,
        string memory symbol_
    )
        ERC1155SeaDrop(
            allowedConfigurer,
            allowedConduit,
            allowedSeaport,
            name_,
            symbol_
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
