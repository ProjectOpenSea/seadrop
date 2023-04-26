import { setCode } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

import { whileImpersonating } from "./impersonate";

import type {
  ConsiderationInterface,
  ERC721SeaDrop,
  ERC721SeaDropConfigurer,
} from "../../typechain-types";
import type { Wallet } from "ethers";

const { BigNumber, provider } = ethers;
const { AddressZero } = ethers.constants;
const { defaultAbiCoder, hexlify, keccak256, toUtf8Bytes, zeroPad } =
  ethers.utils;

export const VERSION = "2.0.0";

export type AwaitedObject<T> = {
  [K in keyof T]: Awaited<T[K]>;
};

export const deployERC721SeaDrop = async (
  owner: Wallet,
  marketplaceContract: string,
  conduit: string
) => {
  // Deploy configurer
  const ERC721SeaDropConfigurer = await ethers.getContractFactory(
    "ERC721SeaDropConfigurer",
    owner
  );
  const configurer = await ERC721SeaDropConfigurer.deploy();

  // Deploy token
  const ERC721SeaDrop = await ethers.getContractFactory("ERC721SeaDrop", owner);
  const token = await ERC721SeaDrop.deploy(
    "",
    "",
    configurer.address,
    marketplaceContract,
    conduit
  );

  return { configurer, token };
};

export const setMintRecipientStorageSlot = async (
  token: ERC721SeaDrop,
  minter: Wallet
) => {
  // Storage slot from ERC721SeaDropContractOffererStorage
  const libStorageSlot = keccak256(
    toUtf8Bytes("openzeppelin.contracts.storage.ERC721SeaDropContractOfferer")
  );
  // _mintRecipient is slot 17. This can be found by creating a new Test.sol contract
  // with the storage fields and using `forge inspect Test storage-layout`
  const mintRecipientStorageSlot = BigNumber.from(libStorageSlot)
    .add(17)
    .toHexString();
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

  const safeTransferFrom1155Selector = "0xf242432a";
  const encodedParams = defaultAbiCoder.encode(
    ["address", "address", "uint256", "uint256", "bytes"],
    [token.address, AddressZero, 0, quantity, []]
  );
  const data = safeTransferFrom1155Selector + encodedParams.slice(2);

  await whileImpersonating(
    marketplaceContract.address,
    provider,
    async (impersonatedSigner) => {
      await impersonatedSigner.sendTransaction({ to: token.address, data });
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

export const txDataForPreviewOrder = (
  minter: Wallet,
  minimumReceived: any,
  maximumSpent: any,
  order: any
) => {
  const previewOrderSelector = "0x582d4241";
  const encodedParams = defaultAbiCoder.encode(
    [
      "address",
      "address",
      "tuple(uint8 itemType, address token, uint256 identifier, uint256 amount)[]",
      "tuple(uint8 itemType, address token, uint256 identifier, uint256 amount)[]",
      "bytes",
    ],
    [
      AddressZero,
      minter.address,
      minimumReceived,
      maximumSpent,
      order.extraData,
    ]
  );
  const data = previewOrderSelector + encodedParams.slice(2);
  return data;
};

export const returnDataToOfferAndConsideration = (returnData: string) => {
  const [offer, consideration] = defaultAbiCoder.decode(
    [
      "tuple(uint8, address, uint256, uint256)[]",
      "tuple(uint8, address, uint256, uint256, address)[]",
    ],
    returnData
  );
  return {
    offer: offer.map((o: any) => ({
      itemType: o[0],
      token: o[1],
      identifier: o[2],
      amount: o[3],
    })),
    consideration: consideration.map((c: any) => ({
      itemType: c[0],
      token: c[1],
      identifier: c[2],
      amount: c[3],
      recipient: c[4],
    })),
  };
};
