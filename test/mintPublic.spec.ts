import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";

import { getRandomNumberBetween, randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { ERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/SeaDrop";
import type { Wallet } from "ethers";

describe(`Mint Public (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let deployer: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let feeBps: number;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets
    deployer = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    payer = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    await faucet(deployer.address, provider);
    await faucet(payer.address, provider);
    await faucet(minter.address, provider);

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", deployer);
    seadrop = await SeaDrop.deploy();

    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      deployer
    );
    token = await ERC721SeaDrop.deploy("", "", deployer.address, [
      seadrop.address,
    ]);

    // Configure token
    await token.setMaxSupply(100);
    await token.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      true
    );
    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);
    feeBps = getRandomNumberBetween(100, 1000);
    await token.updatePublicDropFee(seadrop.address, feeBps);
  });

  it("can mint a public stage", async () => {
    const publicDrop: PublicDropStruct = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxMintsPerWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      feeBps,
      restrictFeeRecipients: false,
    };

    await token.updatePublicDrop(seadrop.address, publicDrop);

    const value = BigNumber.from(publicDrop.mintPrice).mul(3);

    // Mint public with payer for minter.
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    ).to.emit(seadrop, "SeaDropMint");
    let minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);

    // Mint public with minter being payer.
    await expect(
      seadrop
        .connect(minter)
        .mintPublic(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          3,
          { value }
        )
    ).to.emit(seadrop, "SeaDropMint");
    minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(6);
  });
});
