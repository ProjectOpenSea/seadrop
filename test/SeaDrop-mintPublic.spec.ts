import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { ERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/SeaDrop";
import type { Wallet } from "ethers";

describe(`SeaDrop - Mint Public (v${VERSION})`, function () {
  const { provider } = ethers as any;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let owner: Wallet;
  let admin: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let publicDrop: PublicDropStruct;

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
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy("", "", admin.address, [
      seadrop.address,
    ]);

    // Configure token
    await token.setMaxSupply(100);
    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);
    publicDrop = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxMintsPerWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      feeBps: 1000,
      restrictFeeRecipients: false,
    };
    await token.updatePublicDrop(seadrop.address, publicDrop);

    // Only the admin can update fee bps and fee recipient.
    await token
      .connect(admin)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true);
    await token
      .connect(admin)
      .updatePublicDropFee(seadrop.address, publicDrop.feeBps);
  });

  it("Should mint a public stage", async () => {
    // Mint public with payer for minter.
    const value = BigNumber.from(publicDrop.mintPrice).mul(3);
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    ).to.emit(seadrop, "SeaDropMint");
    let minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);

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
    expect(await token.totalSupply()).to.eq(6);
  });

  it("Should not mint a public stage that hasn't started", async () => {
    // Set start time in the future.
    publicDrop.startTime = Math.round(Date.now() / 1000) + 100;
    await token.updatePublicDrop(seadrop.address, publicDrop);

    // Mint public with payer for minter.
    const value = BigNumber.from(publicDrop.mintPrice).mul(3);
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    ).to.be.revertedWith("NotActive");

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
    ).to.be.revertedWith("NotActive");
  });

  it("Should respect limit for max mints per wallet and max supply", async () => {
    // Update max limit per wallet to 2.
    publicDrop.maxMintsPerWallet = 2;
    await token.updatePublicDrop(seadrop.address, publicDrop);

    // Update max supply to 1.
    await token.setMaxSupply(1);

    // Mint one.
    const value = publicDrop.mintPrice;
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.emit(seadrop, "SeaDropMint");

    // Minting the next should throw MintQuantityExceedsMaxSupply.
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("MintQuantityExceedsMaxSupply");

    // Update max supply to 3.
    await token.setMaxSupply(3);

    // Mint one.
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.emit(seadrop, "SeaDropMint");

    // Minting the next should throw MintQuantityExceedsMaxMintedPerWallet.
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("MintQuantityExceedsMaxMintedPerWallet");
  });

  it("Should not mint with incorrect payment", async () => {
    // Pay for only 1 mint, but request quantity of 2.
    let value = BigNumber.from(publicDrop.mintPrice);
    let mintQuantity = 2;

    await expect(
      seadrop
        .connect(payer)
        .mintPublic(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          {
            value,
          }
        )
    ).to.be.revertedWith("IncorrectPayment");

    // Pay for 3 mints but request quantity of 2.
    value = BigNumber.from(publicDrop.mintPrice).mul(3);
    mintQuantity = 2;
    await expect(
      seadrop
        .connect(minter)
        .mintPublic(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          { value }
        )
    ).to.be.revertedWith("IncorrectPayment");
  });

  it("Should not mint with invalid fee recipient", async () => {
    const value = BigNumber.from(publicDrop.mintPrice);
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(
          token.address,
          ethers.constants.AddressZero,
          minter.address,
          1,
          {
            value,
          }
        )
    ).to.be.revertedWith("FeeRecipientCannotBeZeroAddress");

    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, creator.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("FeeRecipientNotAllowed");
  });

  it("Should not mint with invalid fee bps", async () => {
    await token.connect(admin).updatePublicDropFee(seadrop.address, 15_000);

    const value = BigNumber.from(publicDrop.mintPrice);
    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("InvalidFeeBps");

    await token.connect(admin).updatePublicDropFee(seadrop.address, 0);

    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.emit(seadrop, "SeaDropMint");
  });
});
