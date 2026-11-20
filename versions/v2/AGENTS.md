# SeaDrop v2

The [v2 guide](README.md) describes the Seaport mint flow. Follow the [shared contribution rules](../../AGENTS.md#pull-requests).

## Layout

- `src/ERC721SeaDrop.sol` and `src/ERC1155SeaDrop.sol` are the tokens. Their fallback routes configuration calls, getters, and Seaport's `previewOrder` and `generateOrder` to a configurer (`src/lib/*SeaDropConfigurer.sol`) by delegatecall, which keeps the tokens under the size limit.
- The shared logic is in `src/lib/*ContractOffererImplementation.sol`, and the storage layout in `src/lib/*ContractOffererStorage.sol`, at a fixed slot that tokens and configurers share.
- `src/extensions` has token variants, such as `ERC721SeaDropLockable`, `ERC1155SeaDropLockable` and `ERC721SeaDropRandomOffset`.
- `src/clones` has the cloneable ERC-1155 token and `ERC1155SeaDropCloneFactory`.
- `test/foundry` has the Forge tests, and `script` the deployment scripts.

## Commands

Use the [v2 development instructions](../../docs/Development.md#seadrop-v2) for the pinned toolchain, Seaport build, tests and coverage.

## Things to know

- Contracts compile with solc 0.8.38 for Cancun, 100,000 optimizer runs and no metadata hash. The `clone_factory_deployment` profile uses 99,999,999 runs for deploying the factory. Changing either changes deployed bytecode.
- `foundry.toml` silences solc's size errors, so `../../scripts/check_sizes.sh versions/v2` is the size gate. CI runs it, and the tokens sit close to the EIP-170 limit.
- A token and its configurer must agree on the storage layout. Change the storage structs on both sides, or not at all.
- OpenSea recognizes cloned tokens by their implementation's code hash. A change to `ERC1155SeaDropCloneable`'s bytecode needs coordinating with OpenSea before the factory is redeployed.
- Fuzz tests exclude precompiles with forge-std's `assumeNotPrecompile`. Under Cancun, `0x0A` is a precompile too.
- Biome formats Markdown and JSON. It aligns Markdown tables and wants a blank line before a list.
- Dependencies are git submodules under `lib`. Don't edit them, apart from the pragma patch above.
