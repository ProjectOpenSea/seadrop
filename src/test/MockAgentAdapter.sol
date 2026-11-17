// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { IAgentAdapter } from "../interfaces/IAgentAdapter.sol";

interface IOwnerOf {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @dev An ERC-8217 adapter stand-in with the real adapter's registration
 *      rule for ERC-721 tokens: the token contract itself can register a
 *      token while `ownerOf` reverts or returns the zero address, and
 *      otherwise only the token's holder can. Like the real adapter, it
 *      does not stop a token from being registered twice.
 */
contract MockAgentAdapter is IAgentAdapter {
    struct Binding {
        address boundAddress;
        uint256 tokenId;
        string agentURI;
    }

    error UnsupportedStandard(uint8 standard);
    error NotController(address account);

    uint256 public nextAgentId = 1;

    uint256 public registrations;

    mapping(uint256 => Binding) public bindings;

    function register(
        uint8 standard,
        address boundAddress,
        uint256 tokenId,
        string calldata agentURI
    ) external returns (uint256 agentId) {
        if (standard != 0) {
            revert UnsupportedStandard(standard);
        }

        (bool success, bytes memory result) = boundAddress.staticcall(
            abi.encodeCall(IOwnerOf.ownerOf, (tokenId))
        );
        address owner = success ? abi.decode(result, (address)) : address(0);

        bool contractPath = msg.sender == boundAddress && owner == address(0);
        if (!contractPath && (owner == address(0) || msg.sender != owner)) {
            revert NotController(msg.sender);
        }

        agentId = nextAgentId++;
        ++registrations;
        bindings[agentId] = Binding(boundAddress, tokenId, agentURI);
    }

    /// @dev Whether `account` controls `agentId`: the bound token's holder.
    function isController(uint256 agentId, address account)
        external
        view
        returns (bool)
    {
        Binding storage binding = bindings[agentId];
        return
            IOwnerOf(binding.boundAddress).ownerOf(binding.tokenId) == account;
    }
}
