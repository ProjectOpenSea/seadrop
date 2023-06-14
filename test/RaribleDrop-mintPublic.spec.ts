import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { ERC721PartnerRaribleDrop, IRaribleDrop } from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/RaribleDrop";
import type { Wallet } from "ethers";

describe(`RaribleDrop - Mint Public (v${VERSION})`, function () {
  const { provider } = ethers;
  let raribleDrop: IRaribleDrop;
  let token: ERC721PartnerRaribleDrop;
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
    for (const wallet of [owner, admin, payer, minter]) {
      await faucet(wallet.address, provider);
    }

    // Deploy RaribleDrop
    const RaribleDrop = await ethers.getContractFactory("RaribleDrop", owner);
    raribleDrop = await RaribleDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721PartnerRaribleDrop = await ethers.getContractFactory(
      "ERC721PartnerRaribleDrop",
      owner
    );
    token = await ERC721PartnerRaribleDrop.deploy("", "", admin.address, [
      raribleDrop.address,
    ]);

    // Configure token
    await token.setMaxSupply(100);
    await token.updateCreatorPayoutAddress(raribleDrop.address, creator.address);
    publicDrop = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };
    await token.connect(admin).updatePublicDrop(raribleDrop.address, publicDrop);
    await token.connect(owner).updatePublicDrop(raribleDrop.address, publicDrop);
    await token
      .connect(admin)
      .updateAllowedFeeRecipient(raribleDrop.address, feeRecipient.address, true);
  });

  it("Should mint a public stage", async () => {
    // Mint public with payer for minter.
    const value = BigNumber.from(publicDrop.mintPrice).mul(3);
    await expect(
      raribleDrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    ).to.be.revertedWith("PayerNotAllowed");

    expect(await raribleDrop.getPayers(token.address)).to.deep.eq([]);
    expect(await raribleDrop.getPayerIsAllowed(token.address, payer.address)).to.eq(
      false
    );

    // Allow the payer.
    await token.updatePayer(raribleDrop.address, payer.address, true);

    expect(await raribleDrop.getPayers(token.address)).to.deep.eq([payer.address]);
    expect(await raribleDrop.getPayerIsAllowed(token.address, payer.address)).to.eq(
      true
    );

    await expect(
      raribleDrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        payer.address,
        3, // mint quantity
        publicDrop.mintPrice,
        publicDrop.feeBps,
        0 // drop stage index (0 for public)
      );

    let minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);

    // Mint public with minter being payer.
    await expect(
      raribleDrop
        .connect(minter)
        .mintPublic(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          3,
          { value }
        )
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        3, // mint quantity
        publicDrop.mintPrice,
        publicDrop.feeBps,
        0 // drop stage index (0 for public)
      );

    minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(6);
    expect(await token.totalSupply()).to.eq(6);
  });

  it("Should not mint a public stage that hasn't started", async () => {
    // Set start time in the future.
    await token.updatePublicDrop(raribleDrop.address, {
      ...publicDrop,
      startTime: Math.round(Date.now() / 1000) + 100,
    });

    // Mint public with payer for minter.
    const value = BigNumber.from(publicDrop.mintPrice).mul(3);
    await expect(
      raribleDrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    ).to.be.revertedWith("NotActive");

    // Mint public with minter being payer.
    await expect(
      raribleDrop
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

  it("Should not mint a public stage that has ended", async () => {
    // Set start time in the future.
    await token.updatePublicDrop(raribleDrop.address, {
      ...publicDrop,
      endTime: Math.round(Date.now() / 1000) - 100,
    });

    // Mint public with payer for minter.
    const value = BigNumber.from(publicDrop.mintPrice).mul(3);
    await expect(
      raribleDrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    ).to.be.revertedWith("NotActive");

    // Mint public with minter being payer.
    await expect(
      raribleDrop
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
    publicDrop.maxTotalMintableByWallet = 2;
    await token.updatePublicDrop(raribleDrop.address, publicDrop);

    // Update max supply to 1.
    await token.setMaxSupply(1);

    // Mint one.
    const value = publicDrop.mintPrice;
    await expect(
      raribleDrop
        .connect(minter)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // mint quantity
        publicDrop.mintPrice,
        publicDrop.feeBps,
        0 // drop stage index (0 for public)
      );

    // Minting the next should throw MintQuantityExceedsMaxSupply.
    await expect(
      raribleDrop
        .connect(minter)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("MintQuantityExceedsMaxSupply");

    // Update max supply to 3.
    await token.setMaxSupply(3);

    // Mint one.
    await expect(
      raribleDrop
        .connect(minter)
        .mintPublic(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          1,
          {
            value,
          }
        )
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // mint quantity
        publicDrop.mintPrice,
        publicDrop.feeBps,
        0 // drop stage index (0 for public)
      );

    // Minting the next should throw MintQuantityExceedsMaxMintedPerWallet.
    await expect(
      raribleDrop
        .connect(minter)
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
      raribleDrop
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
      raribleDrop
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
      raribleDrop
        .connect(minter)
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
      raribleDrop
        .connect(minter)
        .mintPublic(token.address, creator.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("FeeRecipientNotAllowed");
  });

  it("Should not be able to set an invalid fee bps", async () => {
    await expect(
      token
        .connect(admin)
        .updatePublicDrop(raribleDrop.address, { ...publicDrop, feeBps: 15_000 })
    ).to.be.revertedWith("InvalidFeeBps");
  });

  it("Should mint when feeBps is zero", async () => {
    await token
      .connect(admin)
      .updatePublicDrop(raribleDrop.address, { ...publicDrop, feeBps: 0 });

    await expect(
      raribleDrop
        .connect(minter)
        .mintPublic(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          1,
          {
            value: publicDrop.mintPrice,
          }
        )
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // mint quantity
        publicDrop.mintPrice,
        0, // fee bps
        0 // drop stage index (0 for public)
      );
  });

  it("Should not be able to mint zero quantity", async () => {
    await expect(
      raribleDrop
        .connect(minter)
        .mintPublic(token.address, feeRecipient.address, minter.address, 0)
    ).to.be.revertedWith("MintQuantityCannotBeZero");
  });
});
