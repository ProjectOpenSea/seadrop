import { setCode } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

import { whileImpersonating } from "./impersonate";

import type {
  ConsiderationInterface,
  ERC721SeaDrop,
} from "../../typechain-types";
import type { Wallet } from "ethers";

const { provider } = ethers;
const { hexlify, zeroPad } = ethers.utils;

export const VERSION = "2.0.0";

export type AwaitedObject<T> = {
  [K in keyof T]: Awaited<T[K]>;
};

export const setMintRecipientStorageSlot = async (
  token: ERC721SeaDrop,
  minter: Wallet
) => {
  // If the below storage slot changes, the updated value can be found
  // with `forge inspect ERC721SeaDropContractOfferer storage-layout`
  const mintRecipientStorageSlot = "0x21";
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
  token,
  minter,
  quantity,
}: {
  marketplaceContract: ConsiderationInterface;
  token: ERC721SeaDrop;
  minter: Wallet;
  quantity: number;
}) => {
  await setMintRecipientStorageSlot(token, minter);

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
  const delegationRegistryBytecode = await provider.getCode(
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

/**
 * This is to remove unnecessary properties from the output type.
 * Use it eg. `ExtractPropsFromArray<Inventory.ItemStructOutput>`
 */
export type ExtractPropsFromArray<T> = Omit<
  T,
  keyof Array<unknown> | `${number}`
>;

/**
 * convertToStruct takes an array type
 * eg. Inventory.ItemStructOutput and converts it to an object type.
 */
export const convertToStruct = <A extends Array<unknown>>(
  arr: A
): ExtractPropsFromArray<A> => {
  const keys = Object.keys(arr).filter((key) => isNaN(Number(key)));
  const result = {};
  // @ts-ignore
  arr.forEach((item, index) => (result[keys[index]] = item));
  return result as A;
};
