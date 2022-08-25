import { faucet } from "./faucet";

import type { JsonRpcProvider } from "@ethersproject/providers";

export const impersonate = async (
  address: string,
  provider: JsonRpcProvider
) => {
  await provider.send("hardhat_impersonateAccount", [address]);
  await faucet(address, provider);
};

export const stopImpersonation = async (
  address: string,
  provider: JsonRpcProvider
) => {
  await provider.send("hardhat_stopImpersonatingAccount", [address]);
};

export const whileImpersonating = async <T>(
  address: string,
  provider: JsonRpcProvider,
  fn: () => T
) => {
  await impersonate(address, provider);
  const result = await fn();
  await stopImpersonation(address, provider);
  return result;
};
