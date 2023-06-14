![Raribledrop_GithubCover](img/raribleDrop-banner.png)

[![Version][version-badge]][version-link]
[![Test CI][ci-badge]][ci-link]
[![Code Coverage][coverage-badge]][coverage-link]
[![License][license-badge]][license-link]
[![Docs][docs-badge]][docs-link]
[![Discussions][discussions-badge]][discussions-link]

# RaribleDrop

RaribleDrop is a contract for conducting primary NFT drops on evm-compatible blockchains.

Forked from the [SeaDrop by OpenSea](https://github.com/ProjectOpenSea/seadrop)

## Table of Contents

- [RaribleDrop](#raribleDrop)
  - [Table of Contents](#table-of-contents)
  - [Background](#background)
  - [Deployments](#deployments)
  - [Diagram](#diagram)
  - [Docs](#docs)
  - [Install](#install)
  - [Usage](#usage)
    - [Foundry Tests](#foundry-tests)
  - [Audits](#audits)
  - [Contributing](#contributing)
  - [License](#license)

## Background

RaribleDrop is a contract to perform primary drops on evm-compatible blockchains. The types of drops supported are public drops, allow list stages, token gated drops, and server-side signed mints. An implementing token contract should contain the methods to interface with `RaribleDrop` through an authorized user such as an Owner or Administrator.

Future RaribleDrop contracts are envisioned to contain additional functionality like descending dutch auction mechanisms and payment in ERC20 tokens.

To deploy to a new EVM chain, follow the [steps outlined here](docs/RaribleDropDeployment.md).

## Docs

- [RaribleDrop Deployment](docs/RaribleDropDeployment.md)
- [RaribleDrop Token Deployment](docs/RaribleDropTokenDeployment.md)
- [Bring Your Own Token Contract](docs/BringYourOwnTokenContract.md)
- [Provenance Hash](docs/ProvenanceHash.md)

## Install

To install dependencies and compile contracts:

```bash
git clone --recurse-submodules https://github.com/rarible/open-edition-contracts && cd raribleDrop
yarn install
yarn build
```

## Usage

To run hardhat tests written in javascript:

```bash
yarn test
yarn coverage
```

To profile gas usage:

```bash
yarn profile
```

### Foundry Tests

RaribleDrop also includes a suite of fuzzing tests written in solidity with Foundry.

To install Foundry (assuming a Linux or macOS system):

```bash
curl -L https://foundry.paradigm.xyz | bash
```

This will download foundryup. To start Foundry, run:

```bash
foundryup
```

To install dependencies:

```
forge install
```

To run tests:

```
forge test
```

To run gas snapshot:

```
forge snapshot
```

The following modifiers are also available:

- Level 2 (-vv): Logs emitted during tests are also displayed.
- Level 3 (-vvv): Stack traces for failing tests are also displayed.
- Level 4 (-vvvv): Stack traces for all tests are displayed, and setup traces for failing tests are displayed.
- Level 5 (-vvvvv): Stack traces and setup traces are always displayed.

```bash
forge test  -vv
```

For more information on foundry testing and use, see [Foundry Book installation instructions](https://book.getfoundry.sh/getting-started/installation).

To run lint checks:

```bash
yarn lint:check
```

Lint checks utilize prettier, prettier-plugin-solidity, and solhint.

```javascript
"prettier": "^2.5.1",
"prettier-plugin-solidity": "^1.0.0-beta.24",
```

## Audits

RaribleDrop was audited after development by [Spearbit](https://spearbit.com/), read the report [here](./assets/spearbit-raribleDrop-audit.pdf).

## Contributing

Contributions to RaribleDrop are welcome by anyone interested in writing more tests, improving readability, optimizing for gas efficiency, or extending the protocol with new features.

When making a pull request, ensure that:

- All tests pass.
- Code coverage remains at 100% (coverage tests must currently be written in hardhat).
- All new code adheres to the style guide:
  - All lint checks pass.
  - Code is thoroughly commented with natspec where relevant.
- If making a change to the contracts:
  - Gas snapshots are provided and demonstrate an improvement (or an acceptable deficit given other improvements).
  - Reference contracts are modified correspondingly if relevant.
  - New tests (ideally via foundry) are included for all new features or code paths.
- If making a modification to third-party dependencies, `yarn audit` passes.
- A descriptive summary of the PR has been provided.

## License

[MIT](LICENSE) Copyright 2022 Ozone Networks, Inc.

[version-badge]: https://img.shields.io/github/package-json/v/rarible/open-edition-contracts
[version-link]: https://github.com/rarible/open-edition-contracts/blob/main/package.json
[ci-badge]: https://github.com/rarible/open-edition-contracts/actions/workflows/test.yml/badge.svg
[ci-link]: https://github.com/rarible/open-edition-contracts/actions/workflows/test.yml
[coverage-badge]: https://coveralls.io/repos/github/rarible/open-edition-contracts/badge.svg?branch=main
[coverage-link]: https://coveralls.io/github/rarible/open-edition-contracts?branch=main
[license-badge]: https://img.shields.io/github/license/rarible/open-edition-contracts
[license-link]: https://github.com/rarible/open-edition-contracts/blob/main/LICENSE
[docs-badge]: https://img.shields.io/badge/RaribleDrop-documentation-informational
[docs-link]: https://github.com/rarible/open-edition-contracts/tree/main/docs
[discussions-badge]: https://img.shields.io/badge/RaribleDrop-discussions-blueviolet
[discussions-link]: https://github.com/rarible/open-edition-contracts/discussions
