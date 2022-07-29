// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721ContractMetadata } from "./IContractMetadata.sol";

interface IERC721Drop is IERC721ContractMetadata {
    event PublicDropUpdated(PublicDrop indexed newPublicDrop);
    event DropURIUpdated(string newDropURI);

    // designed to take up 1 storage slot - 248 bits total
    struct PublicDrop {
        // whether mint is part of allowlist - can be used to disqualify future allowlist mints
        bool allowList; // 8/256 bits
        // up to 1.2m of native token, eg: ETH, MATIC
        uint80 mintPrice; // 88/256 bits
        // when drop stage starts being active
        uint64 startTime; // 152/256 bits
        // when drop stage stops being active
        uint64 endTime; // 216/256 bits
        // maximum number of mints for this drop stage
        uint16 maxNumberMinted; // 232/256 bits
        // fee out of 10,000 basis points that we will collect - TBD?
        uint16 feeBps; // 248/256 bits
    }

    function getPublicDrop() external view returns (PublicDrop memory);

    function setPublicDrop(PublicDrop calldata newPublicDrop) external;

    // return JSON of drop information for marketplaces to consume
    function dropURI() external view returns (string memory);

    function setDropURI(string memory dropURI) external;
}
