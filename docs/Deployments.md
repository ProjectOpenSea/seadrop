# Deployments

SeaDrop has two versions in this repository. v1 is on the [`main`](https://github.com/ProjectOpenSea/seadrop/tree/main) branch and v2 is on the [`v2`](https://github.com/ProjectOpenSea/seadrop/tree/v2) branch. Each contract below has the same address on every network it's deployed to.

## What OpenSea uses

OpenSea drops use SeaDrop v1. OpenSea deploys each drop as a clone of `ERC721SeaDropCloneable` through `ERC721SeaDropCloneFactory`, or as a standalone `ERC721SeaDrop`, and mints go through the shared `SeaDrop` contract.

SeaDrop v2 currently powers ERC-1155 open collections on OpenSea, which the collection owner mints. OpenSea deploys each one as a clone through `ERC1155SeaDropCloneFactory`, and the owner mints through the token's configurer. Earlier v2 ERC-1155 drops, whose public mints fill [Seaport 1.6](https://github.com/ProjectOpenSea/seaport) orders with the token as a contract offerer, are still live, but OpenSea no longer creates them.

OpenSea doesn't create v2 ERC-721 tokens, upgradeable SeaDrop tokens, or standalone ERC-1155 tokens. It still indexes v2 ERC-721 tokens and the drops created by the legacy factories below.

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
