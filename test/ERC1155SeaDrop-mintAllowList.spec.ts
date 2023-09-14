import { expect } from "chai";
import { randomInt } from "crypto";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { createAllowListAndGetProof } from "./utils/allow-list";
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
  ConsiderationInterface,
  ERC1155SeaDrop,
  IERC1155SeaDrop,
} from "../typechain-types";
import type { MintParamsStruct } from "../typechain-types/src/shim/Shim2";
import type { Wallet } from "ethers";

const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`ERC1155SeaDrop - Mint Allow List (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;

  // SeaDrop
  let token: ERC1155SeaDrop;
  let tokenSeaDropInterface: IERC1155SeaDrop;
  let feeBps: number;
  let mintParams: AwaitedObject<MintParamsStruct>;

  // Wallets
  let creator: Wallet;
  let owner: Wallet;
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

    ({ marketplaceContract } = await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy token
    ({ token, tokenSeaDropInterface } = await deployERC1155SeaDrop(
      owner,
      marketplaceContract.address
    ));

    // Set a random feeBps.
    feeBps = randomInt(1, 10_000);

    // Update the fee recipient and creator payout address for the token.
    await token.setMaxSupply(10, 1000);
    await tokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );
    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);

    // Set the allow list mint params.
    mintParams = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      startTime: Math.round(Date.now() / 1000) - 1000,
      endTime: Math.round(Date.now() / 1000) + 1000,
      paymentToken: AddressZero,
      fromTokenId: 10,
      toTokenId: 10,
      maxTotalMintableByWallet: 10,
      maxTotalMintableByWalletPerToken: 9,
      maxTokenSupplyForStage: 11,
      dropStageIndex: 1,
      feeBps,
      restrictFeeRecipients: true,
    };
  });

  it("Should mint to a minter on the allow list", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    // Update the allow list of the token.
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    // Mint the allow list stage to the minter and verify
    // the expected event was emitted.
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
        minter.address, // payer
        mintParams.dropStageIndex
      );
  });

  it("Should mint a free mint allow list stage", async () => {
    // Create a mintParams with price of 0.
    const mintParamsFreeMint = { ...mintParams, startPrice: 0, endPrice: 0 };

    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParamsFreeMint
    );

    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    expect(await tokenSeaDropInterface.getAllowListMerkleRoot()).to.eq(root);

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParamsFreeMint.startPrice,
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
        minter.address, // payer
        mintParams.dropStageIndex
      );
  });

  it("Should mint an allow list stage with a different payer than minter", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
    await tokenSeaDropInterface.updatePayer(owner.address, true);

    // Mint an allow list stage with a different payer than minter.
    await expect(
      marketplaceContract
        .connect(owner)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        owner.address, // payer
        mintParams.dropStageIndex
      );
  });

  it("Should revert if the minter is not on the allow list", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const invalidFeeRecipient = new ethers.Wallet(randomHex(32), provider);

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient: invalidFeeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    // Deploy a new ERC1155SeaDrop.
    const {
      token: differentToken,
      tokenSeaDropInterface: differentTokenSeaDropInterface,
    } = await deployERC1155SeaDrop(owner, marketplaceContract.address);

    // Update the fee recipient and creator payout address for the new token.
    await differentToken.setMaxSupply(10, 1000);
    await differentTokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );
    await differentTokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);

    const { order, value } = await createMintOrder({
      token: differentToken,
      tokenSeaDropInterface: differentTokenSeaDropInterface,
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await tokenSeaDropInterface.updateAllowList({
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
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
      (mintParams.maxTotalMintableByWalletPerToken as number) - 1
    );

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    // Update the allow list of the token.
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
        minter.address, // payer
        mintParams.dropStageIndex
      );

    // Attempt to mint maxTotalMintableByWallet to the minter.
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [mintParams.maxTotalMintableByWalletPerToken],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
    ); // MintQuantityExceedsMaxMintedPerWalletForTokenId
    // withArgs(10, (mintParams.maxTotalMintableByWalletPerToken as number) + quantity, mintParams.maxTotalMintableByWallet)
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
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [mintParams.maxTotalMintableByWalletPerToken],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // Mint the maxTotalMintableByWalletPerToken to the minter and verify
    // the expected event was emitted.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        mintParams.dropStageIndex
      );

    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [mintParams.maxTotalMintableByWalletPerToken],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter: secondMinter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof: proofSecondMinter,
    }));

    // Attempt to mint the maxTotalMintableByWalletPerToken to the second minter, exceeding
    // the drop stage supply.
    await expect(
      marketplaceContract
        .connect(secondMinter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // QuantityExceedsMaxTokenSupplyForStage
    // withArgs(2 * (mintParams.maxTotalMintableByWalletPerToken as number), mintParams.maxTokenSupplyForStage)
  });

  it("Should not mint an allow list stage after exceeding max token supply", async () => {
    // Update the max supply.
    await token.setMaxSupply(10, 10);

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
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [mintParams.maxTotalMintableByWalletPerToken],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    });

    // Mint the maxTotalMintableByWalletPerToken to the minter and verify
    // the expected event was emitted.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(minter.address, mintParams.dropStageIndex);

    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter: secondMinter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof: proofSecondMinter,
    }));

    // Attempt to mint the maxTotalMintableByWalletPerToken to the second minter, exceeding
    // the token max supply.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // QuantityExceedsMaxTokenSupply
    // withArgs(2 * (mintParams.maxTotalMintableByWalletPerToken as number), 11)
  });

  it("Should not mint with an uninitialized AllowList", async () => {
    // Set a random quantity under maxTotalMintableByWallet.
    const quantity = randomInt(
      1,
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const { proof } = await createAllowListAndGetProof([minter], mintParams);

    // We are skipping updating the allow list, the root should be zero.
    expect(await tokenSeaDropInterface.getAllowListMerkleRoot()).to.eq(
      HashZero
    );

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
      mintParams.maxTotalMintableByWalletPerToken as number
    );

    const mintParamsInvalidFeeBps = { ...mintParams, feeBps: 10_100 };

    // Encode the minter address and mintParams.
    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParamsInvalidFeeBps
    );

    // Update the allow list of the token.
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [quantity],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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

  it("Should allow delegated payers to mint via the DelegationRegistry", async () => {
    const delegationRegistry =
      await deployDelegationRegistryToCanonicalAddress();

    const payer = new ethers.Wallet(randomHex(32), provider);
    await faucet(payer.address, provider);

    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 5_000 },
      { payoutAddress: owner.address, basisPoints: 5_000 },
    ]);

    // Allow list mint
    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
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
      .withArgs(payer.address, mintParams.dropStageIndex);

    // Remove delegation
    await delegationRegistry
      .connect(minter)
      .delegateForAll(payer.address, false);
  });

  it("Should return the expected offer and consideration in previewOrder", async () => {
    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    const { order } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
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

  it("Should not allow feeBps over 10_000", async () => {
    const mintParamsFeeBpsOver10k = { ...mintParams, feeBps: 10_001 };

    const { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParamsFeeBpsOver10k
    );

    // Update the allow list of the token.
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    // Mint the allow list stage to the minter and verify
    // the expected event was emitted.
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [10],
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams: mintParamsFeeBpsOver10k,
      proof,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidFeeBps
    // withArgs(10_001)
  });

  it("Should be able to handle minting multiple tokenIds in the same order for the same stage", async () => {
    await token.setMaxSupply(0, 1);
    await token.setMaxSupply(1, 1);
    await token.setMaxSupply(2, 1);
    await token.setMaxSupply(3, 1);

    mintParams = {
      ...mintParams,
      fromTokenId: 0,
      toTokenId: 3,
      maxTotalMintableByWallet: 2,
    };

    let { root, proof } = await createAllowListAndGetProof(
      [minter],
      mintParams
    );

    // Update the allow list of the token.
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0, 1],
      quantities: [1, 1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
        minter.address, // payer
        mintParams.dropStageIndex
      );

    expect(await token.balanceOf(minter.address, 0)).to.eq(1);
    expect(await token.balanceOf(minter.address, 1)).to.eq(1);
    expect(
      await token.balanceOfBatch([minter.address, minter.address], [0, 1])
    ).to.deep.eq([1, 1]);

    // Should revert if duplicate tokenIds are provided.
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0, 1, 1],
      quantities: [1, 1, 1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
    ); // OfferContainsDuplicateTokenId

    // Ensure we cannot exceed maxTokenSupplyForStage with the total mint quantity.
    // We have already minted 2 tokens.
    expect(await token.balanceOf(minter.address, 2)).to.eq(0);
    expect(await token.balanceOf(minter.address, 3)).to.eq(0);
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [2, 3],
      quantities: [1, 1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
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
    ); // MintQuantityExceedsMaxTotalMintableByWallet, .withArgs(4, 2)

    // Update maxTotalMintableByWallet to 4, the order should now succeed.
    mintParams = {
      ...mintParams,
      maxTotalMintableByWallet: 4,
    };

    ({ root, proof } = await createAllowListAndGetProof([minter], mintParams));

    // Update the allow list of the token.
    await tokenSeaDropInterface.updateAllowList({
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    });

    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [2, 3],
      quantities: [1, 1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.ALLOW_LIST,
      mintParams,
      proof,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        mintParams.dropStageIndex
      );

    expect(await token.balanceOf(minter.address, 2)).to.eq(1);
    expect(await token.balanceOf(minter.address, 3)).to.eq(1);
  });
});
