import { whileImpersonating } from "./impersonate";

import type {
  ConsiderationInterface,
  ERC721SeaDrop,
} from "../../typechain-types";
import type { Wallet, providers } from "ethers";

export const VERSION = "2.0.0";

export type AwaitedObject<T> = {
  [K in keyof T]: Awaited<T[K]>;
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
