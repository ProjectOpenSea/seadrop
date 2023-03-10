import { BigNumber, ethers } from "ethers";

import type { JsonRpcProvider } from "@ethersproject/providers";

export const getPrevRandaoForOffset = (
  targetOffset: number,
  maxSupply: number
) => {
  let i = 0;
  while (true) {
    // Feels like proof-of-work all over again
    const hash = ethers.utils.solidityKeccak256(
      ["bytes"],
      [ethers.utils.defaultAbiCoder.encode(["uint256"], [i])]
    );
    const offset = BigNumber.from(hash).mod(maxSupply).toNumber();
    if (offset === targetOffset) {
      return i;
    }
    i++;
  }
};

export const setPrevRandao = (n: number, provider: JsonRpcProvider) => {
  const prevRandao = `0x${n.toString(16).padStart(64, "0")}`;
  return provider.send("hardhat_setPrevRandao", [prevRandao]);
};
