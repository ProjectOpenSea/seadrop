# SeaDrop

Guidance for coding agents and contributors working on this repository. The [README](README.md) explains SeaDrop, and [docs/Development.md](docs/Development.md) has the full setup.

## What this branch is

`main` is SeaDrop v1. `SeaDrop` is the minting contract, deployed once per chain (addresses in [docs/Deployments.md](docs/Deployments.md)), and the ERC-721 tokens mint through it. The `v2` branch is a separate design that adds ERC-1155. Its public drops mint through Seaport, while ERC-1155 open collections are minted by their owner through the token's configurer ([what OpenSea uses](docs/Deployments.md#what-opensea-uses)).

Deployed non-upgradeable contracts are immutable, so a change only reaches contracts deployed after it. Be conservative with anything that changes bytecode. Upgradeable tokens can be upgraded in place, so their storage layout must stay compatible: see [the storage rules](docs/UpgradeableContracts.md#storage).

## Layout

- `src/SeaDrop.sol` is the minter, and `src/ERC721SeaDrop.sol` the token it mints.
- `src/extensions` has token variants, such as `ERC721SeaDropLockable` and `ERC721SeaDropRandomOffset`.
- `src/clones` has the cloneable token and `ERC721SeaDropCloneFactory`.
- `src/upgradeable` has the upgradeable versions. `src/upgradeable/vendored` is vendored code that isn't formatted or linted.
- `src/test` and `src/shim` hold contracts the tests use.
- `test/foundry` has the Forge tests, and `script` the deployment scripts.

## Commands

Use Foundry v1.9.0, the version CI pins (`FOUNDRY_VERSION` in `.github/workflows/test.yml`). Other versions format differently and can reject the lint settings in `foundry.toml`. Install it with `foundryup --install v1.9.0`.

| Task                                        | Command                                                                                     |
| ------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Build                                       | `forge build`                                                                               |
| Test                                        | `forge test`                                                                                |
| Install the pinned lint tools (once)        | `scripts/install-tools.sh`                                                                  |
| Lint, as CI does                            | `scripts/lint.sh check`                                                                     |
| Fix formatting                              | `scripts/lint.sh fix`                                                                       |
| Check contract sizes (EIP-170 and EIP-3860) | `./scripts/check_sizes.sh`                                                                  |
| Coverage                                    | `FOUNDRY_PROFILE=coverage forge coverage` (see [Development](docs/Development.md#commands)) |

`scripts/lint.sh check` runs `forge fmt --check`, `forge lint --deny warnings`, Biome, taplo, shellcheck, shfmt and actionlint. The repo has no Node or npm dependencies. Keep it that way: add tools through `scripts/install-tools.sh`, pinned by version and SHA-256. `.tools/bin/lefthook install` sets up a pre-commit hook that formats staged files. `ERC721SeaDropCloneFactory.t.sol` forks mainnet and needs `ETHEREUM_RPC_URL`.

## Things to know

- Contracts compile with solc 0.8.38 for Cancun, 1,000,000 optimizer runs and no metadata hash. `src/upgradeable` compiles separately with via-IR, 1,000 runs and an IPFS metadata hash, which verifying an upgradeable deployment needs. Changing either changes deployed bytecode.
- OpenSea recognizes cloned tokens by their implementation's code hash. A change to `ERC721SeaDropCloneable`'s bytecode needs coordinating with OpenSea before the factory is redeployed.
- Fuzz tests exclude precompiles with forge-std's `assumeNotPrecompile`. Under Cancun, `0x0A` is a precompile too, so a hand-rolled `> address(9)` check isn't enough.
- Biome formats Markdown and JSON. It aligns Markdown tables and wants a blank line before a list.
- Dependencies are git submodules under `lib`. Don't edit them.

## Pull requests

- Follow [the pull request checklist](docs/Development.md#pull-requests): tests and lint pass, coverage doesn't drop, and contract changes come with gas snapshots.
- Request a Copilot review on each pull request.
- Write docs and descriptions in plain prose, with sentence-case headings and no em dashes.
- Report security issues through [Bugcrowd](https://bugcrowd.com/engagements/opensea), not in a public issue or pull request.
