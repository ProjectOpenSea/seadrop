# Agent NFTs

`ERC721SeaDropAgents` (in `src/extensions`) is `ERC721SeaDrop` for collections whose tokens are AI agents. It adds two things:

- Agent registration. The owner registers an [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004) agent for each token before it mints, through an [ERC-8217](https://eips.ethereum.org/EIPS/eip-8217) adapter. Whoever holds the token controls its agent.
- Onchain metadata under [ERC-8048](https://eips.ethereum.org/EIPS/eip-8048): string keys with bytes values, stored per token, with ERC-8048's Metadata Authority extension deciding who can write them. The ERC-8048 code lives in `src/lib/ERC8048OnchainMetadata.sol`, so other token contracts can reuse it, including ones that already implement ERC-4906.

Minting, drop configuration and `tokenURI` work as in `ERC721SeaDrop`.

## Deploy

The constructor takes the usual name, symbol and allowed SeaDrop addresses, plus the adapter to register agents through:

| Network         | ERC-8217 adapter                             |
| --------------- | -------------------------------------------- |
| Ethereum        | `0xde152afb7db5373f34876e1499fbd893a82dd336` |
| Base            | `0x270d25d2c59a8bca1b0f40ad95ff7806c0025c27` |
| Robinhood Chain | `0x000000009d62675362a58911e3f32fecf46f5e18` |
| Sepolia         | `0x7621630cb63a73a194f45a3e6801b8c6a7ec2f92` |

On a network without an adapter, pass the zero address. Registration then reverts with `AgentAdapterNotSet`, and onchain metadata still works.

The adapters are upgradeable proxies. On Ethereum and Base a 3-of-4 Safe controls their upgrades, so the bindings between tokens and agents rely on that Safe.

The contract's runtime code is about 23.4 KB, about 1.2 KB under the EIP-170 limit, so a contract that inherits it has little room to add code.

## Register agents

```solidity
function registerAgents(
    uint256 firstTokenId,
    uint256 lastTokenId,
    string calldata prefix,
    string calldata suffix
) external;
```

`registerAgents` registers one agent per token id from `firstTokenId` to `lastTokenId`. Each agent's URI is `prefix`, then the token id, then `suffix`, for example `https://example.com/agents/` and `.json`. `agentOf(tokenId)` returns the agent id.

- Only the owner can call it.
- It only works for tokens that are not minted yet. The adapter lets a token contract register a token only while the token has no owner. Set the max supply first, since the range can't go past the last token id that can mint.
- Tokens already registered are skipped, so overlapping ranges, or a range sent again after earlier transactions registered part of it, don't register a token twice. The adapter itself doesn't stop a token from being registered twice.
- Each registration mints an identity in the ERC-8004 registry. That costs about 200,000 gas per token, or about 240,000 once the agent URI is longer than 31 bytes. Ethereum and Base cap a transaction at 16,777,216 gas (EIP-7825), so register about 60 tokens per transaction, fewer with long URIs.
- Nobody can change an agent URI before its token mints, the owner included, and sending the range again skips it. Check the prefix and suffix before you register, and use URIs whose content you control.
- Agent URIs are public once registered. For a delayed reveal, keep anything that gives the reveal away out of the registration files until then.

After a token mints, its holder controls the agent in the adapter. They can change the agent URI or set the agent's wallet there. A holder can also register a token the owner didn't register by calling the adapter directly. `agentOf` only tracks agents registered through `registerAgents`. Once a token is burned, nobody controls its agent.

The agent's URI and wallet stay as they are when the token is sold. A buyer should set both again through the adapter after buying, or payments sent to the agent's wallet keep reaching the seller.

The agent URI should point to an ERC-8004 registration file, the JSON whose `type` is `https://eips.ethereum.org/EIPS/eip-8004#registration-v1`. Keep that `type` out of the token's own `tokenURI` JSON. OpenSea reads the agent card from the registration file only.

## Onchain metadata

Anyone can read a token's records with `metadata(tokenId, key)`.

### Who can write

The contract implements [ERC-8048](https://github.com/ethereum/ERCs/blob/master/ERCS/erc-8048.md)'s optional Metadata Authority extension (interface id `0x04f90b41`). `tokenMetadataAuthority()` returns the one address that can write every token's records, or the zero address when none is set.

- While the authority is set, it is the only writer, for every token, including before a token mints. It can be an account or a policy contract that applies its own rules. The owner and holders write only through it.
- While the authority is blank, three settings decide who writes. `collectionAuthoritySettings()` returns them.
  - The owner writes any token's records, unless `ownerCannotWrite` is on.
  - With `holderCanWrite`, a token's current holder also writes that token's records. The contract checks `ownerOf` at write time, so after a transfer the new holder can write right away and the old holder can't. ERC-721 operators can't write for the holder.
  - With `authorityLocked`, nobody can change the settings or set an authority again, the owner included.
- A set authority can also be locked. Then the owner can't replace it, and only the authority can hand itself on, including to a locked blank state.

`setCollectionAuthority(authority, holderCanWrite, ownerCannotWrite, authorityLocked)` sets the authority and all three settings. The owner can call it until the settings are locked, and a set authority can always call it. It emits `TokenMetadataAuthoritySet(authority)` when the authority changes and `CollectionAuthoritySettingsUpdated` every time. The settings all start false, so a new collection starts with the owner as the only writer. A blank authority follows ownership, so a new owner takes over writing when the contract changes owners.

### Common setups

- Owner only. Leave the authority blank and the settings false, the default. The owner writes and can change the settings.
- Owner and holders. Leave the authority blank and set `holderCanWrite`. The owner writes any token, each holder writes their own, and the owner can change the settings.
- Locked blank. Leave the authority blank and set `authorityLocked`. The other two settings decide who writes for good: the owner and holders, the owner only, holders only (with `ownerCannotWrite`), or nobody (with `ownerCannotWrite` and without `holderCanWrite`), which freezes every record, including for tokens that mint later. Nobody can change the settings or add a policy.
- A policy. Set a policy contract as the authority. Only the policy writes, and the owner can replace it.
- A locked policy. Do the same and set `authorityLocked`. Only the policy writes, the owner can't replace it, and only the policy can hand the authority on.

When holders can write, a seller can change their token's records up to the moment of sale, so a buyer should check them after buying. In the other setups holders write only through a policy's rules, if at all.

### Reference policy

`src/lib/MetadataWriterPolicy.sol` is a small policy contract to set as the metadata authority. The contract doesn't need it, and it shows what a policy can do. Its owner (the admin) can allow several writer addresses with `setWriter`, such as a hot wallet that runs a metadata job. A writer can write records and nothing else. A token's current holder can delegate their token's writes to one address with `setDelegate`, such as their agent's wallet. A delegation counts only while the holder who set it still holds the token, so it lapses on transfer. It counts again if the token comes back to that holder.

Writers and delegates call the policy's `setMetadata` and `setMetadataBatch`, which check the caller and forward the write to the token. The admin can also call `setCollectionAuthority` through the policy, for example to hand the authority to a new policy.

### Freezing records

The contract has no key locks. A lock on a key would also freeze it for tokens that haven't minted yet, so an artist who signed the first tokens and then locked `artist.signature` would leave every later token without a signature. Freezing is up to a policy set as the authority instead, which can freeze per token.

The reference policy shows one way. Its admin can mark a key write-once with `setWriteOnceKey(key, true)`. A write to a write-once key through the policy reverts with `WriteOnceValueSet` once that token has a non-empty value for the key, in `setMetadata` and `setMetadataBatch` alike, counting earlier entries in the same batch. An artist can sign tokens 1 and 2, and token 3 can still be signed once after it mints, but nobody can overwrite the signatures on tokens 1 and 2.

The admin can unmark a key, and the owner can replace an unlocked policy. For a freeze that holds, set the policy as the authority with `authorityLocked`, then renounce the policy's ownership. While the policy has an admin, that admin can still unmark keys. To freeze every record instead, lock a blank authority with `ownerCannotWrite` on and `holderCanWrite` off, as described above.

### Batches

`setMetadataBatch` writes many records in one transaction. If the caller can't write any one entry, the whole batch reverts. A set authority, or the owner while the authority is blank, can write every entry.

### Events and keys

Every write emits ERC-8048's `MetadataSet`. A write to a minted token also emits ERC-4906's `MetadataUpdate`. Writes before mint don't, since marketplaces read a token's metadata when it mints.

The contract doesn't fix any keys. ERC-8048's agent profile (nicknamed ERC-721T) reserves these:

| Key                            | Value                                                          |
| ------------------------------ | -------------------------------------------------------------- |
| `context`                      | The agent's context as UTF-8 text, Markdown suggested          |
| `endpoint[<type>]`             | A URI, for types such as `mcp`, `a2a`, `ens`, `web` and `x402` |
| `address[<chain-id>]`          | The agent's account on a chain, as raw address bytes           |
| `account[<chain-id>][<index>]` | An additional account on a chain                               |

`<chain-id>` is an ERC-7930 chain identifier, such as `0x00010000010100` for Ethereum. ERC-8048 is a draft and its agent profile may still change, so check the current text before you pick keys. Keys are case sensitive.

Token id 0 is not special. Put collection-level data in the contract URI.

## How OpenSea shows agent NFTs

- The NFT's page shows that the token is bound to an agent, from the adapter's `AgentBound` event.
- The agent card shows on the agent's identity item in the ERC-8004 registry, read from the agent URI.
- OpenSea doesn't read ERC-8048 records. Anything OpenSea should show, such as the name, image and traits, goes in the `tokenURI` JSON. Don't copy agent keys such as `context` or `endpoint[mcp]` into that JSON: ERC-8495, the draft standard for `tokenURI` JSON, asks for field names of lowercase letters, digits and underscores that won't collide with future extensions.
- OpenSea refreshes a token's metadata when it sees an ERC-4906 event, and every record write to a minted token emits one.
- Agents created with the adapter's `counterfactualRegister` are not indexed.
