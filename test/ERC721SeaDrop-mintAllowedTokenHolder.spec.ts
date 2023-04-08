import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { MintType, createMintOrder } from "./utils/order";

import type { AwaitedObject } from "./utils/helpers";
import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDrop,
  TestERC721,
} from "../typechain-types";
import type { TokenGatedDropStageStruct } from "../typechain-types/src/lib/SeaDropErrorsAndEvents";
import type { Wallet } from "ethers";

const { BigNumber } = ethers;
const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`SeaDrop - Mint Allowed Token Holder (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
  let allowedNftToken: TestERC721;
  let owner: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let dropStage: AwaitedObject<TokenGatedDropStageStruct>;

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
    for (const wallet of [owner, minter]) {
      await faucet(wallet.address, provider);
    }
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy(
      "",
      "",
      marketplaceContract.address,
      conduitOne.address
    );

    // Deploy the allowed NFT token.
    const AllowedNftToken = await ethers.getContractFactory("TestERC721");
    allowedNftToken = await AllowedNftToken.deploy();

    // Configure token.
    await token.setMaxSupply(100);
    await token.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
    await token.updateAllowedFeeRecipient(feeRecipient.address, true);

    // Create the drop stage object.
    dropStage = {
      mintPrice: parseEther("0.1"),
      paymentToken: AddressZero,
      maxMintablePerRedeemedToken: 3,
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 100,
      restrictFeeRecipients: true,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(allowedNftToken.address, dropStage);
  });

  it("Should mint a token to a user with the allowed NFT token", async () => {
    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Ensure the token id has not been redeemed.
    expect(
      await token.getAllowedNftTokenIdRedeemedCount(
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.eq(0);

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // Mint the token to the minter and verify the expected event was emitted.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address,
        1, // mint quantity
        dropStage.mintPrice,
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    // Ensure the token id redeemed count is accurate.
    expect(
      await token.getAllowedNftTokenIdRedeemedCount(
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.eq(1);

    expect(await token.getTokenGatedAllowedTokens()).to.deep.eq([
      allowedNftToken.address,
    ]);
  });

  it("Should mint a token to a user with the allowed NFT token when the payer is different from the minter", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // The payer must be allowed first.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // PayerNotAllowed

    // Allow the payer.
    await token.connect(owner).updatePayer(owner.address, true);

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        owner.address,
        1, // mint quantity
        dropStage.mintPrice,
        dropStage.paymentToken,
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(1);
  });

  it("Should mint a token to a user with the allowed NFT token when the mint is free", async () => {
    // Create the free mint drop stage object.
    const dropStageFreeMint = { ...dropStage, mintPrice: 0 };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(
      allowedNftToken.address,
      dropStageFreeMint
    );

    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address,
        1, // mint quantity
        0, // mint price: free
        dropStage.paymentToken,
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(1);
  });

  it("Should revert if the allowed NFT token has already been redeemed", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [3],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address,
        3, // mint quantity
        dropStage.mintPrice,
        dropStage.paymentToken,
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // TokenGatedTokenIdMintExceedsQuantityRemaining
    // withArgs(allowedNftToken.address, mintParams.allowedNftTokenIds[0], dropStage.maxMintablePerRedeemedToken, 3, 3)
  });

  it("Should revert if the minter does not own the allowed NFT token passed into the call", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the owner.
    await allowedNftToken.mint(owner.address, 0);

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // TokenGatedNotTokenOwner
    // withArgs(allowedNftToken.address, 0)
  });

  it("Should revert if the drop stage is not active", async () => {
    // Create the drop stage object.
    const dropStageExpired = {
      ...dropStage,
      endTime: Math.round(Date.now() / 1000) - 500,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(allowedNftToken.address, dropStageExpired);

    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    // Disable eslint for unused variable until we can check the proper revert message args again in the future.
    /* eslint-disable @typescript-eslint/no-unused-vars */
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive
    // withArgs(mostRecentBlockTimestamp + 1, dropStage.startTime, dropStageExpired.endTime)
  });

  it("Should not mint an allowed token holder stage with a different fee recipient", async () => {
    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    const { order, value } = await createMintOrder({
      token,
      feeRecipient: minter,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // Expect the transaction to revert since an incorrect fee recipient was given.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // FeeRecipientNotAllowed
    // withArgs(minter.address)
  });

  it("Should not mint an allowed token holder stage with a different token contract", async () => {
    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Deploy a new ERC721PartnerSeaDrop.
    const ERC721SeaDrop = await ethers.getContractFactory("ERC721SeaDrop");
    const differentToken = await ERC721SeaDrop.deploy(
      "",
      "",
      marketplaceContract.address,
      conduitOne.address
    );

    // Update the fee recipient and creator payout address for the new token.
    await differentToken.setMaxSupply(1000);
    await differentToken
      .connect(owner)
      .updateAllowedFeeRecipient(feeRecipient.address, true);
    await token.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // Expect the transaction to revert since a different token address was given.
    // Transaction will revert with NotActive() because startTime and endTime for
    // a nonexistent drop stage will be 0.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive
    // withArgs(mostRecentBlockTimestamp + 1, 0, 0)
  });

  it("Should not mint an allowed token holder stage with different mint params", async () => {
    // Deploy a different allowed NFT token.
    const AllowedNftToken = await ethers.getContractFactory("TestERC721");
    const differentAllowedNftToken = await AllowedNftToken.deploy();

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: differentAllowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    // Mint an allowedNftToken to the minter with a tokenId not included in the mintParams.
    await allowedNftToken.mint(minter.address, 0);

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // Expect the transaction to revert since a different token address was passed to the mintParams.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive
    // withArgs(mostRecentBlockTimestamp + 1, 0, 0)
  });

  it("Should not mint an allowed token holder stage after exceeding max mints per wallet", async () => {
    // Create an array of tokenIds with length exceeding maxTotalMintableByWallet.
    const tokenIds = [...Array(20).keys()];

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: tokenIds,
      amounts: tokenIds.map(() => 1),
    };

    // Mint the tokenIds in the mintParams to the minter.
    for (const id of tokenIds) {
      await allowedNftToken.mint(minter.address, id);
    }

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // Expect the transaction to revert since the mint quantity exceeds the
    // max total mintable by a wallet.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxMintedPerWallet
    // withArgs(tokenIds.length, dropStage.maxTotalMintableByWallet)
  });

  it("Should not mint an allowed token holder stage after exceeding max token supply for stage", async () => {
    // Create a new drop stage object.
    const newDropStage = {
      ...dropStage,
      maxTotalMintableByWallet: 20,
      maxTokenSupplyForStage: 5,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token
      .connect(owner)
      .updateTokenGatedDrop(allowedNftToken.address, newDropStage);

    // Create an array of tokenIds with length exceeding maxTotalMintableByWallet.
    const tokenIds = [...Array(20).keys()];

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: tokenIds,
      amounts: tokenIds.map(() => 1),
    };

    // Mint the tokenIds in the mintParams to the minter.
    for (const id of tokenIds) {
      await allowedNftToken.mint(minter.address, id);
    }

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // Expect the transaction to revert since the mint quantity exceeds the
    // max total mintable by a wallet.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxTokenSupplyForStage
    // withArgs(tokenIds.length, 5)
  });

  it("Should not mint an allowed token holder stage after exceeding max token supply", async () => {
    const newDropStage = {
      ...dropStage,
      maxTotalMintableByWallet: 110,
      maxTokenSupplyForStage: 110,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(allowedNftToken.address, newDropStage);

    // Create an array of tokenIds with length exceeding maxTotalMintableByWallet.
    const tokenIds = [...Array(110).keys()];

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: tokenIds,
      amounts: tokenIds.map(() => 1),
    };

    // Mint the tokenIds in the mintParams to the minter.
    for (const id of tokenIds) {
      await allowedNftToken.mint(minter.address, id);
    }

    const { order, value } = await createMintOrder({
      token,
      feeRecipient,
      feeBps: dropStage.feeBps,
      mintPrice: dropStage.mintPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // Expect the transaction to revert since the mint quantity exceeds the
    // max supply.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxSupply
    // withArgs(tokenIds.length, 100)
  });

  it("Should not be able to set an allowedNftToken to the drop token itself or zero address", async () => {
    await expect(
      token.connect(owner).updateTokenGatedDrop(token.address, dropStage)
    ).to.be.revertedWithCustomError(
      token,
      "TokenGatedDropAllowedNftTokenCannotBeDropToken"
    );

    await expect(
      token.connect(owner).updateTokenGatedDrop(AddressZero, dropStage)
    ).to.be.revertedWithCustomError(
      token,
      "TokenGatedDropAllowedNftTokenCannotBeZeroAddress"
    );
  });

  it("Should not be able to set an invalid fee bps", async () => {
    await expect(
      token.connect(owner).updateTokenGatedDrop(allowedNftToken.address, {
        ...dropStage,
        feeBps: 15_000,
      })
    ).to.be.revertedWithCustomError(token, "InvalidFeeBps");
  });

  it("Should revert when stage not present or fee not set", async () => {
    // Create a non-mintable drop stage object.
    const zeroMintDropStage = {
      ...dropStage,
      maxTotalMintableByWallet: 0,
      maxTokenSupplyForStage: 5,
    };

    const token2 = `0x${"2".repeat(40)}`;

    await expect(
      token.connect(owner).updateTokenGatedDrop(token2, zeroMintDropStage)
    ).to.be.revertedWithCustomError(token, "TokenGatedDropStageNotPresent");
  });

  it("Should clear from enumeration when deleted", async () => {
    await token.connect(owner).updateTokenGatedDrop(allowedNftToken.address, {
      ...dropStage,
      maxTotalMintableByWallet: 0,
    });
    expect(await token.getTokenGatedAllowedTokens()).to.deep.eq([]);
    expect(await token.getTokenGatedDrop(allowedNftToken.address)).to.deep.eq([
      BigNumber.from(0),
      0,
      0,
      0,
      0,
      0,
      AddressZero,
      0,
      false,
    ]);
  });
});
