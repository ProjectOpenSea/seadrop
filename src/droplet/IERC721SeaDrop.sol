// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721ContractMetadata } from "../interfaces/IContractMetadata.sol";
import { PublicDrop, AllowListMint, AllowListData } from "./SeaDropStructs.sol";

interface IERC721SeaDrop is IERC721ContractMetadata {
    function getSeaDrop() external view returns (address);

    // doing `maxMintsPerWallet` check here may be cheaper
    function mintSeaDrop(address minter, uint256 amount) external payable;

    // These methods can all consist of a single line: seaDrop.updateFunction(params);

    function updatePublicDrop(PublicDrop calldata publicDrop) external;

    function updateAllowList(AllowListData calldata allowListData) external;

    function updateSaleToken(address saleToken) external;

    function updateDropURI(string calldata dropURI) external;

    // if SeaDrop should verify `maxNumberMinted`, it will probably need this
    function numberMinted(address minter) external view returns (uint256);
}
