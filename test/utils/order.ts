import { ethers } from "ethers";

import { toBN } from "../seaport-utils/encoding";

import { toPaddedBuffer } from "./encoding";

import type {
  ERC721SeaDrop,
  ERC721SeaDropConfigurer,
  TestERC20,
} from "../../typechain-types";
import type {
  MintParamsStruct,
  TokenGatedMintParamsStruct,
} from "../../typechain-types/src/shim/Shim";
import type { AdvancedOrder, OrderParameters } from "../seaport-utils/types";
import type { BigNumberish, Wallet } from "ethers";
import { AwaitedObject } from "./helpers";

const { AddressZero, HashZero } = ethers.constants;
const { defaultAbiCoder } = ethers.utils;

export const expectedPrice = ({
  startPrice,
  endPrice,
  startTime,
  endTime,
  blockTimestamp,
}: {
  startPrice: BigNumberish;
  endPrice: BigNumberish;
  startTime: BigNumberish;
  endTime: BigNumberish;
  blockTimestamp: BigNumberish;
}) => {
  const duration = toBN(endTime).sub(startTime);
  const elapsed = toBN(blockTimestamp).sub(startTime);
  const remaining = duration.sub(elapsed);
  const totalBeforeDivision = toBN(startPrice)
    .mul(remaining)
    .add(toBN(endPrice).mul(elapsed));
  const price = totalBeforeDivision.div(duration);
  return price;
};

export enum MintType {
  PUBLIC = 0,
  ALLOW_LIST = 1,
  TOKEN_GATED = 2,
  SIGNED = 3,
}

export const createMintOrder = async ({
  token,
  configurer,
  quantity,
  feeRecipient,
  feeBps,
  price,
  paymentToken,
  minter,
  mintType,
  startTime,
  endTime,
  mintParams,
  // Allow list
  proof,
  // Token gated
  tokenGatedMintParams,
  // Signed
  salt,
  signature,
}: {
  token: ERC721SeaDrop;
  configurer: ERC721SeaDropConfigurer;
  quantity?: BigNumberish;
  feeRecipient: Wallet;
  feeBps: BigNumberish;
  price: BigNumberish;
  paymentToken?: TestERC20;
  minter: Wallet;
  mintType: MintType;
  startTime?: number;
  endTime?: number;
  mintParams?: AwaitedObject<MintParamsStruct>;
  proof?: string[];
  tokenGatedMintParams?: AwaitedObject<TokenGatedMintParamsStruct>;
  signature?: string;
  salt?: string;
}) => {
  const paymentTokenAddress = paymentToken?.address ?? AddressZero;

  if (mintType === MintType.TOKEN_GATED) {
    if (!tokenGatedMintParams)
      throw new Error("Token gated mint params required for token gated mint");
    quantity = (tokenGatedMintParams?.amounts as number[]).reduce(
      (prev, curr) => prev + curr,
      0
    );
  }
  if (quantity === undefined)
    throw new Error("Quantity missing for mint order");

  const offer = [
    {
      itemType: 3, // ERC1155
      token: token.address,
      identifierOrCriteria: toBN(0),
      startAmount: toBN(quantity),
      endAmount: toBN(quantity),
    },
  ];

  const value = toBN(price).mul(quantity);
  const feeAmount = value.mul(feeBps).div(10_000);
  const creatorAmount = value.sub(feeAmount);

  const itemType = paymentTokenAddress === AddressZero ? 0 : 1;
  const consideration = [];

  if (feeAmount.gt(0)) {
    const considerationItemFeeRecipient = {
      itemType,
      token: paymentTokenAddress,
      identifierOrCriteria: toBN(0),
      startAmount: feeAmount,
      endAmount: feeAmount,
      recipient: feeRecipient.address,
    };
    consideration.push(considerationItemFeeRecipient);
  }

  const creatorPayouts = await configurer.getCreatorPayouts(token.address);
  for (const creatorPayout of creatorPayouts) {
    const amount = creatorAmount.mul(creatorPayout.basisPoints).div(10_000);
    const considerationItem = {
      itemType,
      token: paymentTokenAddress,
      identifierOrCriteria: toBN(0),
      startAmount: amount,
      endAmount: amount,
      recipient: creatorPayout.payoutAddress,
    };
    consideration.push(considerationItem);
  }

  const parameters: OrderParameters = {
    offerer: token.address,
    orderType: 4, // CONTRACT
    offer,
    consideration,
    startTime: startTime ?? Math.round(Date.now() / 1000) - 100,
    endTime: endTime ?? Math.round(Date.now() / 1000) + 500,
    zone: AddressZero,
    zoneHash: HashZero,
    salt: "0x00",
    conduitKey: HashZero,
    totalOriginalConsiderationItems: consideration.length,
  };

  let extraDataBuffer = Buffer.concat([
    Buffer.from([0]), // SIP-6 version byte
    Buffer.from([mintType]), // substandard version byte
    Buffer.from(feeRecipient.address.slice(2), "hex"),
    Buffer.from(minter.address.slice(2), "hex"),
  ]);

  switch (mintType) {
    case MintType.ALLOW_LIST:
      if (!mintParams)
        throw new Error("Mint params required for allow list mint");
      if (!proof) throw new Error("Proof required for allow list mint");
      extraDataBuffer = Buffer.concat([
        extraDataBuffer,
        mintParamsBuffer(mintParams),
        ...proof.map((p) => Buffer.from(p.slice(2), "hex")),
      ]);
      break;
    case MintType.TOKEN_GATED:
      if (!tokenGatedMintParams)
        throw new Error(
          "Token gated mint params required for token gated mint"
        );
      extraDataBuffer = Buffer.concat([
        extraDataBuffer,
        tokenGatedMintParamsBuffer(tokenGatedMintParams),
      ]);
      break;
    case MintType.SIGNED:
      if (!mintParams) throw new Error("Mint params required for signed mint");
      if (!salt) throw new Error("Salt required for signed mint");
      if (!signature) throw new Error("Signature required for signed mint");
      extraDataBuffer = Buffer.concat([
        extraDataBuffer,
        mintParamsBuffer(mintParams),
        Buffer.from(salt.slice(2), "hex"),
        Buffer.from(signature.slice(2), "hex"),
      ]);
      break;
    default:
      break;
  }

  const extraData = "0x" + extraDataBuffer.toString("hex");

  const order: AdvancedOrder = {
    parameters,
    numerator: 1,
    denominator: 1,
    signature: "0x",
    extraData,
  };

  return { order, value };
};

export const mintParamsBuffer = (mintParams: MintParamsStruct) =>
  Buffer.concat(
    [
      mintParams.startPrice,
      mintParams.endPrice,
      mintParams.paymentToken,
      mintParams.maxTotalMintableByWallet,
      mintParams.startTime,
      mintParams.endTime,
      mintParams.dropStageIndex,
      mintParams.maxTokenSupplyForStage,
      mintParams.feeBps,
      mintParams.restrictFeeRecipients ? 1 : 0,
    ].map(toPaddedBuffer)
  );

const tokenGatedMintParamsBuffer = (mintParams: TokenGatedMintParamsStruct) =>
  Buffer.from(
    defaultAbiCoder
      .encode(
        [
          "tuple(address allowedNftToken, uint256[] allowedNftTokenIds, uint256[] amounts)",
        ],
        [mintParams]
      )
      .slice(2),
    "hex"
  );
