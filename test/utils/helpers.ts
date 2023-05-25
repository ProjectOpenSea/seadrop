import { setCode } from "@nomicfoundation/hardhat-network-helpers";
import { ethers } from "hardhat";

import {
  IERC1155SeaDrop__factory,
  IERC721SeaDrop__factory,
} from "../../typechain-types";

import { MintType, createMintOrder } from "./order";

import type {
  ConsiderationInterface,
  ERC1155SeaDrop,
  ERC721SeaDrop,
  IERC1155SeaDrop,
  IERC721SeaDrop,
} from "../../typechain-types";
import type { Wallet } from "ethers";

const { provider } = ethers;
const { AddressZero, HashZero } = ethers.constants;
const { defaultAbiCoder } = ethers.utils;

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
    "Test721",
    "T721",
    configurer.address,
    conduit,
    marketplaceContract
  );

  const tokenSeaDropInterface = IERC721SeaDrop__factory.connect(
    token.address,
    owner
  );

  return { configurer, token, tokenSeaDropInterface };
};

export const deployERC1155SeaDrop = async (
  owner: Wallet,
  marketplaceContract: string,
  conduit: string
) => {
  // Deploy configurer
  const ERC1155SeaDropConfigurer = await ethers.getContractFactory(
    "ERC1155SeaDropConfigurer",
    owner
  );
  const configurer = await ERC1155SeaDropConfigurer.deploy();

  // Deploy token
  const ERC1155SeaDrop = await ethers.getContractFactory(
    "ERC1155SeaDrop",
    owner
  );
  const token = await ERC1155SeaDrop.deploy(
    "Test1155",
    "T1155",
    configurer.address,
    conduit,
    marketplaceContract
  );

  const tokenSeaDropInterface = IERC1155SeaDrop__factory.connect(
    token.address,
    owner
  );

  return { configurer, token, tokenSeaDropInterface };
};

export const mintTokens = async ({
  marketplaceContract,
  token,
  tokenSeaDropInterface,
  minter,
  tokenId,
  quantity,
}: {
  marketplaceContract: ConsiderationInterface;
  token: ERC721SeaDrop | ERC1155SeaDrop;
  tokenSeaDropInterface: IERC721SeaDrop | IERC1155SeaDrop;
  minter: Wallet;
  tokenId?: number;
  quantity: number;
}) => {
  const seadrop1155 = tokenId !== undefined;
  const publicDropIndex = 0;

  const prevPublicDrop = await (seadrop1155
    ? (tokenSeaDropInterface as IERC1155SeaDrop).getPublicDrop(publicDropIndex)
    : (tokenSeaDropInterface as IERC721SeaDrop).getPublicDrop());

  const temporaryPublicDrop: any = {
    startPrice: 0,
    endPrice: 0,
    startTime: Math.round(Date.now() / 1000) - 1000,
    endTime: Math.round(Date.now() / 1000) + 5000,
    paymentToken: AddressZero,
    maxTotalMintableByWallet: 1000,
    feeBps: 0,
    restrictFeeRecipients: false,
  };
  if (seadrop1155) {
    temporaryPublicDrop.fromTokenId = tokenId;
    temporaryPublicDrop.toTokenId = tokenId;
    temporaryPublicDrop.maxTotalMintableByWalletPerToken = 1000;
  }
  await (seadrop1155
    ? (tokenSeaDropInterface as IERC1155SeaDrop).updatePublicDrop(
        temporaryPublicDrop,
        publicDropIndex
      )
    : (tokenSeaDropInterface as IERC721SeaDrop).updatePublicDrop(
        temporaryPublicDrop
      ));

  const { order, value } = await createMintOrder({
    token,
    tokenSeaDropInterface,
    tokenId,
    publicDropIndex: seadrop1155 ? publicDropIndex : undefined,
    quantity,
    feeRecipient: { address: `0x${"1".repeat(40)}` } as any,
    feeBps: 0,
    price: 0,
    minter,
    mintType: MintType.PUBLIC,
  });

  await marketplaceContract
    .connect(minter)
    .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value });

  // Reset the public drop.
  await (seadrop1155
    ? (tokenSeaDropInterface as IERC1155SeaDrop).updatePublicDrop(
        prevPublicDrop as any,
        publicDropIndex
      )
    : (tokenSeaDropInterface as IERC721SeaDrop).updatePublicDrop(
        prevPublicDrop
      ));
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
