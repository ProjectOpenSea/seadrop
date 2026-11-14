# SeaDrop (private)

Guidance for coding agents and contributors working on `ProjectOpenSea/seadrop-priv`. The [README](README.md) explains SeaDrop v1.

## This repository

- seadrop-priv is the private counterpart of the public `ProjectOpenSea/seadrop`.
- Its `main` and `v2` branches are fast-forward mirrors of the public ones. Change them through pull requests to the public repository, then fast-forward here. A commit made directly to either one here stops the mirror from fast-forwarding.
- The `v3` branch holds SeaDrop v3, which stays private until it launches. Don't push v3 code, docs or discussion to the public repository.
- A fix for a security issue that hasn't been disclosed gets neutral wording anywhere public, including commit messages, pull requests and docs, until it's disclosed.

## What the v3 branch is

It's v1's tree plus SeaDrop v3 under `src/v3`. v3 replaces v2's Seaport-based design with one minter contract per chain and thin tokens. The design and its reasoning are in [#27](https://github.com/ProjectOpenSea/seadrop-priv/issues/27), and the draft audit scope is [docs/v3/AuditScope.md](docs/v3/AuditScope.md).

- `src/v3/SeaDropMinter.sol` is the minter. It holds stages, signed authorizations and intents, recipient rules, payments and payouts for every v3 drop on a chain.
- `src/v3/ERC721SeaDropV3.sol`, `src/v3/ERC1155SeaDropV3.sol` and `src/v3/SeaDropTokenV3Base.sol` are the tokens. They keep ownership, supply and metadata, and mint only for the minters they allow.
- `src/v3/SeaDropTokenFactory.sol` deploys the tokens as EIP-1167 clones and registers them with the minter. Each chain gets one, deployed with that chain's minter and conduit.
- `src/v3/interfaces` has the minter's structs, events and errors, the token interface, and the delegate.xyz registry call.
- `test/v3` has v3's Forge tests, with mocks and helpers in `test/v3/utils`.
- Everything else is v1, as on the public `main`.

## Commands

Use Foundry v1.9.0, the version CI pins (`FOUNDRY_VERSION` in `.github/workflows/test.yml`). Other versions format differently and can reject the lint settings in `foundry.toml`. Install it with `foundryup --install v1.9.0`.

| Task                                        | Command                               |
| ------------------------------------------- | ------------------------------------- |
| Build                                       | `forge build`                         |
| Test v3                                     | `forge test --match-path 'test/v3/*'` |
| Test everything                             | `forge test`                          |
| Install the pinned lint tools (once)        | `scripts/install-tools.sh`            |
| Lint, as CI does                            | `scripts/lint.sh check`               |
| Fix formatting                              | `scripts/lint.sh fix`                 |
| Check contract sizes (EIP-170 and EIP-3860) | `./scripts/check_sizes.sh`            |

`scripts/lint.sh check` runs `forge fmt --check`, `forge lint --deny warnings`, Biome, taplo, shellcheck, shfmt and actionlint. The repo has no Node or npm dependencies. Keep it that way: add tools through `scripts/install-tools.sh`, pinned by version and SHA-256. `.tools/bin/lefthook install` sets up a pre-commit hook that formats staged files. v1's `ERC721SeaDropCloneFactory.t.sol` forks mainnet and needs `ETHEREUM_RPC_URL`.

## Things to know about v3

- Every mint separates the payer (`msg.sender`), the eligible wallet, whose signatures and wallet limits apply, and the recipient. Keep the three apart in new code.
- A payout never reverts a mint. A failed push credits the recipient, who withdraws later. ERC-20 pushes run in a gas-capped call back into the minter (`pushERC20`), so a transfer that fails is rolled back before the credit.
- OpenSea indexes drops from `SeaDropMint` and the versioned configuration events. Changing their fields is a schema change, so bump the version, update the event schema in `docs/v3/AuditScope.md` and `test/v3/SeaDropV3EventSchema.t.sol`, and coordinate.
- Live v1 tokens mint through the minter after `updateAllowedSeaDrop`, via `mintSeaDrop(address,uint256)`. Keep that path working.
- A token's preapproved conduit is fixed at deployment, because it can move every holder's tokens until they revoke it. OpenSea's conduit differs by chain, so the factory takes it and deploys the implementations with it as an immutable. A clone's creator never passes it.
- Tokens are clones. Only the factory can initialize one, once, and the implementations can't be initialized. Keep new token state in the ERC-7201 namespaces, and update the slot tests and `docs/v3/AuditScope.md` when a namespace changes.
- Errors are plain, with one check per error.
- The minter is about 2.3 KB under the EIP-170 limit. Run `./scripts/check_sizes.sh` after adding to it.
- Compiler settings (solc 0.8.38 for Cancun, 1,000,000 optimizer runs, no metadata hash) change deployed bytecode, so don't change them in passing.
- Biome formats Markdown and JSON. It aligns Markdown tables and wants a blank line before a list.

## Pull requests

- v3 work targets the `v3` branch here.
- Greenlight reviews pull requests in this repository. Request a Copilot review too.
- Tests and lint pass, and new code paths come with Forge tests.
- Write docs and descriptions in plain prose, with sentence-case headings and no em dashes.
