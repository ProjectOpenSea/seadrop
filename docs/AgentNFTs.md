# Agent NFTs

`ERC721SeaDropAgents` (in `src/extensions`) is `ERC721SeaDrop` for collections whose tokens are AI agents. It adds two things:
- Agent registration. The owner registers an [ERC-8004](https://eips.ethereum.org/EIPS/eip-8004) agent for each token before it mints, through an [ERC-8217](https://eips.ethereum.org/EIPS/eip-8217) adapter. Whoever holds the token controls its agent.
- Onchain metadata under [ERC-8048](https://eips.ethereum.org/EIPS/eip-8048): string keys with bytes values, stored per token, with ERC-8048's Metadata Authority extension. The ERC-8048 code lives in `src/lib/ERC8048OnchainMetadata.sol`, so other token contracts can reuse it.

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

The contract's runtime code is about 23.5 KB, about 1 KB under the EIP-170 limit, so a contract that inherits it has little room to add code.

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
- It only works for tokens that are not minted yet. The adapter lets a token contract register a token only while the token has no owner. Set the max supply first, since the range can't go past it.
- Tokens already registered are skipped, so you can send a range again after a failed transaction. The adapter itself doesn't stop a token from being registered twice.
- Each registration mints an identity in the ERC-8004 registry. On Base it costs about 220,000 gas per token, so register a large collection over several transactions.

After a token mints, its holder controls the agent in the adapter. They can change the agent URI or set the agent's wallet there. A holder can also register a token the owner didn't register by calling the adapter directly. `agentOf` only tracks agents registered through `registerAgents`.

The agent URI should point to an ERC-8004 registration file, the JSON whose `type` is `https://eips.ethereum.org/EIPS/eip-8004#registration-v1`. Keep that `type` out of the token's own `tokenURI` JSON. OpenSea reads the agent card from the registration file only.

## Onchain metadata

Anyone can read a token's records with `metadata(tokenId, key)`. Writing them works like this:
- While a token has no metadata authority, the owner and the metadata writers the owner allows (`setMetadataWriter`) can write its records. A writer can't call any other owner function, so a hot wallet can run a metadata job. Records can be written before a token mints.
- The token's holder can set a metadata authority for it at any time with `setMetadataAuthority`, usually themself or their agent's wallet. While a token has an authority, only that authority can write its records, and the owner and writers can't.
- The authority can hand the role to another address or clear it. Clearing it returns the token to the owner and writers.
- A transfer or burn clears the authority, so a seller's authority never carries over to the buyer.
- `lockMetadataKey(key)` locks a key for every token, for good. After that nobody can write it, authorities included. Only the owner can lock a key.

`setMetadataBatch` writes many records in one transaction. Every write emits ERC-8048's `MetadataSet` and ERC-4906's `MetadataUpdate`.

The contract doesn't fix any keys. ERC-8048's agent profile (nicknamed ERC-721T) reserves these:

| Key                            | Value                                                   |
| ------------------------------ | ------------------------------------------------------- |
| `context`                      | The agent's context as UTF-8 text, Markdown suggested   |
| `endpoint[<type>]`             | A URI, for types such as `mcp`, `a2a`, `web` and `x402` |
| `address[<chain-id>]`          | The agent's account on a chain, as raw address bytes    |
| `account[<chain-id>][<index>]` | An additional account on a chain                        |

`<chain-id>` is an ERC-7930 chain identifier, such as `0x00010000010100` for Ethereum. ERC-8048 is a draft and its agent profile may still change, so check the current text before you pick keys. Keys are case sensitive.

Token id 0 is not special. Put collection-level data in the contract URI.

## How OpenSea shows agent NFTs

- The NFT's page shows that the token is bound to an agent, from the adapter's `AgentBound` event.
- The agent card shows on the agent's identity item in the ERC-8004 registry, read from the agent URI.
- OpenSea doesn't read ERC-8048 records. Anything OpenSea should show, such as the name, image and traits, goes in the `tokenURI` JSON.
- OpenSea refreshes a token's metadata when it sees an ERC-4906 event, and every record write emits one.
- Agents created with the adapter's `counterfactualRegister` are not indexed.
