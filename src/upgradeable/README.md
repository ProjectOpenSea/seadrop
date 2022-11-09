# Using with Upgrades

For more information about deploying upgradeable contracts, please refer to 
[OpenZeppelin's documentation](https://docs.openzeppelin.com/contracts/4.x/upgradeable).

Since ERC721A v4, the upgradeable variant uses the Diamond storage pattern as defined in [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).

## Usage

The package shares the same directory layout as the main SeaDrop package, but every file and contract has the suffix `Upgradeable`.

Constructors are replaced by internal initializer functions following the naming convention `__{ContractName}_init`. 

These functions are internal, and you must define your own public initializer function that calls the parent class' initializer.

If using with another upgradeable library, please do use their respective initializer modifier on the `initialize()` function, in addition to the `initializerERC721A` modifier.

## Deployment

If you are using hardhat, you can deploy it using 
[OpenZeppelin Upgrade Plugins](https://docs.openzeppelin.com/upgrades-plugins/1.x/).

```
npm install --save-dev @openzeppelin/hardhat-upgrades
```

**Deploy Script**

Located at [`scripts/deploy.js`](./scripts/deploy.js)

**Upgrade Script**

Located at [`scripts/upgrade.js`](./scripts/upgrade.js)

### Testnet / Mainnet

We will use the Goerli testnet as an example.

Add the following to your environment file `.env`:

```
export ETHERSCAN_KEY="Your Etherscan API Key"
export PRIVATE_KEY="Your Wallet Private Key"
export RPC_URL_GOERLI="https://Infura Or Alchemy URL With API Key"
```

Hardhat config located at [`hardhat.config.js`](./hardhat.config.js)

**Deploy**

In `src/upgradeable` run:

```
npx hardhat run --config hardhat.config.js --network goerli scripts/deploy.js
```

**Upgrade**

In `src/upgradeable` run:

```
npx hardhat run --config hardhat.config.js --network goerli scripts/upgrade.js
```
