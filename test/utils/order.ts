import { ethers } from "ethers";

import { toBN } from "../seaport-utils/encoding";

import { toPaddedBuffer } from "./encoding";

import type { AwaitedObject } from "./helpers";
import type {
  ERC1155SeaDrop,
  ERC721SeaDrop,
  IERC1155SeaDrop,
  IERC721SeaDrop,
  TestERC20,
} from "../../typechain-types";
import type { MintParamsStruct as MintParamsStruct721 } from "../../typechain-types/src/shim/Shim";
import type { MintParamsStruct as MintParamsStruct1155 } from "../../typechain-types/src/shim/Shim2";
import type { AdvancedOrder, OrderParameters } from "../seaport-utils/types";
import type { BigNumberish, Wallet } from "ethers";

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
  SIGNED = 2,
}

export const createMintOrder = async ({
  token,
  tokenSeaDropInterface,
  tokenId,
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
  // Signed
  salt,
  signature,
  // 1155
  publicDropIndex,
}: {
  token: ERC721SeaDrop | ERC1155SeaDrop;
  tokenSeaDropInterface: IERC721SeaDrop | IERC1155SeaDrop;
  tokenId?: BigNumberish;
  quantity: BigNumberish;
  feeRecipient: Wallet;
  feeBps: BigNumberish;
  price: BigNumberish;
  paymentToken?: TestERC20;
  minter: Wallet;
  mintType: MintType;
  startTime?: number;
  endTime?: number;
  mintParams?: AwaitedObject<MintParamsStruct721 | MintParamsStruct1155>;
  proof?: string[];
  signature?: string;
  salt?: string;
  publicDropIndex?: number;
}) => {
  const paymentTokenAddress = paymentToken?.address ?? AddressZero;

  const offer = [
    {
      itemType: 3, // ERC1155
      token: token.address,
      identifierOrCriteria: toBN(tokenId ?? 0),
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

  const creatorPayouts = await tokenSeaDropInterface.getCreatorPayouts();
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
    case MintType.PUBLIC:
      if (publicDropIndex !== undefined) {
        extraDataBuffer = Buffer.concat([
          extraDataBuffer,
          Buffer.from(publicDropIndex.toString(16).padStart(2, "0"), "hex"),
        ]);
      }
      break;
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

export const mintParamsBuffer = (
  mintParams: MintParamsStruct721 | MintParamsStruct1155
) =>
  Buffer.concat(
    (Object.keys(mintParams).length === 10
      ? [
          mintParams.startPrice,
          mintParams.endPrice,
          mintParams.startTime,
          mintParams.endTime,
          mintParams.paymentToken,
          mintParams.maxTotalMintableByWallet,
          mintParams.maxTokenSupplyForStage,
          mintParams.dropStageIndex,
          mintParams.feeBps,
          mintParams.restrictFeeRecipients ? 1 : 0,
        ]
      : [
          mintParams.startPrice,
          mintParams.endPrice,
          mintParams.startTime,
          mintParams.endTime,
          mintParams.paymentToken,
          (mintParams as MintParamsStruct1155).fromTokenId,
          (mintParams as MintParamsStruct1155).toTokenId,
          mintParams.maxTotalMintableByWallet,
          (mintParams as MintParamsStruct1155).maxTotalMintableByWalletPerToken,
          mintParams.maxTokenSupplyForStage,
          mintParams.dropStageIndex,
          mintParams.feeBps,
          mintParams.restrictFeeRecipients ? 1 : 0,
        ]
    ).map(toPaddedBuffer)
  );
