import { setCode } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

import { whileImpersonating } from "./impersonate";

import type {
  ConsiderationInterface,
  ERC721SeaDrop,
} from "../../typechain-types";
import type { Wallet, providers } from "ethers";

const { hexlify, zeroPad } = ethers.utils;

export const VERSION = "2.0.0";

export type AwaitedObject<T> = {
  [K in keyof T]: Awaited<T[K]>;
};

export const setMintRecipientStorageSlot = async (
  provider: providers.JsonRpcProvider,
  token: ERC721SeaDrop,
  minter: Wallet
) => {
  // If the below storage slot changes, the updated value can be found
  // with `forge inspect ERC721SeaDropContractOfferer storage-layout`
  const mintRecipientStorageSlot = "0x22";
  // Storage value must be a 32 bytes long padded with leading zeros hex string
  const mintRecipientStorageValue = hexlify(zeroPad(minter.address, 32));
  await provider.send("hardhat_setStorageAt", [
    token.address,
    mintRecipientStorageSlot,
    mintRecipientStorageValue,
  ]);
};

export const mintTokens = async ({
  marketplaceContract,
  provider,
  token,
  minter,
  quantity,
}: {
  provider: providers.JsonRpcProvider;
  marketplaceContract: ConsiderationInterface;
  token: ERC721SeaDrop;
  minter: Wallet;
  quantity: number;
}) => {
  await setMintRecipientStorageSlot(provider, token, minter);

  await whileImpersonating(
    marketplaceContract.address,
    provider,
    async (impersonatedSigner) => {
      await token
        .connect(impersonatedSigner)
        ["safeTransferFrom(address,address,uint256,uint256,bytes)"](
          token.address,
          minter.address,
          0,
          quantity,
          []
        );
    }
  );
};

export const deployDelegationRegistryToCanonicalAddress = async () => {
  const DelegationRegistry = await ethers.getContractFactory(
    "DelegationRegistry"
  );
  const exampleDelegationRegistry = await DelegationRegistry.deploy();
  const delegationRegistryBytecode = await ethers.provider.getCode(
    exampleDelegationRegistry.address
  );
  const canonicalDelegationRegistryAddress =
    "0x00000000000076A84feF008CDAbe6409d2FE638B";
  await setCode(canonicalDelegationRegistryAddress, delegationRegistryBytecode);
  const delegationRegistry = DelegationRegistry.attach(
    canonicalDelegationRegistryAddress
  );
  return delegationRegistry;
};
