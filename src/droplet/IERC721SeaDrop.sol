// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721ContractMetadata } from "../interfaces/IContractMetadata.sol";
import { PublicDrop, AllowListMint, AllowListData } from "./SeaDropStructs.sol";

interface IERC721SeaDrop is IERC721ContractMetadata {
    // doing `maxMintsPerWallet` check here may be cheaper
    function mintSeaDrop(address minter, uint256 amount) external payable;

    // to enforce maxMintsPerWallet checks - should SeaDrop track this?
    function numberMinted(address seaDropImpl, address minter)
        external
        view
        returns (uint256);

    // These methods can all consist of a single line: seaDropImpl.updateFunction(params);

    function updatePublicDrop(
        address seaDropImpl,
        PublicDrop calldata publicDrop
    ) external;

    function updateAllowList(
        address seaDropImpl,
        AllowListData calldata allowListData
    ) external;

    function updateDropURI(address seaDropImpl, string calldata dropURI)
        external;

    function updateCreatorPayoutAddress(address payoutAddress) external;

    function updateAllowedFeeRecipient(address feeRecipient, bool allowed)
        external;
}
