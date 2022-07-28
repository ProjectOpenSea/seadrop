import { expect } from "chai";
import { ethers, network } from "hardhat";

import { VERSION } from "./utils/helpers";

import type { ShipyardInterface } from "../typechain-types";

describe(`Sample tests (Shipyard v${VERSION})`, function () {
  let shipyardContract: ShipyardInterface;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    const ShipyardContractFactory = await ethers.getContractFactory("Shipyard");
    shipyardContract =
      (await ShipyardContractFactory.deploy()) as ShipyardInterface;
  });

  it("is greeted", async () => {
    const greeting = await shipyardContract.greet();
    expect(greeting).to.equal("Ahoy");
  });
});
