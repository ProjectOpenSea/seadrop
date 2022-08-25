import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";

import { getRandomNumberBetween, randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721SeaDrop, IERC721, ISeaDrop } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let vanillaToken: IERC721;
  let owner: Wallet;
  let admin: Wallet;
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
    owner = new ethers.Wallet(randomHex(32), provider);
    admin = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    payer = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    await faucet(owner.address, provider);
    await faucet(admin.address, provider);
    await faucet(payer.address, provider);
    await faucet(minter.address, provider);

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", owner);
    seadrop = await SeaDrop.deploy();

    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy("", "", admin.address, [
      seadrop.address,
    ]);

    // Deploy vanilla (non-IER721SeaDrop) token
    const ERC721A = await ethers.getContractFactory("ERC721A", owner);
    vanillaToken = (await ERC721A.deploy("", "")) as unknown as IERC721;

    // Configure token
    // await token.setMaxSupply(100);
    // await token.updateAllowedFeeRecipient(
    //   seadrop.address,
    //   feeRecipient.address,
    //   true
    // );
    // await token.updateCreatorPayoutAddress(seadrop.address, creator.address);
    // feeBps = getRandomNumberBetween(100, 1000);
    // await token.updatePublicDropFee(seadrop.address, feeBps);
  });

  it("Should not let a non-IERC721SeaDrop token contract use the token methods", async () => {
    whileImpersonating(vanillaToken.address, provider, async () => {
      await expect(
        seadrop.connect(vanillaToken.address).updateDropURI("http://test.com")
      ).to.revertedWith("OnlyIERC721SeaDrop");
    });
  });
});
