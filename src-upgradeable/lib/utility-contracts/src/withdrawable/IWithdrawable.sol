// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

///@notice Ownable helper contract to withdraw ether or tokens from the contract address balance
interface IWithdrawable {
    function withdraw() external;

    function withdrawERC20(address _tokenAddress) external;

    function withdrawERC721(address _tokenAddress, uint256 tokenId) external;
}
