![SeaDrop_GithubCover](img/seadrop-banner.png)

[![Test CI][ci-badge]][ci-link]
[![Code Coverage][coverage-badge]][coverage-link]
[![License][license-badge]][license-link]
[![Docs][docs-badge]][docs-link]
[![Discussions][discussions-badge]][discussions-link]

# SeaDrop

SeaDrop is a protocol for primary NFT drops on EVM chains.

## Versions

All development targets `main`. Choose the generation that matches your collection:

| Version | Source and tests                                                                                                    | Use                                                                 |
| ------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| v3      | [Guide](docs/v3), [contracts](src/v3), [tests](test/v3), [audit scope](docs/v3/AuditScope.md)                       | In development. Shared minter for ERC-721 and ERC-1155 collections. |
| v2      | [Guide and project](versions/v2), [tests](versions/v2/test/foundry)                                                 | ERC-1155 open collections and existing Seaport-based drops.         |
| v1      | [Guide](docs/SeaDropV1.md), [contracts](src/SeaDrop.sol), [tests](test/foundry), [deployments](docs/Deployments.md) | ERC-721 drops using the original SeaDrop minter.                    |

The root Foundry project builds v1 and v3. Run v2 commands from `versions/v2` to use its pinned dependencies and compiler settings. See the [v3 tracker](https://github.com/ProjectOpenSea/seadrop/issues/235) for rollout and audit status.

## Development

Follow the [development guide](docs/Development.md) for setup, test commands, coverage and pull requests. For existing contracts, the [v1 and v2 deployment tables](docs/Deployments.md) list addresses by network.

## Security

The [Spearbit report](assets/spearbit-seadrop-audit.pdf) covers the earlier protocol. V3 has a separate [draft audit scope](docs/v3/AuditScope.md). Report vulnerabilities through [Bugcrowd](https://bugcrowd.com/engagements/opensea).

## License

[MIT](LICENSE) Copyright 2022 Ozone Networks, Inc.

[ci-badge]: https://github.com/ProjectOpenSea/seadrop/actions/workflows/test.yml/badge.svg
[ci-link]: https://github.com/ProjectOpenSea/seadrop/actions/workflows/test.yml
[coverage-badge]: https://coveralls.io/repos/github/ProjectOpenSea/seadrop/badge.svg?branch=main
[coverage-link]: https://coveralls.io/github/ProjectOpenSea/seadrop?branch=main
[license-badge]: https://img.shields.io/github/license/ProjectOpenSea/seadrop
[license-link]: https://github.com/ProjectOpenSea/seadrop/blob/main/LICENSE
[docs-badge]: https://img.shields.io/badge/SeaDrop-documentation-informational
[docs-link]: https://github.com/ProjectOpenSea/seadrop/tree/main/docs
[discussions-badge]: https://img.shields.io/badge/SeaDrop-discussions-blueviolet
[discussions-link]: https://github.com/ProjectOpenSea/seadrop/discussions
