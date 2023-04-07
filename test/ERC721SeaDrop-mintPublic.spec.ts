import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { MintType, VERSION, createMintOrder } from "./utils/helpers";

import type { AwaitedObject } from "./utils/helpers";
import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDrop,
} from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/ERC721SeaDrop";
import type { Wallet } from "ethers";

describe(`SeaDrop - Mint Public (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
  let owner: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let publicDrop: AwaitedObject<PublicDropStruct>;

  const _PUBLIC_DROP_STAGE_INDEX = 0;
  const _NATIVE_PAYMENT_TOKEN = ethers.constants.AddressZero;

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

    // Configure token
    await token.setMaxSupply(100);
    await token
      .connect(owner)
      .updateCreatorPayouts([
        { payoutAddress: creator.address, basisPoints: 10_000 },
      ]);
    publicDrop = {
      mintPrice: ethers.utils.parseEther("0.1"),
      paymentToken: ethers.constants.AddressZero,
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };
    await token.connect(owner).updatePublicDrop(publicDrop);
    await token
      .connect(owner)
      .updateAllowedFeeRecipient(feeRecipient.address, true);
  });

  it("Should mint a public stage", async () => {
    // Mint public with payer as minter.
    const quantity = 3;
    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // PayerNotAllowed
    expect(await token.getPayers()).to.deep.eq([]);

    // Allow the payer.
    await token.updatePayer(payer.address, true);
    expect(await token.getPayers()).to.deep.eq([payer.address]);

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        payer.address,
        quantity,
        publicDrop.mintPrice,
        _NATIVE_PAYMENT_TOKEN,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
      );

    let minterBalance = await token.balanceOf(minter.address);
    // expect(minterBalance).to.eq(quantity); TODO fix
    expect(await token.totalSupply()).to.eq(quantity);

    // Mint public with minter being payer.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        quantity,
        publicDrop.mintPrice,
        _NATIVE_PAYMENT_TOKEN,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
      );

    minterBalance = await token.balanceOf(minter.address);
    // expect(minterBalance).to.eq(quantity * 2); TODO fix
    expect(await token.totalSupply()).to.eq(quantity * 2);
  });

  it("Should not mint a public stage that hasn't started", async () => {
    // Set start time in the future.
    await token.updatePublicDrop({
      ...publicDrop,
      startTime: Math.round(Date.now() / 1000) + 100,
    });

    // Mint public with payer for minter.
    const quantity = 3;
    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive

    // Mint public with minter being payer.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive
  });

  it("Should not mint a public stage that has ended", async () => {
    // Set start time in the future.
    await token.updatePublicDrop({
      ...publicDrop,
      endTime: Math.round(Date.now() / 1000) - 100,
    });

    // Mint public with payer for minter.
    const quantity = 3;
    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive

    // Mint public with minter being payer.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // NotActive
  });

  it("Should respect limit for max mints per wallet and max supply", async () => {
    // Set max limit per wallet to 2.
    await token.updatePublicDrop({
      ...publicDrop,
      maxTotalMintableByWallet: 2,
    });

    // Update max supply to 1.
    await token.setMaxSupply(1);

    // Mint one.
    const quantity = 1;
    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        quantity,
        publicDrop.mintPrice,
        _NATIVE_PAYMENT_TOKEN,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
      );

    // Minting the next should throw MintQuantityExceedsMaxSupply.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
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
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        quantity,
        publicDrop.mintPrice,
        _NATIVE_PAYMENT_TOKEN,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
      );

    // Minting the next should throw MintQuantityExceedsMaxMintedPerWallet.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
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
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });
    value = value.div(2);

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InsufficientNativeTokensSupplied"
    );

    // Pay for 3 mints but request quantity of 2.
    quantity = 2;
    ({ order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    }));
    value = value.mul(2).div(3);

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InsufficientNativeTokensSupplied"
    );
  });

  it("Should not mint with invalid fee recipient", async () => {
    const quantity = 1;
    let { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient: { address: ethers.constants.AddressZero } as any,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // FeeRecipientCannotBeZeroAddress

    ({ order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient: creator,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // FeeRecipientNotAllowed
  });

  it("Should not be able to set an invalid fee bps", async () => {
    await expect(
      token.connect(owner).updatePublicDrop({ ...publicDrop, feeBps: 15_000 })
    ).to.be.revertedWithCustomError(token, "InvalidFeeBps");
  });

  it("Should mint when feeBps is zero", async () => {
    await token.connect(owner).updatePublicDrop({ ...publicDrop, feeBps: 0 });

    const quantity = 1;
    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: 0,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        quantity,
        publicDrop.mintPrice,
        _NATIVE_PAYMENT_TOKEN,
        0, // fee bps
        _PUBLIC_DROP_STAGE_INDEX
      );
  });

  it("Should not be able to mint zero quantity", async () => {
    const quantity = 0;
    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient: creator,
      feeBps: publicDrop.feeBps,
      mintPrice: publicDrop.mintPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          order,
          [],
          ethers.constants.HashZero,
          ethers.constants.AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityCannotBeZero
  });
});
