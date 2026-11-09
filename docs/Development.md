# Development

## Install

SeaDrop builds and tests with [Foundry](https://getfoundry.sh). CI pins the version in `.github/workflows/test.yml` (`FOUNDRY_VERSION`), and `forge fmt` output can differ between versions, so match it. To install Foundry on Linux or macOS:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup --install v1.9.0
```

Clone the `v2` branch with its submodules, build Seaport's artifacts, then build:

```bash
git clone --recurse-submodules https://github.com/ProjectOpenSea/seadrop -b v2 && cd seadrop
./scripts/build_seaport.sh
forge build
```

`build_seaport.sh` loosens Seaport's exact `pragma solidity` pins in the `lib/seaport` working tree, then builds the Seaport reference and optimized artifacts that the tests deploy from `reference-out` and `optimized-out`. Don't commit the resulting `lib/seaport` changes.

Node.js (see `.nvmrc`) is only needed for formatting and the git hook. `npm install` installs [Biome](https://biomejs.dev) and sets up the [lefthook](https://lefthook.dev) pre-commit hook, which runs `forge fmt` and Biome on staged files.

## Commands

| Task                                               | Command                       |
| -------------------------------------------------- | ----------------------------- |
| Run the tests                                      | `forge test`                  |
| Run coverage                                       | `forge coverage --ir-minimum` |
| Gas snapshot                                       | `forge snapshot`              |
| Lint (`forge fmt --check`, `forge lint` and Biome) | `npm run lint`                |
| Fix formatting                                     | `npm run lint:fix`            |
| Check contract sizes against EIP-170 and EIP-3860  | `./scripts/check_sizes.sh`    |

Add `-vv` through `-vvvvv` to `forge test` for logs and traces.

## Pull requests

- All tests and lint checks pass, and coverage doesn't drop.
- New code has natspec where it helps, and new features or code paths have Forge tests.
- Contract changes include gas snapshots that show an improvement, or a cost worth the change.
- The description says why the change is needed and what it does.

Report security issues through [Bugcrowd](https://bugcrowd.com/engagements/opensea), not in a public issue or pull request.
