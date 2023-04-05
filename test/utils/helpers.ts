import { constants } from "ethers";

import { toBN } from "../seaport-utils/encoding";

import { whileImpersonating } from "./impersonate";

import type {
  ERC721SeaDrop,
  ConsiderationInterface,
} from "../../typechain-types";
import type { AdvancedOrder, OrderParameters } from "../seaport-utils/types";
import type { BigNumberish, Wallet, providers } from "ethers";

export const VERSION = "2.0.0";

export type AwaitedObject<T> = {
  [K in keyof T]: Awaited<T[K]>;
};

export enum MintType {
  PUBLIC = 0,
  ALLOW_LIST = 1,
  TOKEN_GATED = 2,
  SIGNED = 3,
}

export const createMintOrder = async ({
  token,
  quantity,
  feeRecipient,
  feeBps,
  mintPrice,
  minter,
  mintType,
  startTime,
  endTime,
}: {
  token: ERC721SeaDrop;
  quantity: BigNumberish;
  feeRecipient: Wallet;
  feeBps: BigNumberish;
  mintPrice: BigNumberish;
  minter: Wallet;
  mintType: MintType;
  startTime?: number;
  endTime?: number;
}) => {
  const offer = [
    {
      itemType: 3, // ERC1155
      token: token.address,
      identifierOrCriteria: toBN(0),
      startAmount: toBN(1),
      endAmount: toBN(1),
    },
  ];

  const totalValue = toBN(mintPrice).mul(quantity);
  const feeAmount = totalValue.mul(feeBps).div(toBN(10_000));
  const creatorAmount = totalValue.sub(feeAmount);

  const considerationItemFeeRecipient = {
    itemType: 0, // NATIVE
    token: constants.AddressZero,
    identifierOrCriteria: toBN(0),
    startAmount: feeAmount,
    endAmount: feeAmount,
    recipient: feeRecipient.address,
  };

  const considerationItemsCreatorPayouts = [];
  const creatorPayouts = await token.getCreatorPayouts();
  for (const creatorPayout of creatorPayouts) {
    const amount = creatorAmount.mul(creatorPayout.basisPoints).div(10_000);
    const considerationItem = {
      itemType: 0, // NATIVE
      token: constants.AddressZero,
      identifierOrCriteria: toBN(0),
      startAmount: amount,
      endAmount: amount,
      recipient: creatorPayout.payoutAddress,
    };
    considerationItemsCreatorPayouts.push(considerationItem);
  }

  const consideration = [
    considerationItemFeeRecipient,
    ...considerationItemsCreatorPayouts,
  ];

  const parameters: OrderParameters = {
    offerer: token.address,
    orderType: 4, // CONTRACT
    offer,
    consideration,
    startTime: startTime ?? Math.round(Date.now() / 1000) - 100,
    endTime: endTime ?? Math.round(Date.now() / 1000) + 100,
    zone: constants.AddressZero,
    zoneHash: constants.HashZero,
    salt: "0x00",
    conduitKey: constants.HashZero,
    totalOriginalConsiderationItems: consideration.length,
  };

  const extraData =
    "0x" +
    Buffer.concat([
      Buffer.from([0]), // SIP-6 version byte
      Buffer.from([mintType]), // substandard version byte
      Buffer.from(feeRecipient.address.slice(2), "hex"),
      Buffer.from(minter.address.slice(2), "hex"),
    ]).toString("hex");

  const order: AdvancedOrder = {
    parameters,
    numerator: 1,
    denominator: 1,
    signature: "0x",
    extraData,
  };

  return order;
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
