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

Formatting and linting use pinned tools rather than anything from npm. `scripts/install-tools.sh` downloads [Biome](https://biomejs.dev), [taplo](https://taplo.tamasfe.dev), [shellcheck](https://www.shellcheck.net), [shfmt](https://github.com/mvdan/sh), [actionlint](https://github.com/rhysd/actionlint) and [lefthook](https://lefthook.dev) from their GitHub releases into `.tools/bin` and checks each against a pinned SHA-256. It supports macOS and Linux; on Windows, use WSL. `.tools/bin/lefthook install` sets up a pre-commit hook that formats staged files.

## Commands

| Task                                              | Command                    |
| ------------------------------------------------- | -------------------------- |
| Run the tests                                     | `forge test`               |
| Gas snapshot                                      | `forge snapshot`           |
| Lint, as CI does                                  | `scripts/lint.sh check`    |
| Fix formatting                                    | `scripts/lint.sh fix`      |
| Check contract sizes against EIP-170 and EIP-3860 | `./scripts/check_sizes.sh` |

Coverage, as CI runs it:

```bash
FOUNDRY_PROFILE=coverage forge coverage --report summary --report lcov --no-match-coverage 'Shim|MaliciousRecipient|Deploy|Test|Snapshot'
```

`forge test` also runs the upgradeable contracts' tests: `src/upgradeable` compiles with its deployable settings (via-IR, 1000 optimizer runs) in the same build. See [Upgradeable Contracts](UpgradeableContracts.md). Add `-vv` through `-vvvvv` for logs and traces.

## Pull requests

- All tests and lint checks pass, and coverage doesn't drop.
- New code has natspec where it helps, and new features or code paths have Forge tests.
- Contract changes include gas snapshots that show an improvement, or a cost worth the change.
- The description says why the change is needed and what it does.

Report security issues through [Bugcrowd](https://bugcrowd.com/engagements/opensea), not in a public issue or pull request.
