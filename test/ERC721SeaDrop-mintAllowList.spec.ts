import { expect } from "chai";
import { randomInt } from "crypto";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { createAllowListAndGetProof } from "./utils/allow-list";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { MintType, createMintOrder } from "./utils/order";

import type { AwaitedObject } from "./utils/helpers";
import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDrop,
} from "../typechain-types";
import type { SeaDropStructsErrorsAndEvents } from "../typechain-types/src/shim/Shim";
import type { Wallet } from "ethers";

type MintParamsStruct = SeaDropStructsErrorsAndEvents.MintParamsStruct;

const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`SeaDrop - Mint Allow List (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
  let creator: Wallet;
  let owner: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let feeBps: number;
  let mintParams: AwaitedObject<MintParamsStruct>;

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

    // Set a random feeBps.
    feeBps = randomInt(1, 10_000);

    // Update the fee recipient and creator payout address for the token.
    await token.setMaxSupply(1000);
    await token.updateAllowedFeeRecipient(feeRecipient.address, true);
    await token.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);

    // Set the allow list mint params.
    mintParams = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      paymentToken: AddressZero,
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 11,
      feeBps,
      restrictFeeRecipients: true,
    };
  });

  it("Should mint to a minter on the allow list", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    // Update the allow list of the token.
    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    // Mint the allow list stage to the minter and verify
    // the expected event was emitted.
    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
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
        minter.address, // payer
        quantity,
        mintParams.startPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should mint a free mint allow list stage", async () => {
    // Create a mintParams with price of 0.
    const mintParamsFreeMint = { ...mintParams, startPrice: 0, endPrice: 0 };

    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParamsFreeMint
    );

    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    expect(await token.getAllowListMerkleRoot()).to.eq(root);

    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParamsFreeMint.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams: mintParamsFreeMint,
      proof,
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
        minter.address, // payer
        quantity,
        0, // mint price: free
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should mint an allow list stage with a different payer than minter", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // The payer needs to be allowed first.
    await expect(
      marketplaceContract
        .connect(owner)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // PayerNotAllowed

    // Allow the payer.
    await token.updatePayer(owner.address, true);

    // Mint an allow list stage with a different payer than minter.
    await expect(
      marketplaceContract
        .connect(owner)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        owner.address, // payer
        quantity,
        mintParams.startPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should revert if the minter is not on the allow list", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    const nonMinter = new ethers.Wallet(randomHex(32), provider);
    await faucet(nonMinter.address, provider);

    await expect(
      marketplaceContract
        .connect(nonMinter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidProof

    ({ order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter: { address: AddressZero } as any,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    }));

    await expect(
      marketplaceContract
        .connect(nonMinter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidProof
  });

  it("Should not mint an allow list stage with an unknown fee recipient", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const invalidFeeRecipient = new ethers.Wallet(randomHex(32), provider);

    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient: invalidFeeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // FeeRecipientNotAllowed
  });

  it("Should not mint an allow list stage with a different token contract", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    // Deploy a new ERC721SeaDrop.
    const SeaDropToken = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    const differentToken = await SeaDropToken.deploy(
      "",
      "",
      marketplaceContract.address,
      conduitOne.address
    );

    // Update the fee recipient and creator payout address for the new token.
    await differentToken.setMaxSupply(1000);
    await differentToken.updateAllowedFeeRecipient(feeRecipient.address, true);
    await differentToken.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);

    const { order, value } = await createMintOrder({
      token: differentToken,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidProof
  });

  it("Should not mint an allow list stage with different mint params", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    // Create different mint params to include in the mint.
    const differentMintParams = {
      ...mintParams,
      feeBps: (mintParams.feeBps as number) + 100,
    };

    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams: differentMintParams,
      proof,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidProof
  });

  it("Should not mint an allow list stage after exceeding max mints per wallet", async () => {
    // Set a random quantity between 1 and maxTotalMintableByWallet - 1.
    const quantity = randomInt(
      1,
      (mintParams.maxTotalMintableByWallet as number) - 1
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    // Update the allow list of the token.
    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // Mint the allow list stage to the minter and verify
    // the expected event was emitted.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        quantity,
        mintParams.startPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    // Attempt to mint maxTotalMintableByWallet to the minter.
    ({ order, value } = await createMintOrder({
      token,
      quantity: mintParams.maxTotalMintableByWallet,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxMintedPerWallet
    // withArgs((mintParams.maxTotalMintableByWallet as number) + quantity, mintParams.maxTotalMintableByWallet)
  });

  it("Should not mint an allow list stage after exceeding max token supply for stage", async () => {
    // Create the second minter that will call the transaction exceeding
    // the drop stage supply.
    const secondMinter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to the second minter's wallet.
    await faucet(secondMinter.address, provider);

    const { root, proof } = await createAllowListAndGetProof(
      [minter, secondMinter],
      mintParams,
      0
    );
    const { proof: proofSecondMinter } = await createAllowListAndGetProof(
      [minter, secondMinter],
      mintParams,
      1
    );

    // Update the allow list of the token.
    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      quantity: mintParams.maxTotalMintableByWallet,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // Mint the maxTotalMintableByWallet to the minter and verify
    // the expected event was emitted.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        mintParams.maxTotalMintableByWallet,
        mintParams.startPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    ({ order, value } = await createMintOrder({
      token,
      quantity: mintParams.maxTotalMintableByWallet,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter: secondMinter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof: proofSecondMinter,
    }));

    // Attempt to mint the maxTotalMintableByWallet to the second minter, exceeding
    // the drop stage supply.
    await expect(
      marketplaceContract
        .connect(secondMinter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // QuantityExceedsMaxTokenSupplyForStage
    // withArgs(2 * (mintParams.maxTotalMintableByWallet as number), mintParams.maxTokenSupplyForStage)
  });

  it("Should not mint an allow list stage after exceeding max token supply", async () => {
    // Update the max supply.
    await token.setMaxSupply(10);

    // Create the second minter that will call the transaction exceeding
    // the drop stage supply.
    const secondMinter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to the second minter's wallet.
    await faucet(secondMinter.address, provider);

    const { root, proof } = await createAllowListAndGetProof(
      [minter, secondMinter],
      mintParams,
      0
    );
    const { proof: proofSecondMinter } = await createAllowListAndGetProof(
      [minter, secondMinter],
      mintParams,
      1
    );

    // Update the allow list of the token.
    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      quantity: 10,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // Mint the maxTotalMintableByWallet to the minter and verify
    // the expected event was emitted.
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
        mintParams.maxTotalMintableByWallet,
        mintParams.startPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    ({ order, value } = await createMintOrder({
      token,
      quantity: 1,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter: secondMinter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof: proofSecondMinter,
    }));

    // Attempt to mint the maxTotalMintableByWallet to the second minter, exceeding
    // the token max supply.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // QuantityExceedsMaxTokenSupply
    // withArgs(2 * (mintParams.maxTotalMintableByWallet as number), 11)
  });

  it("Should not mint with an uninitialized AllowList", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const { proof } = await createAllowListAndGetProof([minter], mintParams);

    // We are skipping updating the allow list, the root should be zero.
    expect(await token.getAllowListMerkleRoot()).to.eq(HashZero);

    let { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // Mint the allow list stage.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidProof

    // Try with proof of zero.
    ({ order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof: [HashZero],
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidProof
  });

  it("Should not mint with feeBps > 10_000", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWallet as number
    );

    const mintParamsInvalidFeeBps = { ...mintParams, feeBps: 10_100 };

    // Encode the minter address and mintParams.
    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParamsInvalidFeeBps
    );

    // Update the allow list of the token.
    await token.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const { order, value } = await createMintOrder({
      token,
      quantity,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // Mint the allow list stage.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidFeeBps
    // withArgs(10100)
  });
});
