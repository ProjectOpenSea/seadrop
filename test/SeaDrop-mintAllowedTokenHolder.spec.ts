import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { ERC721SeaDrop, ISeaDrop, TestERC721 } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`SeaDrop - Mint Allowed Token Holder (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let allowedNftToken: TestERC721;
  let owner: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets.
    owner = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets.
    await faucet(owner.address, provider);
    await faucet(minter.address, provider);

    // Deploy Seadrop.
    const SeaDrop = await ethers.getContractFactory("SeaDrop");
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token.
    const SeaDropToken = await ethers.getContractFactory("ERC721SeaDrop");
    token = await SeaDropToken.deploy("", "", owner.address, [seadrop.address]);

    // Deploy the allowed NFT token.
    const AllowedNftToken = await ethers.getContractFactory("TestERC721");
    allowedNftToken = await AllowedNftToken.deploy();

    // Configure token.
    await token.setMaxSupply(100);
    await token
      .connect(owner)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true);

    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);

    // Create the drop stage object.
    const dropStage = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: 100,
      restrictFeeRecipients: false,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(
      seadrop.address,
      allowedNftToken.address,
      dropStage
    );
  });

  // TODO: Test for MintQuantityExceedsMaxTokenSupplyForStage

  it("Should mint a token to a user with the allowed NFT token", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    await expect(
      seadrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: 10000000000000 }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        1,
        10000000000000,
        0,
        1
      );
  });

  it("Should mint a token to a user with the allowed NFT token when the payer is different from the minter", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    await expect(
      seadrop
        .connect(owner)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: 10000000000000 }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        owner.address,
        1,
        10000000000000,
        0,
        1
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(1);
  });

  it("Should mint a token to a user with the allowed NFT token when the mint is free", async () => {
    // Create the free mint drop stage object.
    const dropStage = {
      mintPrice: "0",
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: 100,
      restrictFeeRecipients: false,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(
      seadrop.address,
      allowedNftToken.address,
      dropStage
    );

    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    await expect(
      seadrop
        .connect(owner)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        owner.address,
        1,
        0,
        0,
        1
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(1);
  });

  it("Should revert if the allowed NFT token has already been redeemed", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    await expect(
      seadrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: 10000000000000 }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        1,
        10000000000000,
        0,
        1
      );

    await expect(
      seadrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: 10000000000000 }
        )
    ).to.be.revertedWith(
      `TokenGatedTokenIdAlreadyRedeemed("${token.address}", "${allowedNftToken.address}", 0)`
    );
  });

  it("Should revert if the minter does not own the allowed NFT token passed into the call", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the owner.
    await allowedNftToken.mint(owner.address, 0);

    await expect(
      seadrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: 10000000000000 }
        )
    ).to.be.revertedWith(
      `TokenGatedNotTokenOwner("${token.address}", "${allowedNftToken.address}", 0)`
    );
  });

  it("Should revert if the drop stage is not active", async () => {
    // Create the drop stage object.
    const dropStage = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 1000,
      endTime: Math.round(Date.now() / 1000) - 500,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: 100,
      restrictFeeRecipients: false,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(
      seadrop.address,
      allowedNftToken.address,
      dropStage
    );

    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    await expect(
      seadrop
        .connect(owner)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams
        )
    ).to.be.revertedWith(
      `NotActive(${mostRecentBlockTimestamp + 1}, ${dropStage.startTime}, ${
        dropStage.endTime
      })`
    );
  });
});
