// SPDX-License-Identifier: MIT
pragma solidity 0.8.38;

import { ERC721SeaDrop } from "../ERC721SeaDrop.sol";

import { ERC8048OnchainMetadata } from "../lib/ERC8048OnchainMetadata.sol";

import { IAgentAdapter } from "../interfaces/IAgentAdapter.sol";

import { IERC8048Metadata } from "../interfaces/IERC8048Metadata.sol";

import {
    IERC8048TokenMetadataAuthority
} from "../interfaces/IERC8048TokenMetadataAuthority.sol";

/**
 * @title  ERC721SeaDropAgents
 * @author Ryan Ghods (ralxz.eth)
 * @notice ERC721SeaDrop for tokens that are AI agents. It adds:
 *
 *         - Agent registration. The owner registers an ERC-8004 agent for
 *           each token before it is minted, through an ERC-8217 adapter, so
 *           every token is minted with its agent. Whoever holds the token
 *           controls the agent.
 *         - ERC-8048 onchain metadata, for agent records such as the
 *           ERC-721T profile's `context` and `endpoint[mcp]` keys, with
 *           ERC-8048's Metadata Authority extension. See
 *           ERC8048OnchainMetadata for who can write them.
 *
 *         tokenURI works as in ERC721SeaDrop, and marketplaces read the
 *         token's JSON from it as usual.
 */
contract ERC721SeaDropAgents is ERC721SeaDrop, ERC8048OnchainMetadata {
    /// @dev The ERC-8217 adapter agents are registered through, or the
    ///      zero address on a chain without one.
    address internal immutable _AGENT_ADAPTER;

    /// @dev The agent id registered for each token, plus one, so zero means
    ///      none.
    mapping(uint256 => uint256) private _agentIdsPlusOne;

    /// @notice Emitted when a token's metadata changes (ERC-4906).
    event MetadataUpdate(uint256 _tokenId);

    /// @notice Revert when registering agents without an adapter.
    error AgentAdapterNotSet();

    /// @notice Revert when the token id range to register is empty, starts
    ///         at a token that was already minted, or ends past the max
    ///         supply.
    error InvalidAgentTokenIdRange(uint256 firstTokenId, uint256 lastTokenId);

    /**
     * @notice Deploy the token contract with its name, symbol, allowed
     *         SeaDrop addresses, and agent adapter.
     *
     * @param name           The name of the token.
     * @param symbol         The symbol of the token.
     * @param allowedSeaDrop The allowed SeaDrop addresses.
     * @param adapter        The ERC-8217 adapter to register agents
     *                       through, or the zero address on a chain without
     *                       one. Registration reverts without an adapter.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory allowedSeaDrop,
        address adapter
    ) ERC721SeaDrop(name, symbol, allowedSeaDrop) {
        _AGENT_ADAPTER = adapter;
    }

    /**
     * @notice Returns the ERC-8217 adapter agents are registered through.
     */
    function agentAdapter() external view returns (address) {
        return _AGENT_ADAPTER;
    }

    /**
     * @notice Returns the agent the owner registered for `tokenId`, if any.
     *         An agent the holder registers through the adapter directly
     *         after mint is not tracked here.
     *
     * @param tokenId The token id.
     *
     * @return registered Whether an agent is registered for the token.
     * @return agentId    The agent's id in the ERC-8004 registry.
     */
    function agentOf(uint256 tokenId)
        external
        view
        returns (bool registered, uint256 agentId)
    {
        uint256 agentIdPlusOne = _agentIdsPlusOne[tokenId];
        if (agentIdPlusOne != 0) {
            registered = true;
            unchecked {
                agentId = agentIdPlusOne - 1;
            }
        }
    }

    /**
     * @notice Register an ERC-8004 agent for each token id from
     *         `firstTokenId` to `lastTokenId`, with the agent URI
     *         `prefix` + token id + `suffix`. Only the owner can call this,
     *         and only for tokens not minted yet, since the adapter lets a
     *         token contract register only tokens without an owner. Tokens
     *         already registered here are skipped, so a failed batch can be
     *         sent again.
     *
     *         Each registration mints an identity in the ERC-8004 registry,
     *         so large ranges need several transactions.
     *
     * @param firstTokenId The first token id to register.
     * @param lastTokenId  The last token id to register.
     * @param prefix       The agent URI before the token id.
     * @param suffix       The agent URI after the token id.
     */
    function registerAgents(
        uint256 firstTokenId,
        uint256 lastTokenId,
        string calldata prefix,
        string calldata suffix
    ) external onlyOwner {
        address adapter = _AGENT_ADAPTER;
        if (adapter == address(0)) revert AgentAdapterNotSet();

        if (
            firstTokenId < _nextTokenId() || lastTokenId < firstTokenId
                || lastTokenId > maxSupply()
        ) {
            revert InvalidAgentTokenIdRange(firstTokenId, lastTokenId);
        }

        for (uint256 tokenId = firstTokenId; tokenId <= lastTokenId; ++tokenId) {
            if (_agentIdsPlusOne[tokenId] != 0) continue;

            uint256 agentId = IAgentAdapter(adapter)
                .register(
                    0, // ERC-721
                    address(this),
                    tokenId,
                    string.concat(prefix, _toString(tokenId), suffix)
                );
            _agentIdsPlusOne[tokenId] = agentId + 1;
        }
    }

    /**
     * @notice Returns whether the interface is supported.
     *
     * @param interfaceId The interface id to check against.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC8048Metadata).interfaceId
            || interfaceId == type(IERC8048TokenMetadataAuthority).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev The owner is the metadata admin.
     */
    function _isMetadataAdmin(address account)
        internal
        view
        virtual
        override
        returns (bool)
    {
        return account == owner();
    }

    /**
     * @dev Emit ERC-4906 `MetadataUpdate` for a token that exists, from mint
     *      until burn.
     */
    function _emitMetadataUpdate(uint256 tokenId) internal virtual override {
        if (_exists(tokenId)) {
            emit MetadataUpdate(tokenId);
        }
    }

    /**
     * @dev A token's holder is its owner, from mint until burn.
     */
    function _metadataHolderOf(uint256 tokenId)
        internal
        view
        virtual
        override
        returns (address)
    {
        return _exists(tokenId) ? ownerOf(tokenId) : address(0);
    }
}
