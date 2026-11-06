# Using with Upgrades

For more information about deploying upgradeable contracts, please refer to 
[OpenZeppelin's documentation](https://docs.openzeppelin.com/contracts/4.x/upgradeable).

Since ERC721A v4, the upgradeable variant uses the Diamond storage pattern as defined in [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).

## Usage

The package shares the same directory layout as the main SeaDrop package, but every file and contract has the suffix `Upgradeable`.

Constructors are replaced by internal initializer functions following the naming convention `__{ContractName}_init`. 

These functions are internal, and you must define your own public initializer function that calls the parent class' initializer.

If using with another upgradeable library, please do use their respective initializer modifier on the `initialize()` function, in addition to the `onlyInitializing` modifier.

## Deployment

The upgradeable contracts deploy with Forge scripts. They use a transparent proxy, the same layout the OpenZeppelin Hardhat Upgrades plugin created for this contract: the `ERC721SeaDropUpgradeable` implementation, a `ProxyAdmin` owned by the deployer, and a `TransparentUpgradeableProxy` whose constructor calls `initialize(name, symbol, allowedSeaDrop)`.

Run the scripts from the repository root with `FOUNDRY_PROFILE=upgradeable`. That profile in [`foundry.toml`](../foundry.toml) compiles with the settings the contracts were deployed with (solc 0.8.17, via-IR, 1000 optimizer runs), which `--verify` needs to match the deployed bytecode.

**Deploy script**

Located at [`script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol`](../script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol). It writes the proxy, admin, and implementation addresses to `src-upgradeable/deployment-addresses.json`. Each run deploys a new `ProxyAdmin`; the Hardhat plugin reused one per network.

**Upgrade script**

Located at [`script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol`](../script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol). It reads the proxy from `src-upgradeable/deployment-addresses.json`, deploys a new implementation, upgrades the proxy through its `ProxyAdmin` (the broadcaster must own it), and rewrites the file. Proxies deployed by the old Hardhat scripts work too, since the script reads the admin from the proxy.

Unlike the Hardhat plugin, the upgrade script does not check upgrade safety or storage layout compatibility, so review the new implementation first. State lives in the namespaced `Layout` structs of the `*Storage.sol` libraries (and ERC721A's), so a new implementation may only append fields to those structs.

Set `DEPLOYMENT_ADDRESSES_PATH` to use a different addresses file. The path must be allowed by `fs_permissions` in the upgradeable profile.

**Test**

`FOUNDRY_PROFILE=upgradeable forge test` runs both scripts end to end in [`test/upgradeable`](../test/upgradeable).

### Testnet / Mainnet

We will use the Sepolia testnet as an example.

Add the following to your environment file `.env`:

```
export PRIVATE_KEY="Your Wallet Private Key"
export SEPOLIA_RPC_URL="https://Infura Or Alchemy URL With API Key"
export ETHERSCAN_API_KEY="Your Etherscan API Key"
```

**Deploy**

From the repository root run:

```
FOUNDRY_PROFILE=upgradeable forge script script/upgradeable/DeployERC721SeaDropUpgradeable.s.sol \
  --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast --verify
```

**Upgrade**

From the repository root run:

```
FOUNDRY_PROFILE=upgradeable forge script script/upgradeable/UpgradeERC721SeaDropUpgradeable.s.sol \
  --rpc-url sepolia --private-key $PRIVATE_KEY --broadcast --verify
```

`--verify` uses `ETHERSCAN_API_KEY` and verifies every contract the script deployed.
