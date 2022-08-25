import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { IERC721SeaDrop, ISeaDrop, TestERC721 } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`Mint Allowed Token Holder (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: IERC721SeaDrop;
  let allowedNftToken: TestERC721;
  let deployer: Wallet;
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
    deployer = new ethers.Wallet(randomHex(32), provider as any);
    creator = new ethers.Wallet(randomHex(32), provider as any);
    minter = new ethers.Wallet(randomHex(32), provider as any);
    feeRecipient = new ethers.Wallet(randomHex(32), provider as any);

    // Add eth to wallets.
    await faucet(deployer.address, provider as any);
    await faucet(minter.address, provider as any);

    // Deploy Seadrop.
    const SeaDrop = await ethers.getContractFactory("SeaDrop");
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token.
    const SeaDropToken = await ethers.getContractFactory("ERC721SeaDrop");
    token = await SeaDropToken.deploy("", "", deployer.address, [
      seadrop.address,
    ]);

    // Deploy the allowed NFT token.
    const AllowedNftToken = await ethers.getContractFactory("TestERC721");
    allowedNftToken = await AllowedNftToken.deploy();

    // Configure token.
    await token.setMaxSupply(100);
    await token
      .connect(deployer)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true);

    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);

    // Get the most recent block timestamp to use for the drop stage start time.
    const mostRecentBlock = await provider.getBlock(
      await provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    // Create the drop stage object.
    const dropStage = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: mostRecentBlockTimestamp,
      endTime: mostRecentBlockTimestamp + 1000000,
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

  it("Should mint a token to a user with the allowed NFT token", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    expect(
      await seadrop.mintAllowedTokenHolder(
        token.address,
        feeRecipient.address,
        minter.address,
        mintParams,
        { value: 10000000000000 }
      )
    ).to.be.true;
  });
});
