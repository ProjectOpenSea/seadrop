import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
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
type SignedMintValidationParamsStruct =
  SeaDropStructsErrorsAndEvents.SignedMintValidationParamsStruct;

const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`SeaDrop - Mint Signed (v${VERSION})`, function () {
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
  let mintParams: AwaitedObject<MintParamsStruct>;
  let signedMintValidationParams: AwaitedObject<SignedMintValidationParamsStruct>;
  let emptySignedMintValidationParams: AwaitedObject<SignedMintValidationParamsStruct>;
  let signer: Wallet;
  let eip712Domain: { [key: string]: string | number };
  let eip712Types: Record<string, Array<{ name: string; type: string }>>;
  let salt: string;

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

    emptySignedMintValidationParams = {
      minMintPrices: [],
      maxMaxTotalMintableByWallet: 0,
      minStartTime: 0,
      maxEndTime: 0,
      maxMaxTokenSupplyForStage: 0,
      minFeeBps: 0,
      maxFeeBps: 0,
    };

    signedMintValidationParams = {
      minMintPrices: [{ paymentToken: AddressZero, minMintPrice: 1 }],
      maxMaxTotalMintableByWallet: 11,
      minStartTime: 50,
      maxEndTime: 100000000000,
      maxMaxTokenSupplyForStage: 10000,
      minFeeBps: 1,
      maxFeeBps: 9000,
    };
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
        { name: "paymentToken", type: "address" },
        { name: "maxTotalMintableByWallet", type: "uint256" },
        { name: "startTime", type: "uint256" },
        { name: "endTime", type: "uint256" },
        { name: "dropStageIndex", type: "uint256" },
        { name: "maxTokenSupplyForStage", type: "uint256" },
        { name: "feeBps", type: "uint256" },
        { name: "restrictFeeRecipients", type: "bool" },
      ],
    };

    // Configure token
    await token.setMaxSupply(100);
    await token.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
    await token.updateAllowedFeeRecipient(feeRecipient.address, true);

    mintParams = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      paymentToken: AddressZero,
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };

    // Add signer.
    await token.updateSignedMintValidationParams(
      signer.address,
      signedMintValidationParams
    );

    // Set a random salt.
    salt = randomHex(32);
  });

  const signMint = async (
    nftContract: string,
    minter: Wallet,
    feeRecipient: Wallet,
    mintParams: MintParamsStruct,
    salt: string,
    signer: Wallet
  ) => {
    const signedMint = {
      nftContract,
      minter: minter.address,
      feeRecipient: feeRecipient.address,
      mintParams,
      salt,
    };
    const signature = await signer._signTypedData(
      eip712Domain,
      eip712Types,
      signedMint
    );
    // Verify recovered address matchers signer address
    const verifiedAddress = ethers.utils.verifyTypedData(
      eip712Domain,
      eip712Types,
      signedMint,
      signature
    );
    expect(verifiedAddress).to.eq(signer.address);
    return signature;
  };

  it("Should mint a signed mint", async () => {
    // Mint signed with payer for minter.
    let signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    let { order, value } = await createMintOrder({
      token,
      quantity: 3,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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

    // Allow the payer.
    await token.updatePayer(payer.address, true);

    await expect(
      marketplaceContract
        .connect(payer)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        payer.address,
        3, // mint quantity
        mintParams.startPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    let minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);

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

    // Mint signed with minter being payer.
    // Change the salt to use a new digest.
    const newSalt = randomHex();
    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      newSalt,
      signer
    );
    ({ order, value } = await createMintOrder({
      token,
      quantity: 3,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      mintParams,
      salt: newSalt,
      signature,
    }));

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
        3, // mint quantity
        mintParams.startPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(6);
    expect(await token.totalSupply()).to.eq(6);
  });

  it("Should not mint a signed mint with different params", async () => {
    const signature = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    let { order, value } = await createMintOrder({
      token,
      quantity: 3,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
    await token.updateAllowedFeeRecipient(payer.address, true);
    await token.updatePayer(payer.address, true);

    ({ order, value } = await createMintOrder({
      token,
      quantity: 3,
      feeRecipient: payer, // Test with different fee recipient
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    const token2 = await ERC721SeaDrop.deploy(
      "",
      "",
      marketplaceContract.address,
      conduitOne.address
    );
    await token2.setMaxSupply(100);
    await token.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
    await token2.updateAllowedFeeRecipient(feeRecipient.address, true);

    // Test coverage for error SignerNotPresent()
    await expect(
      token.updateSignedMintValidationParams(
        `0x${"8".repeat(40)}`,
        emptySignedMintValidationParams
      )
    ).to.be.revertedWithCustomError(token, "SignerNotPresent");

    await token2.updateSignedMintValidationParams(
      signer.address,
      signedMintValidationParams
    );
    await token2.updateSignedMintValidationParams(
      signer.address,
      signedMintValidationParams
    );

    ({ order, value } = await createMintOrder({
      token: token2, // Different token contract
      quantity: 3,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
    await token.updateSignedMintValidationParams(
      signer2.address,
      signedMintValidationParams
    );
    await token.updateSignedMintValidationParams(
      signer2.address,
      emptySignedMintValidationParams
    );
    expect(
      await token.getSignedMintValidationParams(signer2.address)
    ).to.deep.eq([[], 0, 0, 0, 0, 0, 0]);
    expect(await token.getSigners()).to.deep.eq([signer.address]);
    const signature2 = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      salt,
      signer2
    );
    ({ order, value } = await createMintOrder({
      token,
      quantity: 3,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
      quantity: 3,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
      quantity: 3,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
      token.updateSignedMintValidationParams(
        AddressZero,
        signedMintValidationParams
      )
    ).to.be.revertedWithCustomError(token, "SignerCannotBeZeroAddress");

    // Remove the original signer for branch coverage.
    await token.updateSignedMintValidationParams(
      signer.address,
      emptySignedMintValidationParams
    );
    expect(
      await token.getSignedMintValidationParams(signer.address)
    ).to.deep.eq([[], 0, 0, 0, 0, 0, 0]);

    // Add two signers and remove the second for branch coverage.
    await token.updateSignedMintValidationParams(
      signer.address,
      signedMintValidationParams
    );
    await token.updateSignedMintValidationParams(
      signer2.address,
      signedMintValidationParams
    );
    await token.updateSignedMintValidationParams(
      signer2.address,
      emptySignedMintValidationParams
    );
    expect(
      await token.getSignedMintValidationParams(signer2.address)
    ).to.deep.eq([[], 0, 0, 0, 0, 0, 0]);
  });

  it("Should not mint a signed mint after exceeding max mints per wallet.", async () => {
    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
      signer
    );

    let { order, value } = await createMintOrder({
      token,
      quantity: 10, // Max mints per wallet is 10. Mint 10
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
        minter.address,
        feeRecipient.address,
        minter.address,
        10, // mint quantity
        mintParams.endPrice,
        mintParams.paymentToken,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    // Try to mint one more.
    ({ order, value } = await createMintOrder({
      token,
      quantity: 1,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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
      quantity: 1,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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

    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParamsZeroFee,
      salt,
      signer
    );

    const { order, value } = await createMintOrder({
      token,
      quantity: 3,
      feeRecipient,
      feeBps: mintParamsZeroFee.feeBps,
      startPrice: mintParamsZeroFee.startPrice,
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
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        3, // mint quantity
        mintParamsZeroFee.endPrice,
        mintParams.paymentToken,
        mintParamsZeroFee.feeBps,
        mintParams.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);
  });

  it("Should not mint with invalid fee bps", async () => {
    const mintParamsInvalidFeeBps = { ...mintParams, feeBps: 11_000 };

    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParamsInvalidFeeBps,
      salt,
      signer
    );

    const { order, value } = await createMintOrder({
      token,
      quantity: 1,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
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

  it("Should not mint a signed mint that violates the validation params", async () => {
    let newMintParams: any = { ...mintParams, startPrice: 0, endPrice: 0 };

    let signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    const orderParams = {
      token,
      quantity: 1,
      feeRecipient,
      feeBps: mintParams.feeBps,
      startPrice: mintParams.startPrice,
      minter,
      mintType: MintType.SIGNED,
      salt,
      signature,
    };

    let { order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedMintPrice
    // withArgs(newMintParams.endPrice, signedMintValidationParams.minMintPrice)

    newMintParams = { ...mintParams, maxTotalMintableByWallet: 12 };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    ({ order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedMaxTotalMintableByWallet
    // withArgs(newMintParams.maxTotalMintableByWallet, signedMintValidationParams.maxMaxTotalMintableByWallet)

    newMintParams = { ...mintParams, startTime: 30 };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    ({ order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedStartTime
    // withArgs(newMintParams.startTime, ${signedMintValidationParams.minStartTime)`

    newMintParams = {
      ...mintParams,
      endTime: (signedMintValidationParams.maxEndTime as number) + 1,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    ({ order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedEndTime
    // withArgs(newMintParams.endTime, signedMintValidationParams.maxEndTime)

    newMintParams = {
      ...mintParams,
      maxTokenSupplyForStage: 10001,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    ({ order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedMaxTokenSupplyForStage
    // withArgs(newMintParams.maxTokenSupplyForStage, signedMintValidationParams.maxMaxTokenSupplyForStage)

    newMintParams = {
      ...mintParams,
      feeBps: 0,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    ({ order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedFeeBps
    // withArgs(newMintParams.feeBps, signedMintValidationParams.minFeeBps)

    newMintParams = {
      ...mintParams,
      feeBps: 9010,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    ({ order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSignedFeeBps
    // withArgs(newMintParams.feeBps, signedMintValidationParams.maxFeeBps)

    newMintParams = {
      ...mintParams,
      restrictFeeRecipients: false,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    ({ order, value } = await createMintOrder({
      ...orderParams,
      mintParams: newMintParams,
      signature,
    }));

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // SignedMintsMustRestrictFeeRecipients

    expect(await token.totalSupply()).to.eq(0);
  });

  it("Should not update SignedMintValidationParams with invalid fee bps", async () => {
    await expect(
      token.updateSignedMintValidationParams(signer.address, {
        ...signedMintValidationParams,
        minFeeBps: 11_000,
      })
    )
      .to.be.revertedWithCustomError(token, "InvalidFeeBps")
      .withArgs(11000);

    await expect(
      token.updateSignedMintValidationParams(signer.address, {
        ...signedMintValidationParams,
        maxFeeBps: 12_000,
      })
    )
      .to.be.revertedWithCustomError(token, "InvalidFeeBps")
      .withArgs(12000);
  });
});
