# Development

## Install

SeaDrop builds and tests with [Foundry](https://getfoundry.sh). CI pins the version in `.github/workflows/test.yml` (`FOUNDRY_VERSION`), and `forge fmt` output can differ between versions, so match it. To install Foundry on Linux or macOS:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup --install v1.9.0
```

Clone the repo with its submodules and build:

```bash
git clone --recurse-submodules https://github.com/ProjectOpenSea/seadrop && cd seadrop
forge build
```

Node.js (see `.nvmrc`) is only needed for formatting and the git hook. `npm install` installs [Biome](https://biomejs.dev) and sets up the [lefthook](https://lefthook.dev) pre-commit hook, which runs `forge fmt` and Biome on staged files.

## Commands

| Task                                               | Command                    |
| -------------------------------------------------- | -------------------------- |
| Run the tests                                      | `forge test`               |
| Run coverage                                       | `npm run coverage`         |
| Gas snapshot                                       | `forge snapshot`           |
| Lint (`forge fmt --check`, `forge lint` and Biome) | `npm run lint`             |
| Fix formatting                                     | `npm run lint:fix`         |
| Check contract sizes against EIP-170 and EIP-3860  | `./scripts/check_sizes.sh` |

`forge test` also runs the upgradeable contracts' tests: `src/upgradeable` compiles with its deployable settings (via-IR, 1000 optimizer runs) in the same build. See [Upgradeable Contracts](UpgradeableContracts.md). Add `-vv` through `-vvvvv` for logs and traces.

## Pull requests

- All tests and lint checks pass, and coverage doesn't drop.
- New code has natspec where it helps, and new features or code paths have Forge tests.
- Contract changes include gas snapshots that show an improvement, or a cost worth the change.
- The description says why the change is needed and what it does.

Report security issues through [Bugcrowd](https://bugcrowd.com/engagements/opensea), not in a public issue or pull request.
