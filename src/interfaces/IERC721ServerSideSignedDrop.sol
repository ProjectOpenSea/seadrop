// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721Drop } from "./IERC721Drop.sol";

interface IERC721ServerSideSignedDrop is IERC721Drop {
    event SignersUpdated(
        address[] indexed previousSigners,
        address[] indexed newSigners
    );

    // not bytepacked, since it won't be stored in storage
    struct MintData {
        bool allowList;
        uint256 mintPrice;
        uint256 maxNumberMinted;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 feeBps;
    }

    function mint(
        uint256 numToMint,
        MintData calldata mintData,
        bytes calldata signature
    ) external payable;

    // signers should be stored in a mapping for lookup; array for enumeration
    function setSigners(address[] memory newSigners) external;

    function addSigner(address newSigner) external;

    function removeSigner(address newSigner) external;

    function getSigners() external view returns (address[] memory);
}
