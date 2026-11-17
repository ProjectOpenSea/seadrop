// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

/**
 * @title  IAgentAdapter
 * @notice The registration call of an ERC-8217 adapter for ERC-8004 agent
 *         identities. The adapter mints an identity in the ERC-8004
 *         registry and binds it to a token for good. Whoever holds the
 *         token then controls the agent.
 *
 *         A token contract can register one of its own ERC-721 tokens
 *         while `ownerOf` reverts or returns the zero address for it. After
 *         the token is minted, only its holder or the holder's delegate
 *         can register it. The adapter does not stop a token from being
 *         registered twice.
 */
interface IAgentAdapter {
    /**
     * @notice Registers a new ERC-8004 agent bound to `tokenId` of
     *         `boundAddress`.
     *
     * @param standard     The bound token's standard. 0 is ERC-721.
     * @param boundAddress The token contract.
     * @param tokenId      The token id.
     * @param agentURI     The agent's registration file URI.
     *
     * @return agentId The new agent's id in the ERC-8004 registry.
     */
    function register(
        uint8 standard,
        address boundAddress,
        uint256 tokenId,
        string calldata agentURI
    ) external returns (uint256 agentId);
}
