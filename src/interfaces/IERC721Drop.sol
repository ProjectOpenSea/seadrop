// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721ContractMetadata } from "./IContractMetadata.sol";

interface IERC721Drop is IERC721ContractMetadata {
    event PublicDropUpdated(PublicDrop indexed newPublicDrop);
    event DropURIUpdated(string newDropURI);

    // designed to take up 1 storage slot - 248 bits total
    struct PublicDrop {
        // up to 1.2m of native token, eg: ETH, MATIC
        uint80 mintPrice; //80/256 bits
        // when drop stage starts being active
        uint64 startTime; // 144/256 bits
        // when drop stage stops being active
        uint64 endTime; // 208/256 bits
        // maximum number of mints for the public drop
        uint16 maxMintsPerWallet; // 224/256 bits
        // maxmium number of mints per transaction for the public drop
        uint16 maxMintsPerTransation; // 240/256 bits
        // fee out of 10,000 basis points that we will collect - TBD?
        uint16 feeBps; // 256/256 bits
    }

    /// @notice Returns the address of the token used for the sale; returns address(0) if native token
    function saleToken() external view returns (address);

    function getPublicDrop() external view returns (PublicDrop memory);

    function setPublicDrop(PublicDrop calldata newPublicDrop) external;

    // return JSON of drop information for marketplaces to consume
    function dropURI() external view returns (string memory);

    function setDropURI(string memory dropURI) external;

    function publicMint(uint256 amount) external payable;

    function publicMint(uint256 option, uint256 amount) external payable;
}
