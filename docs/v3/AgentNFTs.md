# Agent NFTs on v3

`src/v3/extensions/ERC721SeaDropV3Agents.sol` is the v3 version of SeaDrop's agent NFT extension ([ProjectOpenSea/seadrop#212](https://github.com/ProjectOpenSea/seadrop/pull/212) on v1). It is `ERC721SeaDropV3` plus:

- Agent registration. The owner registers an [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004) agent for each token before it mints, through an [ERC-8217](https://eips.ethereum.org/EIPS/eip-8217) adapter, with `registerAgents(firstTokenId, lastTokenId, prefix, suffix)`. Whoever holds the token controls the agent. `agentOf(tokenId)` returns the agent id.
- [ERC-8048](https://github.com/ethereum/ERCs/blob/master/ERCS/erc-8048.md) onchain metadata with its collection-wide Metadata Authority extension, from `src/v3/lib/ERC8048OnchainMetadata.sol`.

## Deployment

The factory deploys only the default v3 tokens. Extensions such as this one are standalone contracts the creator deploys:

```solidity
new ERC721SeaDropV3Agents(name, symbol, seaDropMinter, conduit, adapter, initialOwner);
```

The initial owner administers the token, and the chain's `SeaDropMinter` is its first allowed minter. `conduit` is the conduit every holder's tokens are approved for until the holder revokes it (OpenSea's conduit for the chain, or the zero address for none). `adapter` is the chain's ERC-8217 adapter, or the zero address on a chain without one, where `registerAgents` reverts. `initialize` always reverts, since the constructor already did its work.

The minter mints a standalone token the same way it mints a clone. The minter's `tokenFactoryOf` stays zero for it, since no factory registered it.

Set the max supply before registering. Registration covers only tokens not minted yet, up to the last token id that can mint, since the adapter lets a token contract register only tokens without an owner.

## Who can write metadata

`tokenMetadataAuthority()` returns the one address that can write every token's records, or the zero address when none is set. The token answers `supportsInterface(0x04f90b41)`.

- While the authority is set, it is the only writer. It can be an account or a policy contract such as `src/v3/lib/MetadataWriterPolicy.sol`.
- While the authority is blank, three settings decide, which `collectionAuthoritySettings()` returns. The owner writes any token unless `ownerCannotWrite` is on. With `holderCanWrite`, a token's current holder writes that token. With `authorityLocked`, nobody can change the settings or set an authority again.
- A set authority can be locked too. Then the owner can't replace it, and only the authority can hand itself on.

`setCollectionAuthority(authority, holderCanWrite, ownerCannotWrite, authorityLocked)` sets everything. It emits `TokenMetadataAuthoritySet(authority)` when the authority changes and `CollectionAuthoritySettingsUpdated` every time. The settings start false, so a new token is owner-only. The v1 doc, `docs/AgentNFTs.md` on `main`, walks through the setups and the reference policy, and they work the same here.

## Storage

Like the rest of v3, this contract's state is in ERC-7201 namespaced storage: `seadrop.v3.ERC8048OnchainMetadata` for records and the authority (`0xfc7a356b7c4fc14ef0fb4888fa6feb6db813951f1163492fbc23ac5c95c77600`) and `seadrop.v3.ERC721SeaDropV3Agents` for agent ids (`0x81d23eda6b422c7dfc16f0a75c57549cf4ff057c8b7855458b38a2f38fc85900`). `testStorageSlots` checks both.

The writer policy constructor takes the token address and the initial policy administrator.
