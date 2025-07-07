import * as dotenv from 'dotenv';
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-gas-reporter";
import "hardhat-preprocessor";
import fs from "fs";
import type { HardhatUserConfig } from "hardhat/config";

dotenv.config();

const DEFAULT_GAS_MULTIPLIER: number = 1.2;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          viaIR: false,
          optimizer: {
            enabled: true,
            runs: 1000,
          },
          metadata: {
            bytecodeHash: "none",
          },
        },
      },
    ],
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v5",
  },
  networks: {
    hardhat: {
      blockGasLimit: 30_000_000,
      throwOnCallFailures: false,
      allowUnlimitedContractSize: true,
    },
    verificationNetwork: {
      url: process.env.NETWORK_RPC ?? "",
    },
    truffle: {
      allowUnlimitedContractSize: true,
      url: 'http://localhost:24012/rpc',
      timeout: 3600000,//1h
      gasMultiplier: DEFAULT_GAS_MULTIPLIER,
//       blockGasLimit: 100000000429720,
      // gasPrice: 14_400_000_000,// 14 GWEI = 0.000000014 eth
      // gasPrice: 8000000000,
      // gasPrice: 11_000_000_000,
      blockGasLimit: 100_000_000_429_720,
      // blockGasLimit: 40_000_000,
      // gas: 21_000,
      // gas: 2100000,
      // gas: 20_000_000, // gas limit must be:   20999 < gas limit <= 7920027
      gas: 7_920_027, // gas limit must be:  2100000 <= gas limit <= 7920027


    },
    sepolia: {
      url: process.env.NETWORK_TESTNET_URL,
      // gas: 2100000,
      // gasPrice: 8000000000,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    coinmarketcap: process.env.GAS_REPORTER_COIN_MARKET_CAP_API_KEY,
  },
  etherscan: {
    apiKey: process.env.BLOCK_EXPLORER_API_KEY,
  },
  // specify separate cache for hardhat, since it could possibly conflict with foundry's
  paths: { sources: "./src", tests: "./test", cache: "./hh-cache" },
  mocha: {
    timeout: 3600000
  }
};


export default config;
