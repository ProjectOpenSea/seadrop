import { BigNumber, ethers } from "ethers";

export const VERSION = `1.0.0${process.env.REFERENCE ? "-reference" : ""}`;

export async function defaultGasOptions() {
  const gasPrice: BigNumber = await estimateGas();
  return {
    gasPrice,
    gasLimit: 302133,
  };
}

async function estimateGas() {
  let gasPrice: BigNumber = await ethers.providers
    .getDefaultProvider()
    .getGasPrice();
  const multiplier = 2.5; // avoids 'replacement fee too low' error.
  gasPrice = multiply(gasPrice, multiplier);

  return gasPrice;
}

function multiply(bn: BigNumber | string, number: number): BigNumber {
  const oneDotZero: BigNumber = ethers.utils.parseUnits("1", 18);
  const bnForSure = BigNumber.from(bn);
  const numberBN = ethers.utils.parseUnits(number.toString(), 18);

  return bnForSure.mul(numberBN).div(oneDotZero);
}
