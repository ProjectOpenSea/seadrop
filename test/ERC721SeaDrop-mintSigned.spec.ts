import { expect } from "chai";
import hre, { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { getCustomRevertSelector } from "./seaport-utils/helpers";
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
import type { MintParamsStruct } from "../typechain-types/src/shim/Shim";
import type { Wallet } from "ethers";

const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`ERC721SeaDrop - Mint Signed (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
  let tokenSeaDropInterface: IERC721SeaDrop;
  let mintParams: AwaitedObject<MintParamsStruct>;
  let eip712Domain: { [key: string]: string | number };
  let eip712Types: Record<string, Array<{ name: string; type: string }>>;
  let salt: string;

  // Wallets
  let owner: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let signer: Wallet;

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
    signer = new ethers.Wallet(randomHex(32), provider);

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

    // Set EIP-712 params
    eip712Domain = {
      name: "ERC721SeaDrop",
      version: "2.0",
      chainId: (await provider.getNetwork()).chainId,
      verifyingContract: token.address,
    };
    eip712Types = {
      SignedMint: [
        { name: "minter", type: "address" },
        { name: "feeRecipient", type: "address" },
        { name: "mintParams", type: "MintParams" },
        { name: "salt", type: "uint256" },
      ],
      MintParams: [
        { name: "startPrice", type: "uint256" },
        { name: "endPrice", type: "uint256" },
        { name: "startTime", type: "uint256" },
        { name: "endTime", type: "uint256" },
        { name: "paymentToken", type: "address" },
        { name: "maxTotalMintableByWallet", type: "uint256" },
        { name: "maxTokenSupplyForStage", type: "uint256" },
        { name: "dropStageIndex", type: "uint256" },
        { name: "feeBps", type: "uint256" },
        { name: "restrictFeeRecipients", type: "bool" },
      ],
    };

    // Configure token
    await token.setMaxSupply(100);
    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
    await tokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );

    mintParams = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      startTime: Math.round(Date.now() / 1000) - 1000,
      endTime: Math.round(Date.now() / 1000) + 1000,
      paymentToken: AddressZero,
      maxTotalMintableByWallet: 10,
      maxTokenSupplyForStage: 100,
      dropStageIndex: 1,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };

    // Add signer.
    await tokenSeaDropInterface.updateSigner(signer.address, true);

    // Set a random salt.
    salt = randomHex(32);
  });

  const signMint = async (
    nftContract: string,
    minter: Wallet,
    feeRecipient: Wallet,
    mintParams: MintParamsStruct,
    salt: string,
    signer: Wallet,
    compact = true
  ) => {
    const signedMint = {
      nftContract,
      minter: minter.address,
      feeRecipient: feeRecipient.address,
      mintParams,
      salt,
    };
    const digest = ethers.utils._TypedDataEncoder.hash(
      eip712Domain,
      eip712Types,
      signedMint
    );
    let signature = await signer._signTypedData(
      eip712Domain,
      eip712Types,
      signedMint
    );
    if (compact) {
      signature = ethers.utils.splitSignature(signature).compact;
    }
    // Verify recovered address matchers signer address
    const verifiedAddress = ethers.utils.verifyTypedData(
      eip712Domain,
      eip712Types,
      signedMint,
      signature
    );
    expect(verifiedAddress).to.eq(signer.address);
    return { signature, digest };
  };

  it("Should mint a signed mint", async () => {
    // Mint signed with payer for minter.
    let { signature, digest } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
    });

    expect(await tokenSeaDropInterface.getDigestIsUsed(digest)).to.eq(false);

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // PayerNotAllowed
    // withArgs(payer.address)

    expect(await tokenSeaDropInterface.getDigestIsUsed(digest)).to.eq(false);

    // Allow the payer.
    await tokenSeaDropInterface.updatePayer(payer.address, true);

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(payer.address, mintParams.dropStageIndex);

    let minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);
    expect(await tokenSeaDropInterface.getDigestIsUsed(digest)).to.eq(true);

    // Ensure a signature can only be used once.
    // Mint again with the same params.
    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // SignatureAlreadyUsed

    expect(await tokenSeaDropInterface.getDigestIsUsed(digest)).to.eq(true);

    // Mint signed with minter being payer.
    // Change the salt to use a new digest.
    const newSalt = randomHex();
    ({ signature, digest } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      newSalt,
      signer
    ));
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt: newSalt,
      signature,
    }));

    expect(await tokenSeaDropInterface.getDigestIsUsed(digest)).to.eq(false);

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

    minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(6);
    expect(await token.totalSupply()).to.eq(6);
    expect(await tokenSeaDropInterface.getDigestIsUsed(digest)).to.eq(true);
  });

  it("Should not mint a signed mint with different params", async () => {
    const { signature } = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter: payer, // Test with different minter address
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignature

    // Test with different fee recipient
    await tokenSeaDropInterface.updateAllowedFeeRecipient(payer.address, true);
    await tokenSeaDropInterface.updatePayer(payer.address, true);

    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient: payer, // Test with different fee recipient
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignature

    // Test with different token contract
    const { token: token2, tokenSeaDropInterface: tokenSeaDropInterface2 } =
      await deployERC721SeaDrop(
        owner,
        marketplaceContract.address,
        conduitOne.address
      );
    await token2.setMaxSupply(100);
    await tokenSeaDropInterface2.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
    await tokenSeaDropInterface2.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );

    // Test coverage for error SignerNotPresent()
    await expect(
      tokenSeaDropInterface2.updateSigner(`0x${"8".repeat(40)}`, false, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(token, "SignerNotPresent");

    await tokenSeaDropInterface2.updateSigner(signer.address, true);
    await tokenSeaDropInterface2.updateSigner(signer.address, false);
    await tokenSeaDropInterface2.updateSigner(signer.address, true);

    ({ order, value } = await createMintOrder({
      token: token2, // Different token contract
      tokenSeaDropInterface: tokenSeaDropInterface2,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
    }));
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignature

    // Test with signer that is not allowed
    const signer2 = new ethers.Wallet(randomHex(32), provider);
    await tokenSeaDropInterface.updateSigner(signer2.address, true);
    await tokenSeaDropInterface.updateSigner(signer2.address, false);
    expect(await tokenSeaDropInterface2.getSigners()).to.deep.eq([
      signer.address,
    ]);
    const { signature: signature2 } = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      salt,
      signer2
    );
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature: signature2,
    }));
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignature

    // Test with different mint params
    const differentMintParams = {
      ...mintParams,
      maxTokenSupplyForStage: 10000,
    };
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams: differentMintParams,
      salt,
      signature,
    }));
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignature

    // Test with different salt
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams: differentMintParams,
      salt: randomHex(),
      signature,
    }));
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignature

    // Ensure that the zero address cannot be added as a signer.
    await expect(
      tokenSeaDropInterface.updateSigner(AddressZero, true, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(token, "SignerCannotBeZeroAddress");

    // Remove the original signer for branch coverage.
    await tokenSeaDropInterface.updateSigner(signer.address, false);
    expect(await tokenSeaDropInterface.getSigners()).to.deep.eq([]);

    // Add two signers and remove the second for branch coverage.
    await tokenSeaDropInterface.updateSigner(signer.address, true);
    expect(await tokenSeaDropInterface.getSigners()).to.deep.eq([
      signer.address,
    ]);
    await tokenSeaDropInterface.updateSigner(signer2.address, true);
    expect(await tokenSeaDropInterface.getSigners()).to.deep.eq([
      signer.address,
      signer2.address,
    ]);
    await tokenSeaDropInterface.updateSigner(signer2.address, false);
    expect(await tokenSeaDropInterface.getSigners()).to.deep.eq([
      signer.address,
    ]);
  });

  it("Should not mint a signed mint after exceeding max mints per wallet", async () => {
    const { signature } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [10], // Max mints per wallet is 10. Mint 10
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
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

    // Try to mint one more.
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
    }));
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxMintedPerWallet

    // Try to mint one more with manipulated mintParams.
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,

      mintParams: { ...mintParams, maxTotalMintableByWallet: 11 },
      salt,
      signature,
    }));
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignature
  });

  it("Should mint a signed mint with fee amount that rounds down to zero", async () => {
    const mintParamsZeroFee = {
      ...mintParams,
      startPrice: 1,
      endPrice: 1,
      feeBps: 1,
    };

    const { signature } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParamsZeroFee,
      salt,
      signer
    );

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParamsZeroFee.feeBps,
      price: mintParamsZeroFee.startPrice,
      minter,
      mintType: MintType.SIGNED,

      mintParams: mintParamsZeroFee,
      salt,
      signature,
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

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);
  });

  it("Should not mint with invalid fee bps", async () => {
    const mintParamsInvalidFeeBps = { ...mintParams, feeBps: 11_000 };

    const { signature } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParamsInvalidFeeBps,
      salt,
      signer
    );

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,

      mintParams: mintParamsInvalidFeeBps,
      salt,
      signature,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedFeeBps
  });

  it("Should allow delegated payers to mint via the DelegationRegistry", async () => {
    const delegationRegistry =
      await deployDelegationRegistryToCanonicalAddress();

    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 5_000 },
      { payoutAddress: owner.address, basisPoints: 5_000 },
    ]);

    const { signature } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
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
    const { signature } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    const { order } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [1],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
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

  it("Should allow delegated payers to mint via the DelegationRegistry", async () => {
    const delegationRegistry =
      await deployDelegationRegistryToCanonicalAddress();

    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 5_000 },
      { payoutAddress: owner.address, basisPoints: 5_000 },
    ]);

    const { signature } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
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

  // NOTE: Run this test last in this file as it hacks changing the hre
  it("Reverts on changed chainId", async () => {
    const { signature } = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      quantities: [3],
      feeRecipient,
      feeBps: mintParams.feeBps,
      price: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt,
      signature,
    });

    // Change chainId in-flight to test branch coverage for _deriveDomainSeparator()
    // (hacky way, until https://github.com/NomicFoundation/hardhat/issues/3074 is added)
    const changeChainId = () => {
      const recurse = (obj: any) => {
        for (const [key, value] of Object.entries(obj ?? {})) {
          if (key === "transactions") continue;
          if (key === "chainId") {
            obj[key] = typeof value === "bigint" ? BigInt(1) : 1;
          } else if (typeof value === "object") {
            recurse(obj[key]);
          }
        }
      };
      const hreProvider = hre.network.provider as any;
      recurse(
        hreProvider._wrapped._wrapped._wrapped?._node?._vm ??
          // When running coverage, there was an additional layer of wrapping
          hreProvider._wrapped._wrapped._wrapped._wrapped._node._vm
      );
    };
    changeChainId();

    const expectedRevertReason = getCustomRevertSelector(
      "InvalidContractOrder(bytes32)"
    ); // InvalidSignature(address)

    const tx = await marketplaceContract
      .connect(minter)
      .populateTransaction.fulfillAdvancedOrder(
        order,
        [],
        HashZero,
        AddressZero,
        { value }
      );
    tx.chainId = 1;
    const returnData = await provider.call(tx);
    expect(returnData.slice(0, 10)).to.equal(expectedRevertReason);
  });
});
