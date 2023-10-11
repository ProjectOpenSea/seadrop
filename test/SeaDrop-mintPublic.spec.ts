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
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let owner: Wallet;
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
    creator = new ethers.Wallet(randomHex(32), provider);
    payer = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, payer, minter]) {
      await faucet(wallet.address, provider);
    }

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
    token = await ERC721SeaDrop.deploy("", "", [seadrop.address]);

    // Configure token
    await token.setMaxSupply(100);
    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);
    publicDrop = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };
    await token.updatePublicDrop(seadrop.address, publicDrop);
    await token.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      true
    );
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
    ).to.be.revertedWith("PayerNotAllowed");

    expect(await seadrop.getPayers(token.address)).to.deep.eq([]);
    expect(await seadrop.getPayerIsAllowed(token.address, payer.address)).to.eq(
      false
    );

    // Allow the payer.
    await token.updatePayer(seadrop.address, payer.address, true);

    expect(await seadrop.getPayers(token.address)).to.deep.eq([payer.address]);
    expect(await seadrop.getPayerIsAllowed(token.address, payer.address)).to.eq(
      true
    );

    await expect(
      seadrop
        .connect(payer)
        .mintPublic(token.address, feeRecipient.address, minter.address, 3, {
          value,
        })
    )
      .to.emit(seadrop, "SeaDropMint")
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
      seadrop
        .connect(minter)
        .mintPublic(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          3,
          { value }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
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
    await token.updatePublicDrop(seadrop.address, {
      ...publicDrop,
      startTime: Math.round(Date.now() / 1000) + 100,
    });

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

  it("Should not mint a public stage that has ended", async () => {
    // Set start time in the future.
    await token.updatePublicDrop(seadrop.address, {
      ...publicDrop,
      endTime: Math.round(Date.now() / 1000) - 100,
    });

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
    publicDrop.maxTotalMintableByWallet = 2;
    await token.updatePublicDrop(seadrop.address, publicDrop);

    // Update max supply to 1.
    await token.setMaxSupply(1);

    // Mint one.
    const value = publicDrop.mintPrice;
    await expect(
      seadrop
        .connect(minter)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    )
      .to.emit(seadrop, "SeaDropMint")
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
      seadrop
        .connect(minter)
        .mintPublic(token.address, feeRecipient.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("MintQuantityExceedsMaxSupply");

    // Update max supply to 3.
    await token.setMaxSupply(3);

    // Mint one.
    await expect(
      seadrop
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
      .to.emit(seadrop, "SeaDropMint")
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
      seadrop
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
      seadrop
        .connect(minter)
        .mintPublic(token.address, creator.address, minter.address, 1, {
          value,
        })
    ).to.be.revertedWith("FeeRecipientNotAllowed");
  });

  it("Should not be able to set an invalid fee bps", async () => {
    await expect(
      token.updatePublicDrop(seadrop.address, { ...publicDrop, feeBps: 15_000 })
    ).to.be.revertedWith("InvalidFeeBps");
  });

  it("Should mint when feeBps is zero", async () => {
    await token.updatePublicDrop(seadrop.address, { ...publicDrop, feeBps: 0 });

    await expect(
      seadrop
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
      .to.emit(seadrop, "SeaDropMint")
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
      seadrop
        .connect(minter)
        .mintPublic(token.address, feeRecipient.address, minter.address, 0)
    ).to.be.revertedWith("MintQuantityCannotBeZero");
  });
});
