import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import {
  VERSION,
  deployDelegationRegistryToCanonicalAddress,
  deployERC1155SeaDrop,
  returnDataToOfferAndConsideration,
  txDataForPreviewOrder,
} from "./utils/helpers";
import { MintType, createMintOrder } from "./utils/order";

import type { AwaitedObject } from "./utils/helpers";
import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC1155SeaDrop,
  IERC1155SeaDrop,
  TestERC721,
} from "../typechain-types";
import type { TokenGatedDropStageStruct } from "../typechain-types/src/ERC1155SeaDrop";
import type { Wallet } from "ethers";

const { BigNumber } = ethers;
const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`ERC1155SeaDrop - Mint Allowed Token Holder (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC1155SeaDrop;
  let tokenSeaDropInterface: IERC1155SeaDrop;
  let allowedNftToken: TestERC721;
  let dropStage: AwaitedObject<TokenGatedDropStageStruct>;

  // Wallets
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
    for (const wallet of [owner, minter]) {
      await faucet(wallet.address, provider);
    }

    ({ conduitOne, marketplaceContract } = await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy token
    ({ token, tokenSeaDropInterface } = await deployERC1155SeaDrop(
      owner,
      marketplaceContract.address,
      conduitOne.address
    ));

    // Deploy the allowed NFT token.
    const TestERC721 = await ethers.getContractFactory("TestERC721");
    allowedNftToken = await TestERC721.deploy();

    // Configure token.
    await token.setMaxSupply(2, 100);
    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
    await tokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );

    // Create the drop stage object.
    dropStage = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      paymentToken: AddressZero,
      fromTokenId: 2,
      toTokenId: 2,
      maxMintablePerRedeemedToken: 2,
      maxTotalMintableByWallet: 11,
      maxTotalMintableByWalletPerToken: 10,
      maxTokenSupplyForStage: 100,
      dropStageIndex: 1,
      feeBps: 100,
      restrictFeeRecipients: true,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await tokenSeaDropInterface.updateTokenGatedDrop(
      allowedNftToken.address,
      dropStage
    );
  });

  it("Should mint a token to a user with the allowed NFT token", async () => {
    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [3, 1],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Ensure the token id has not been redeemed.
    expect(
      await tokenSeaDropInterface.getAllowedNftTokenIdRedeemedCount(
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.eq(0);

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // This should fail because of the amounts mismatch.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // TokenGatedTokenIdsAndAmountsLengthMismatch

    mintParams.amounts = [3];
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    }));

    // This should fail because the max mintable per redeemed token is 2.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // TokenGatedTokenIdMintExceedsQuantityRemaining
    // withArgs(allowedNftToken.address, mintParams.allowedNftTokenIds[0], 2, 2, 1)

    mintParams.amounts = [1];
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    }));

    // Mint the token to the minter and verify the expected event was emitted.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        dropStage.dropStageIndex
      );

    // Ensure the token id redeemed count is accurate.
    expect(
      await tokenSeaDropInterface.getAllowedNftTokenIdRedeemedCount(
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.eq(1);

    // Mint the token to the minter and verify the expected event was emitted.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        dropStage.dropStageIndex
      );

    // Ensure the token id redeemed count is accurate.
    expect(
      await tokenSeaDropInterface.getAllowedNftTokenIdRedeemedCount(
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.eq(2);

    // This should fail because the max mintable per redeemed token is 2.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // TokenGatedTokenIdMintExceedsQuantityRemaining
    // withArgs(allowedNftToken.address, mintParams.allowedNftTokenIds[0], 2, 2, 1)

    // Ensure the token id redeemed count is accurate.
    expect(
      await tokenSeaDropInterface.getAllowedNftTokenIdRedeemedCount(
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.eq(2);

    expect(await tokenSeaDropInterface.getTokenGatedAllowedTokens()).to.deep.eq(
      [allowedNftToken.address]
    );
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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    // The payer must be allowed first.
    await expect(
      marketplaceContract
        .connect(owner)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // PayerNotAllowed

    // Allow the payer.
    await tokenSeaDropInterface.updatePayer(owner.address, true);

    await expect(
      marketplaceContract
        .connect(owner)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        owner.address, // payer
        dropStage.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address, 2);
    expect(minterBalance).to.eq(1);
  });

  it("Should mint a token to a user with the allowed NFT token when the mint is free", async () => {
    // Create the free mint drop stage object.
    const dropStageFreeMint = { ...dropStage, startPrice: 0, endPrice: 0 };

    // Update the token gated drop for the deployed allowed NFT token.
    await tokenSeaDropInterface.updateTokenGatedDrop(
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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
        minter.address, // payer
        dropStage.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address, 2);
    expect(minterBalance).to.eq(1);
  });

  it("Should revert if the allowed NFT token has already been redeemed", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [2],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
        minter.address, // payer
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
    // withArgs(allowedNftToken.address, mintParams.allowedNftTokenIds[0], dropStage.maxMintablePerRedeemedToken, 2, 2)
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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
    // Create the expired drop stage.
    const dropStageExpired = {
      ...dropStage,
      endTime: Math.round(Date.now() / 1000) - 500,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await tokenSeaDropInterface.updateTokenGatedDrop(
      allowedNftToken.address,
      dropStageExpired
    );

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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient: minter,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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

    // Deploy a new ERC1155PartnerSeaDrop.
    const {
      token: differentToken,
      tokenSeaDropInterface: differentTokenSeaDropInterface,
    } = await deployERC1155SeaDrop(
      owner,
      marketplaceContract.address,
      conduitOne.address
    );

    // Update the fee recipient and creator payout address for the new token.
    await differentToken.setMaxSupply(2, 1000);
    await differentTokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );
    await differentTokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    const { order, value } = await createMintOrder({
      token: differentToken,
      tokenSeaDropInterface: differentTokenSeaDropInterface,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
    const TestERC721 = await ethers.getContractFactory("TestERC721", owner);
    const differentAllowedNftToken = await TestERC721.deploy();

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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
    await tokenSeaDropInterface.updateTokenGatedDrop(
      allowedNftToken.address,
      newDropStage
    );

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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
    await tokenSeaDropInterface.updateTokenGatedDrop(
      allowedNftToken.address,
      newDropStage
    );

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
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
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
      tokenSeaDropInterface.updateTokenGatedDrop(token.address, dropStage, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(
      token,
      "TokenGatedDropAllowedNftTokenCannotBeDropToken"
    );

    await expect(
      tokenSeaDropInterface.updateTokenGatedDrop(AddressZero, dropStage, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(
      token,
      "TokenGatedDropAllowedNftTokenCannotBeZeroAddress"
    );
  });

  it("Should not be able to set an invalid fee bps", async () => {
    await expect(
      tokenSeaDropInterface.updateTokenGatedDrop(
        allowedNftToken.address,
        {
          ...dropStage,
          feeBps: 15_000,
        },
        { gasLimit: 100_000 }
      )
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
      tokenSeaDropInterface.updateTokenGatedDrop(token2, zeroMintDropStage, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(token, "TokenGatedDropStageNotPresent");
  });

  it("Should clear from enumeration when deleted", async () => {
    await tokenSeaDropInterface.updateTokenGatedDrop(allowedNftToken.address, {
      ...dropStage,
      maxTotalMintableByWallet: 0,
    });
    expect(await tokenSeaDropInterface.getTokenGatedAllowedTokens()).to.deep.eq(
      []
    );
    expect(
      await tokenSeaDropInterface.getTokenGatedDrop(allowedNftToken.address)
    ).to.deep.eq([
      BigNumber.from(0),
      BigNumber.from(0),
      0,
      0,
      AddressZero,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      false,
    ]);
  });

  it("Should allow delegated payers to mint via the DelegationRegistry", async () => {
    const delegationRegistry =
      await deployDelegationRegistryToCanonicalAddress();

    const payer = new ethers.Wallet(randomHex(32), provider);
    await faucet(payer.address, provider);

    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 5_000 },
      { payoutAddress: owner.address, basisPoints: 5_000 },
    ]);

    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    await allowedNftToken.mint(minter.address, 0);

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // PayerNotAllowed
    // withArgs(payer.address)

    // Delegate payer for minter
    await delegationRegistry
      .connect(minter)
      .delegateForAll(payer.address, true);

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(payer.address, dropStage.dropStageIndex);
  });

  it("Should return the expected offer and consideration in previewOrder", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
      amounts: [1],
    };

    await allowedNftToken.mint(minter.address, 0);

    const { order } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenId: 2,
      feeRecipient,
      feeBps: dropStage.feeBps,
      price: dropStage.startPrice,
      minter,
      mintType: MintType.TOKEN_GATED,
      tokenGatedMintParams: mintParams,
    });

    const minimumReceived = order.parameters.offer.map((o) => ({
      itemType: o.itemType,
      token: o.token,
      identifier: o.identifierOrCriteria,
      amount: o.endAmount,
    }));
    const maximumSpent = order.parameters.consideration.map((c) => ({
      itemType: c.itemType,
      token: c.token,
      identifier: c.identifierOrCriteria,
      amount: c.endAmount,
      recipient: c.recipient,
    }));

    const data = txDataForPreviewOrder(
      minter,
      minimumReceived,
      maximumSpent,
      order
    );

    const returnData = await minter.call({ to: token.address, data });

    const { offer, consideration } =
      returnDataToOfferAndConsideration(returnData);

    expect({
      offer,
      consideration,
    }).to.deep.eq({
      offer: minimumReceived,
      consideration: maximumSpent,
    });
  });
});
