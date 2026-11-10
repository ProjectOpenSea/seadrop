# Upgradeable contracts

`src/upgradeable` holds the upgradeable variant of the SeaDrop token, `ERC721SeaDropUpgradeable`, for deploying behind a proxy. For background on upgradeable contracts, see [OpenZeppelin's documentation](https://docs.openzeppelin.com/contracts/4.x/upgradeable).

## Layout

`src/upgradeable` mirrors `src`, with the suffix `Upgradeable` on each contract that has a regular counterpart:

- `ERC721SeaDropUpgradeable.sol` and `ERC721ContractMetadataUpgradeable.sol`
- `extensions/ERC721SeaDropRandomOffsetUpgradeable.sol`
- `lib/ERC721AConduitPreapprovedUpgradeable.sol` and `lib/ERC721TransferValidatorUpgradeable.sol`
- `ExampleToken.sol`, an example token that only a set burn address can burn from
- `vendored/`, upgradeable transpilations of solmate's `ReentrancyGuard` and utility-contracts' `TwoStepOwnable` and `ConstructorInitializable`, with their original license headers

The upgradeable contracts share the interfaces, structs, errors, and events in `src/interfaces` and `src/lib` with the regular contracts. So each upgradeable token has the same ABI and ERC-165 interface IDs as its regular counterpart, except that `initialize()` (and its `Initialized` event) replaces the constructor, and `ERC721SeaDropRandomOffsetUpgradeable.revealed()` returns a `bool` where `ERC721SeaDropRandomOffset.revealed()` returns `1` or `2`.

## Storage

State lives in the namespaced `Layout` structs of the `*Storage.sol` libraries, the diamond storage pattern from [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535) that ERC721A-Upgradeable also uses since v4. OpenZeppelin's `Initializable` keeps its two flags in slot 0. Proxies already deployed hold their state at these slots, so:

- Never change a library's `STORAGE_SLOT` string, including the `openzepplin` misspelling.
- Never reorder, retype, or remove a `Layout` field. A new implementation may only append fields to the end of a `Layout`.

`testStorageLayout` in [`test/foundry/upgradeable/ERC721SeaDropUpgradeable.t.sol`](../test/foundry/upgradeable/ERC721SeaDropUpgradeable.t.sol) pins every field to its slot.

## Initializers

Constructors are replaced by internal initializer functions named `__{ContractName}_init`. A contract that inherits one of these must define its own public initializer that calls its parent's. If you combine these contracts with another upgradeable library, use that library's initializer modifier on `initialize()` as well as `onlyInitializing`.

`initialize()` only runs in a constructor context: `TwoStepOwnableUpgradeable` reverts with `AlreadyInitialized` when the caller already has code. So the proxy's constructor has to call it, and nobody can initialize the bare implementation.

## Building and testing

`forge build` and `forge test` cover the upgradeable contracts along with everything else. [`foundry.toml`](../foundry.toml) restricts `src/upgradeable` to the settings the implementations are deployed with (solc 0.8.38, via-IR, 1000 optimizer runs, ipfs metadata hash, Cancun). Files that import them compile with the same settings, and the rest of the repo keeps the default settings.

Coverage runs under `FOUNDRY_PROFILE=coverage` (see the coverage command in [Development](Development.md#commands)), which drops that restriction so the coverage build maps `src/upgradeable` to the right lines.

The token tests in `test/foundry` run against both tokens. Each test contract in [`test/foundry/upgradeable/SharedTests.t.sol`](../test/foundry/upgradeable/SharedTests.t.sol) overrides `_upgradeable()` to rerun a shared test contract against the upgradeable token behind a transparent proxy. `TestHelper` deploys that token from its build artifact, so the shared tests themselves compile with the default settings.

## Deployment

The upgradeable contracts deploy with Forge scripts. They use a transparent proxy, the same layout the OpenZeppelin Hardhat Upgrades plugin created for this contract: the `ERC721SeaDropUpgradeable` implementation, a `ProxyAdmin` owned by the deployer, and a `TransparentUpgradeableProxy` whose constructor calls `initialize(name, symbol, allowedSeaDrop)`.

[`script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol`](../script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol) deploys all three. `forge script` prints the proxy, admin, and implementation addresses it returns. Each run deploys a new `ProxyAdmin`; the Hardhat plugin reused one per network.

[`script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol`](../script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol) upgrades the proxy at `PROXY_ADDRESS`. It deploys a new implementation and upgrades the proxy through its `ProxyAdmin`, which the broadcaster must own. Proxies deployed by the old Hardhat scripts work too, since the script reads the admin from the proxy. Unlike the Hardhat plugin, it does not check upgrade safety or storage layout compatibility, so review the new implementation against the rules in [Storage](#storage) first.

The scripts don't write an addresses file, because `forge script` runs them in simulation before broadcasting: a file written there would also be written on dry runs and on failed broadcasts. The receipt-backed record of each broadcast is `broadcast/<script>/<chain id>/run-latest.json`.

`ERC721SeaDropUpgradeableScriptsTest` in [`test/foundry/upgradeable`](../test/foundry/upgradeable) runs both scripts end to end.

### Testnet and mainnet

These examples use Sepolia. Add the following to your `.env`:

```
export PRIVATE_KEY="Your Wallet Private Key"
export SEPOLIA_RPC_URL="https://Infura Or Alchemy URL With API Key"
export ETHERSCAN_API_KEY="Your Etherscan API Key"
```

To deploy, from the repository root:

```
forge script script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol \
  --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast --verify
```

To upgrade, from the repository root:

```
PROXY_ADDRESS=0x... forge script script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol \
  --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast --verify
```

`--verify` uses `ETHERSCAN_API_KEY` and verifies every contract the script deployed.
