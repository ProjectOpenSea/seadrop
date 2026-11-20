# SeaDrop v3

V3 uses one minter per chain for drop stages, wallet eligibility, payments and payouts. The ERC-721 or ERC-1155 collection keeps ownership, balances, metadata and supply limits. ERC-721 stages use id 0 and mint sequential tokens from 1. ERC-1155 stages use the edition id, starting at 1.

| Use case                                      | Entry point                                                                                                                                                                                  |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Configure stages, mint or read the minter ABI | [SeaDropMinter](../../src/v3/SeaDropMinter.sol), [interface](../../src/v3/interfaces/ISeaDropMinter.sol)                                                                                     |
| Deploy a collection                           | [Factory clones](../../src/v3/SeaDropTokenFactory.sol), [standalone ERC-721](../../src/v3/ERC721SeaDropV3Standalone.sol), [standalone ERC-1155](../../src/v3/ERC1155SeaDropV3Standalone.sol) |
| Deploy an upgradeable token                   | [Token proxy deployment](AuditScope.md#upgradeable-token-deployments)                                                                                                                        |
| Run a drop for an existing ERC-721            | [Adapters](ExistingContractAdapters.md)                                                                                                                                                      |
| Deploy an agent NFT                           | [Agent extension](AgentNFTs.md)                                                                                                                                                              |

Run `forge test --match-path 'test/v3/*'` from the repository root. The [audit scope](AuditScope.md) describes initialization, storage layout and compatibility with v1. Follow the [v3 tracker](https://github.com/ProjectOpenSea/seadrop/issues/235) for rollout status.
