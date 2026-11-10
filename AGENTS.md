# SeaDrop v2

Guidance for coding agents and contributors working on this branch. The [README](README.md) explains SeaDrop v2, and [docs/Development.md](docs/Development.md) has the full setup.

## What this branch is

`v2` is SeaDrop v2, with ERC-721 and ERC-1155 tokens. Each token is a Seaport contract offerer, so a public mint is a Seaport order that the token fills. OpenSea's ERC-1155 open collections are minted by their owner through the token's configurer instead ([what OpenSea uses](docs/Deployments.md#what-opensea-uses)). `main` holds v1, a separate design with a standalone `SeaDrop` minter.

Deployed contracts are immutable. A change here only reaches contracts deployed after it, so be conservative with anything that changes bytecode.

## Layout

- `src/ERC721SeaDrop.sol` and `src/ERC1155SeaDrop.sol` are the tokens. Their fallback routes configuration calls, getters, and Seaport's `previewOrder` and `generateOrder` to a configurer (`src/lib/*SeaDropConfigurer.sol`) by delegatecall, which keeps the tokens under the size limit.
- The shared logic is in `src/lib/*ContractOffererImplementation.sol`, and the storage layout in `src/lib/*ContractOffererStorage.sol`, at a fixed slot that tokens and configurers share.
- `src/extensions` has token variants, such as `ERC721SeaDropLockable`, `ERC1155SeaDropLockable` and `ERC721SeaDropRandomOffset`.
- `src/clones` has the cloneable ERC-1155 token and `ERC1155SeaDropCloneFactory`.
- `test/foundry` has the Forge tests, and `script` the deployment scripts.

## Commands

Use Foundry v1.9.0, the version CI pins (`FOUNDRY_VERSION` in `.github/workflows/test.yml`). Other versions format differently and can reject the lint settings in `foundry.toml`. Install it with `foundryup --install v1.9.0`.

Build Seaport's artifacts once before testing: `./scripts/build_seaport.sh`. It loosens Seaport's exact pragmas in the `lib/seaport` working tree and builds the reference and optimized Seaport the tests deploy. Never commit the `lib/seaport` changes it leaves.

| Task                                        | Command                                                                 |
| ------------------------------------------- | ----------------------------------------------------------------------- |
| Build Seaport, the contracts and size check | `./scripts/build_seaport.sh && forge build && ./scripts/check_sizes.sh` |
| Test                                        | `forge test`                                                            |
| Install the pinned lint tools (once)        | `scripts/install-tools.sh`                                              |
| Lint, as CI does                            | `scripts/lint.sh check`                                                 |
| Fix formatting                              | `scripts/lint.sh fix`                                                   |
| Check contract sizes (EIP-170 and EIP-3860) | `./scripts/check_sizes.sh`                                              |
| Coverage                                    | `forge coverage --ir-minimum`                                           |

`scripts/lint.sh check` runs `forge fmt --check`, patches Seaport's pragmas, then runs `forge lint --deny warnings`, Biome, taplo, shellcheck, shfmt and actionlint. The repo has no Node or npm dependencies. Keep it that way: add tools through `scripts/install-tools.sh`, pinned by version and SHA-256. `.tools/bin/lefthook install` sets up a pre-commit hook that formats staged files.

## Things to know

- Contracts compile with solc 0.8.38 for Cancun, 100,000 optimizer runs and no metadata hash. The `clone_factory_deployment` profile uses 99,999,999 runs for deploying the factory. Changing either changes deployed bytecode.
- `foundry.toml` silences solc's size errors, so `./scripts/check_sizes.sh` is the size gate. CI runs it, and the tokens sit close to the EIP-170 limit.
- A token and its configurer must agree on the storage layout. Change the storage structs on both sides, or not at all.
- OpenSea recognizes cloned tokens by their implementation's code hash. A change to `ERC1155SeaDropCloneable`'s bytecode needs coordinating with OpenSea before the factory is redeployed.
- Fuzz tests exclude precompiles with forge-std's `assumeNotPrecompile`. Under Cancun, `0x0A` is a precompile too.
- Biome formats Markdown and JSON. It aligns Markdown tables and wants a blank line before a list.
- Dependencies are git submodules under `lib`. Don't edit them, apart from the pragma patch above.

## Pull requests

- Target the `v2` branch.
- Follow [the pull request checklist](docs/Development.md#pull-requests): tests and lint pass, coverage doesn't drop, and contract changes come with gas snapshots.
- Request a Copilot review on each pull request.
- Write docs and descriptions in plain prose, with sentence-case headings and no em dashes.
- Report security issues through [Bugcrowd](https://bugcrowd.com/engagements/opensea), not in a public issue or pull request.
