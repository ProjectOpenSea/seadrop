# Deployments

The v1 and v2 tables list contracts with the same address on every network where they are deployed. The [v3 QA deployments](#base-mainnet-v3-qa-deployments) are specific to Base.

## What OpenSea uses

OpenSea uses SeaDrop v1 for new ERC-721 drops. OpenSea deploys each drop as a clone of `ERC721SeaDropCloneable` through `ERC721SeaDropCloneFactory`, or as a standalone `ERC721SeaDrop`, and mints go through the shared `SeaDrop` contract.

SeaDrop v2 currently powers ERC-1155 open collections on OpenSea, which the collection owner mints. OpenSea deploys each one as a clone through `ERC1155SeaDropCloneFactory`, and the owner mints through the token's configurer. Earlier v2 ERC-1155 drops, whose public mints fill [Seaport 1.6](https://github.com/ProjectOpenSea/seaport) orders with the token as a contract offerer, are still live, but OpenSea no longer creates them.

OpenSea doesn't create v2 ERC-721 tokens, upgradeable SeaDrop tokens, or standalone ERC-1155 tokens. It still indexes v2 ERC-721 tokens and the drops created by the legacy factories below.

SeaDrop v3 is in development. The [version table](../README.md#versions) lists the planned OpenSea use cases.

## Contracts

| Contract                                           | Version | Address                                                                                                                      |
| -------------------------------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `SeaDrop`                                          | v1      | [`0x00005EA00Ac477B1030CE78506496e8C2dE24bf5`](https://etherscan.io/address/0x00005EA00Ac477B1030CE78506496e8C2dE24bf5#code) |
| `SeaDrop` on GUNZ, Somnia and MegaETH              | v1      | `0x00005ea12886e54be34e2cc57d095c25e492f8ca`                                                                                 |
| `ERC721SeaDropCloneFactory`                        | v1      | [`0x008EbCCaE39d001200c3003c3225ce0A00690066`](https://etherscan.io/address/0x008EbCCaE39d001200c3003c3225ce0A00690066#code) |
| `ERC1155SeaDropCloneFactory`                       | v2      | [`0x00b19A5200A100e5fc4c9800772f4d002f218400`](https://etherscan.io/address/0x00b19A5200A100e5fc4c9800772f4d002f218400#code) |
| `ERC721SeaDropCloneFactory` on Somnia and MegaETH  | v1      | `0x5dC98cE8AA5F7280B2fFdf0dACA8b57486Aa0eba`                                                                                 |
| `ERC1155SeaDropCloneFactory` on Somnia and MegaETH | v2      | `0xbac56cede785c22f78b268daaa73bf46d37a27ab`                                                                                 |

### Legacy clone factories

These earlier factories no longer create drops, but collections they created are still live. They exist on the networks OpenSea supported when they were deployed: Ethereum, Polygon, Arbitrum, Optimism and Avalanche, plus Base and Zora for the first and third.

| Contract                     | Version | Address                                                                                                                      | Used                         |
| ---------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------- | ---------------------------- |
| `ERC721SeaDropCloneFactory`  | v1      | [`0x000000008924D42d98026C656545c3c1fb3ad31C`](https://etherscan.io/address/0x000000008924D42d98026C656545c3c1fb3ad31C#code) | March 2023 to April 2024     |
| `ERC721SeaDropCloneFactory`  | v1      | [`0x0000000042DbFE4ECA8F719A3693B363adB44a02`](https://etherscan.io/address/0x0000000042DbFE4ECA8F719A3693B363adB44a02#code) | March 2023                   |
| `ERC1155SeaDropCloneFactory` | v2      | [`0x000000f20032b9e171844b00EA507E11960BD94a`](https://etherscan.io/address/0x000000f20032b9e171844b00EA507E11960BD94a#code) | September 2023 to April 2024 |

## Networks

The networks OpenSea supports for drops, with the contracts deployed on each. "Standard" means `SeaDrop` at `0x00005EA0…` and the current clone factories at `0x008EbCCa…` (ERC-721) and `0x00b19A52…` (ERC-1155).

| Network         | Chain ID | Contracts                                            |
| --------------- | -------- | ---------------------------------------------------- |
| Ethereum        | 1        | Standard                                             |
| Polygon         | 137      | Standard                                             |
| Arbitrum        | 42161    | Standard                                             |
| Optimism        | 10       | Standard                                             |
| Avalanche       | 43114    | Standard                                             |
| Base            | 8453     | Standard                                             |
| Zora            | 7777777  | Standard                                             |
| Sei             | 1329     | Standard                                             |
| ApeChain        | 33139    | Standard                                             |
| Flow            | 747      | Standard                                             |
| Soneium         | 1868     | Standard                                             |
| Ronin           | 2020     | Standard                                             |
| Berachain       | 80094    | Standard                                             |
| Shape           | 360      | Standard                                             |
| Unichain        | 130      | Standard                                             |
| Abstract        | 2741     | Standard                                             |
| AnimeChain      | 69000    | Standard                                             |
| HyperEVM        | 999      | Standard                                             |
| Monad           | 143      | Standard                                             |
| Ink             | 57073    | Standard                                             |
| Robinhood Chain | 4663     | Standard                                             |
| Somnia          | 5031     | `SeaDrop` and clone factories for Somnia and MegaETH |
| MegaETH         | 4326     | `SeaDrop` and clone factories for Somnia and MegaETH |
| GUNZ            | 43419    | `SeaDrop` for GUNZ only, no clone factories          |

The standard contracts are also deployed on these testnets: Sepolia, Base Sepolia, Arbitrum Sepolia, Optimism Sepolia, Zora Sepolia, Avalanche Fuji, Polygon Amoy and Kaia Kairos. BSC Testnet has `SeaDrop` and the legacy ERC-721 factories only.

They are also deployed on Arbitrum Nova, Kaia, Arc and Elysium, which OpenSea doesn't currently support for drops. BSC and Gnosis have `SeaDrop` and the legacy ERC-721 factories, and Stable has `SeaDrop` only.

The network list comes from OpenSea's chain configuration as of November 2026. Every address in this document was checked for deployed code on each network listed.

To deploy SeaDrop to a new network, see [SeaDrop Deployment](SeaDropDeployment.md).

## Base mainnet v3 QA deployments

These are unaudited test contracts on Base mainnet (chain ID 8453), deployed November 25, 2026 from [SeaDrop revision `c0ec779`](https://github.com/ProjectOpenSea/seadrop/commit/c0ec77941b4b4bae31dd3526388e046e17951fe4). BaseScan verified all three contracts with Solidity 0.8.38 and 1,000,000 optimizer runs.

| Contract                     | Address and verified source                                                                                                  | Creation transaction and block                                                                           |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `SeaDropMinter`              | [`0xec2abcCB14614c895044BeE34a3E8e2Af026935A`](https://basescan.org/address/0xec2abcCB14614c895044BeE34a3E8e2Af026935A#code) | [62,235,112](https://basescan.org/tx/0xff17232b24531047b246fa3c628c9f96124241b0a9ba613ecbc7a0a8296e411a) |
| `ERC721SeaDropV3Standalone`  | [`0xE3E254162985bA3BF10543192fB313b068219404`](https://basescan.org/address/0xE3E254162985bA3BF10543192fB313b068219404#code) | [62,235,118](https://basescan.org/tx/0x9a6c0913e36f7290b460c5d22f50e1ef774d1c19ceb2488922a47a5b44495e0b) |
| `ERC1155SeaDropV3Standalone` | [`0x76E4d933A379C08555C0556Da76544535542450e`](https://basescan.org/address/0x76E4d933A379C08555C0556Da76544535542450e#code) | [62,235,145](https://basescan.org/tx/0xde7874bc453a1702d71f5916b2657d91a6c12a00a4f6981a7cd71080d863587a) |

At deployment, [the QA wallet](https://basescan.org/address/0xfBa662e1a8e91a350702cF3b87D0C2d2Fb4BA57F) owned all three contracts. Both standalone tokens allowed the minter above and had a zero preapproved conduit. The ERC-721 supply cap and the ERC-1155 cap for edition 1 were zero. Neither token had a stage or payout recipients configured. The minter's native and default ERC-20 currency policies were disabled.

### Clone factory

The Base QA minter above [authorized the factory at block 62,260,260](https://basescan.org/tx/0x89a3915bab0e584b606f9fdf1292d94f4daea8fa2653183171dd72cee7a948f0). The factory uses a zero conduit and [deployed both implementations in its constructor at block 62,260,153](https://basescan.org/tx/0xdbf013d23de4b0e41e2a72091d31877d6b5e33928e0e83545962140d1343a0db). Use `createERC721` or `createERC1155` on the factory to create a collection.

| QA contract                     | Base mainnet address                                                                                                         |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| SeaDropTokenFactory             | [`0x0c36fcd4fF64D62096653A39674558b3eb096D8C`](https://basescan.org/address/0x0c36fcd4fF64D62096653A39674558b3eb096D8C#code) |
| ERC721SeaDropV3 implementation  | [`0x1C265a5B9FB58b88bb48467631FFFE5bd193a124`](https://basescan.org/address/0x1C265a5B9FB58b88bb48467631FFFE5bd193a124#code) |
| ERC1155SeaDropV3 implementation | [`0x50D35d6e1f7414a7B86c76E26E6b391eA82e386d`](https://basescan.org/address/0x50D35d6e1f7414a7B86c76E26E6b391eA82e386d#code) |
