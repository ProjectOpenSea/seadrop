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

If you are using hardhat, you can deploy it using 
[OpenZeppelin Upgrade Plugins](https://docs.openzeppelin.com/upgrades-plugins/1.x/).

**Deploy Script**

Located at [`scripts/deploy.ts`](./scripts/deploy.ts)

**Upgrade Script**

Located at [`scripts/upgrade.ts`](./scripts/upgrade.ts)

### Testnet / Mainnet

We will use the Sepolia testnet as an example.

Add the following to your environment file `.env`:

```
export PRIVATE_KEY="Your Wallet Private Key"
export SEPOLIA_RPC_URL="https://Infura Or Alchemy URL With API Key"
export ETHERSCAN_API_KEY="Your Etherscan API Key"
```

Hardhat config located at [`hardhat.config.ts`](./hardhat.config.ts)

**Deploy**

In this directory (`src-upgradeable`) run:

```
npx hardhat run --config hardhat.config.ts --network sepolia scripts/deploy.ts
```

**Upgrade**

In this directory (`src-upgradeable`) run:

```
npx hardhat run --config hardhat.config.ts --network sepolia scripts/upgrade.ts
```
