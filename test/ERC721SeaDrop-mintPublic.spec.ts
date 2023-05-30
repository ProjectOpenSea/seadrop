import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import {
  VERSION,
  deployDelegationRegistryToCanonicalAddress,
  deployERC721SeaDrop,
  returnDataToOfferAndConsideration,
  txDataForPreviewOrder,
} from "./utils/helpers";
import { MintType, createMintOrder } from "./utils/order";

import type { AwaitedObject } from "./utils/helpers";
import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDrop,
  IERC721SeaDrop,
} from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/ERC721SeaDrop";
import type { Wallet } from "ethers";

const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`ERC721SeaDrop - Mint Public (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
  let tokenSeaDropInterface: IERC721SeaDrop;
  let publicDrop: AwaitedObject<PublicDropStruct>;

  // Wallets
  let owner: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;

  const _PUBLIC_DROP_STAGE_INDEX = 0;

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

    ({ conduitOne, marketplaceContract } = await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy token
    ({ token, tokenSeaDropInterface } = await deployERC721SeaDrop(
      owner,
      marketplaceContract.address,
      conduitOne.address
    ));

    // Configure token
    await token.setMaxSupply(100);
    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
    publicDrop = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      startTime: Math.round(Date.now() / 1000) - 1000,
      endTime: Math.round(Date.now() / 1000) + 1000,
      paymentToken: AddressZero,
      maxTotalMintableByWallet: 10,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };
    await tokenSeaDropInterface.updatePublicDrop(publicDrop);
    await tokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );
  });

  it("Should mint a public stage", async () => {
    // Mint public with payer as minter.
    const quantity = 3;
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // PayerNotAllowed
    let payers = await tokenSeaDropInterface.getPayers();
    expect(payers).to.deep.eq([]);

    // Allow the payer.
    await tokenSeaDropInterface.updatePayer(payer.address, true);
    payers = await tokenSeaDropInterface.getPayers();
    expect(payers).to.deep.eq([payer.address]);

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(payer.address, _PUBLIC_DROP_STAGE_INDEX);

    let minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(quantity);
    expect(await token.totalSupply()).to.eq(quantity);

    // Mint public with minter being payer.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        _PUBLIC_DROP_STAGE_INDEX
      );

    minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(quantity * 2);
    expect(await token.totalSupply()).to.eq(quantity * 2);
  });

  it("Should not mint a public stage that hasn't started", async () => {
    // Set start time in the future.
    await tokenSeaDropInterface.updatePublicDrop({
      ...publicDrop,
      startTime: Math.round(Date.now() / 1000) + 1000,
    });

    // Mint public with payer for minter.
    const quantity = 3;
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive

    // Mint public with minter being payer.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive
  });

  it("Should not mint a public stage that has ended", async () => {
    // Set end time in the past.
    await tokenSeaDropInterface.updatePublicDrop({
      ...publicDrop,
      endTime: Math.round(Date.now() / 1000) - 1000,
    });

    // Mint public with payer for minter.
    const quantity = 3;
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive

    // Mint public with minter being payer.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive
  });

  it("Should respect limit for max mints per wallet and max supply", async () => {
    // Set max limit per wallet to 2.
    await tokenSeaDropInterface.updatePublicDrop({
      ...publicDrop,
      maxTotalMintableByWallet: 2,
    });

    // Update max supply to 1.
    await token.setMaxSupply(1);

    // Mint one.
    const quantity = 1;
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        _PUBLIC_DROP_STAGE_INDEX
      );

    // Minting the next should throw MintQuantityExceedsMaxSupply.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxSupply

    // Update max supply to 3.
    await token.setMaxSupply(3);

    // Mint one.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        _PUBLIC_DROP_STAGE_INDEX
      );

    // Minting the next should throw MintQuantityExceedsMaxMintedPerWallet.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxMintedPerWallet
  });

  it("Should not mint with incorrect payment", async () => {
    // Pay for only 1 mint, but request quantity of 2.
    let quantity = 2;
    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    value = value.div(2);

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InsufficientNativeTokensSupplied"
    );

    // Pay for 3 mints but request quantity of 2.
    quantity = 2;
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    }));
    value = value.mul(2).div(3);

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InsufficientNativeTokensSupplied"
    );
  });

  it("Should not mint with invalid fee recipient", async () => {
    const quantity = 1;
    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient: { address: AddressZero } as any,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // FeeRecipientCannotBeZeroAddress

    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient: creator,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // FeeRecipientNotAllowed
  });

  it("Should not be able to set an invalid fee bps", async () => {
    await expect(
      tokenSeaDropInterface.updatePublicDrop(
        {
          ...publicDrop,
          feeBps: 15_000,
        },
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(token, "InvalidFeeBps");
  });

  it("Should mint when feeBps is zero", async () => {
    await tokenSeaDropInterface.updatePublicDrop({
      ...publicDrop,
      feeBps: 0,
    });

    const quantity = 1;
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient,
      feeBps: 0,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        _PUBLIC_DROP_STAGE_INDEX
      );
  });

  it("Should not be able to mint zero quantity", async () => {
    const quantity = 0;
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity,
      feeRecipient: creator,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityCannotBeZero
  });

  it("Should allow delegated payers to mint via the DelegationRegistry", async () => {
    const delegationRegistry =
      await deployDelegationRegistryToCanonicalAddress();

    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 5_000 },
      { payoutAddress: owner.address, basisPoints: 5_000 },
    ]);

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity: 1,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
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
      .withArgs(
        payer.address, // payer
        _PUBLIC_DROP_STAGE_INDEX
      );
  });

  it("Should not allow a mint quantity of zero", async () => {
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity: 0,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    );
  });

  it("Should return the expected offer and consideration in previewOrder", async () => {
    const { order } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantity: 1,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.endPrice,
      minter,
      mintType: MintType.PUBLIC,
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
