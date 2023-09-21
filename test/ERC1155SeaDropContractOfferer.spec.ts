import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

import {
  ContractOffererInterface__factory,
  IERC1155ContractMetadata__factory,
  IERC1155SeaDrop__factory,
  IERC165__factory,
  IERC2981__factory,
  ISeaDropTokenContractMetadata__factory,
  ISeaDropToken__factory,
} from "../typechain-types";

import { getItemETH, toBN } from "./seaport-utils/encoding";
import { seaportFixture } from "./seaport-utils/fixtures";
import { getInterfaceID, randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION, deployERC1155SeaDrop, setConduit } from "./utils/helpers";
import { MintType, createMintOrder, expectedPrice } from "./utils/order";

import type { SeaportFixtures } from "./seaport-utils/fixtures";
import type { AwaitedObject } from "./utils/helpers";
import type {
  ConsiderationInterface,
  ERC1155SeaDrop,
  ERC1155SeaDropConfigurer,
  IERC1155SeaDrop,
} from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/ERC1155SeaDrop";
import type { AllowListDataStruct } from "../typechain-types/src/shim/Shim";
import type { Wallet } from "ethers";

const { BigNumber } = ethers;
const { AddressZero, HashZero } = ethers.constants;
const { defaultAbiCoder, parseEther } = ethers.utils;

describe(`ERC1155SeaDropContractOfferer (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let createOrder: SeaportFixtures["createOrder"];
  let conduitOne: SeaportFixtures["conduitOne"];
  let conduitKeyOne: SeaportFixtures["conduitKeyOne"];

  // SeaDrop
  let token: ERC1155SeaDrop;
  let tokenSeaDropInterface: IERC1155SeaDrop;
  let configurer: ERC1155SeaDropConfigurer;
  let publicDrop: AwaitedObject<PublicDropStruct>;
  let allowListData: AwaitedObject<AllowListDataStruct>;

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
    // Set the wallets
    owner = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, minter, creator, feeRecipient]) {
      await faucet(wallet.address, provider);
    }

    ({ createOrder, marketplaceContract, conduitOne, conduitKeyOne } =
      await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy token
    ({ token, tokenSeaDropInterface, configurer } = await deployERC1155SeaDrop(
      owner,
      marketplaceContract.address
    ));

    publicDrop = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      startTime: Math.round(Date.now() / 1000) - 1000,
      endTime: Math.round(Date.now() / 1000) + 1000,
      fromTokenId: 0,
      toTokenId: 10,
      paymentToken: AddressZero,
      maxTotalMintableByWallet: 10,
      maxTotalMintableByWalletPerToken: 9,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };

    allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };

    await token.setMaxSupply(0, 5);
    await tokenSeaDropInterface.updatePublicDrop(publicDrop, 0);
    await tokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );
    await tokenSeaDropInterface.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
  });

  it("Should emit an event when the contract is deployed", async () => {
    const ERC1155SeaDrop = await ethers.getContractFactory(
      "ERC1155SeaDrop",
      owner
    );
    const tx = await ERC1155SeaDrop.deploy(
      AddressZero,
      marketplaceContract.address,
      "",
      ""
    );
    const receipt = await tx.deployTransaction.wait();
    const event = (receipt as any).events.filter(
      ({ event }: any) => event === "SeaDropTokenDeployed"
    );
    expect(event).to.not.be.null;

    await expect(
      ERC1155SeaDrop.deploy(AddressZero, AddressZero, "", "", {
        gasLimit: 10_000_000,
      })
    ).to.be.revertedWithCustomError(token, "AllowedSeaportCannotBeZeroAddress");
  });

  it("Should return the configurer contact", async () => {
    expect(await tokenSeaDropInterface.configurer()).to.eq(configurer.address);
  });

  it("Should not be able to call into the implementation contract without delegatecall", async () => {
    // Fallback
    await expect(
      owner.sendTransaction({
        to: configurer.address,
        data: "0x123456",
        gasLimit: 50_000,
      })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updateDropURI
    await expect(
      configurer.updateDropURI("", { gasLimit: 50_000 })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updatePublicDrop
    await expect(
      configurer.updatePublicDrop(publicDrop, 0, { gasLimit: 50_000 })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updateAllowList
    await expect(
      configurer.updateAllowList(
        {
          merkleRoot: `0x${"1".repeat(64)}`,
          publicKeyURIs: [],
          allowListURI: "",
        },
        { gasLimit: 50_000 }
      )
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // generateOrder
    await expect(
      configurer.generateOrder(AddressZero, [], [], [], { gasLimit: 50_000 })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // previewOrder
    await expect(
      configurer.previewOrder(AddressZero, AddressZero, [], [], [], {
        gasLimit: 50_000,
      })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updateAllowedSeaport
    await expect(
      configurer.updateAllowedSeaport([], {
        gasLimit: 50_000,
      })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updateCreatorPayouts
    await expect(
      configurer.updateCreatorPayouts([], {
        gasLimit: 50_000,
      })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updateAllowedFeeRecipient
    await expect(
      configurer.updateAllowedFeeRecipient(AddressZero, true, {
        gasLimit: 50_000,
      })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updateSigner
    await expect(
      configurer.updateSigner(AddressZero, true, {
        gasLimit: 50_000,
      })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");

    // updatePayer
    await expect(
      configurer.updatePayer(AddressZero, true, {
        gasLimit: 50_000,
      })
    ).to.be.revertedWithCustomError(configurer, "OnlyDelegateCalled");
  });

  it("Should not be able to mint until the creator payout is set", async () => {
    const { token: token2, tokenSeaDropInterface: tokenSeaDropInterface2 } =
      await deployERC1155SeaDrop(owner, marketplaceContract.address);

    await token2.setMaxSupply(0, 5);
    await tokenSeaDropInterface2.updatePublicDrop(publicDrop, 0);
    await tokenSeaDropInterface2.updateAllowedFeeRecipient(
      feeRecipient.address,
      true
    );

    expect(await tokenSeaDropInterface2.getCreatorPayouts()).to.deep.equal([]);
    await expect(
      tokenSeaDropInterface2.updateCreatorPayouts([], { gasLimit: 100_000 })
    ).to.be.revertedWithCustomError(token2, "CreatorPayoutsNotSet");

    let { order, value } = await createMintOrder({
      token: token2,
      tokenSeaDropInterface: tokenSeaDropInterface2,
      tokenIds: [0],
      quantities: [1],
      publicDropIndex: 0,
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
    ); // CreatorPayoutsNotSet

    await tokenSeaDropInterface2.updateCreatorPayouts([
      { payoutAddress: creator.address, basisPoints: 1_000 },
      { payoutAddress: owner.address, basisPoints: 9_000 },
    ]);

    ({ order, value } = await createMintOrder({
      token: token2,
      tokenSeaDropInterface: tokenSeaDropInterface2,
      tokenIds: [0],
      quantities: [1],
      publicDropIndex: 0,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    }));

    // Should not be able to mint when minimumReceived.length is zero
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          { ...order, parameters: { ...order.parameters, offer: [] } },
          [],
          HashZero,
          AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MustSpecifyERC1155ConsiderationItemForSeaDropMint

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token2, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        0
      );
  });

  it("Should only let the token owner update the drop URI", async () => {
    await expect(
      tokenSeaDropInterface
        .connect(creator)
        .updateDropURI("http://test.com", { gasLimit: 100_000 })
    ).to.revertedWithCustomError(token, "Unauthorized");

    await expect(tokenSeaDropInterface.updateDropURI("http://test.com"))
      .to.emit(token, "DropURIUpdated")
      .withArgs("http://test.com");
  });

  it("Should only let the owner update the allowed fee recipients", async () => {
    await tokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      false
    );
    let allowedFeeRecipients =
      await tokenSeaDropInterface.getAllowedFeeRecipients();
    expect(allowedFeeRecipients).to.deep.eq([]);

    await expect(
      tokenSeaDropInterface.updateAllowedFeeRecipient(AddressZero, true, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(token, "FeeRecipientCannotBeZeroAddress");

    await expect(
      tokenSeaDropInterface.updateAllowedFeeRecipient(
        feeRecipient.address,
        true
      )
    )
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, true);

    await expect(
      tokenSeaDropInterface.updateAllowedFeeRecipient(
        feeRecipient.address,
        true,
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(token, "DuplicateFeeRecipient");

    allowedFeeRecipients =
      await tokenSeaDropInterface.getAllowedFeeRecipients();
    expect(allowedFeeRecipients).to.deep.eq([feeRecipient.address]);

    // Now let's disallow the feeRecipient
    await expect(
      tokenSeaDropInterface.updateAllowedFeeRecipient(
        feeRecipient.address,
        false
      )
    )
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, false);

    allowedFeeRecipients =
      await tokenSeaDropInterface.getAllowedFeeRecipients();
    expect(allowedFeeRecipients).to.deep.eq([]);

    await expect(
      tokenSeaDropInterface.updateAllowedFeeRecipient(
        feeRecipient.address,
        false,
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(token, "FeeRecipientNotPresent");
  });

  it("Should handle desc and asc mint prices", async () => {
    const publicDropDescMintPrice = {
      ...publicDrop,
      startPrice: parseEther("1"),
      endPrice: parseEther(".1"),
    };
    await tokenSeaDropInterface.updatePublicDrop(publicDropDescMintPrice, 0);

    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0],
      quantities: [1],
      publicDropIndex: 0,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDropDescMintPrice.startPrice,
      // Specifying null address for minter means the fulfiller should be assigned as the minter.
      minter: { address: AddressZero } as any,
      mintType: MintType.PUBLIC,
    });

    // Fix the next block timestamp so we can calculate the expected price.
    let nextTimestamp = (await time.latest()) + 20;
    await time.setNextBlockTimestamp(nextTimestamp);
    let expected = expectedPrice({
      startPrice: publicDropDescMintPrice.startPrice,
      endPrice: publicDropDescMintPrice.endPrice,
      startTime: publicDrop.startTime,
      endTime: publicDrop.endTime,
      blockTimestamp: nextTimestamp,
    });

    let balanceBefore = await provider.getBalance(minter.address);

    let tx;
    await expect(
      (tx = marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value }))
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        0
      );

    let receipt = await (await tx).wait();
    let txCost = receipt.gasUsed.mul(receipt.effectiveGasPrice);
    // Should refund the difference between the expected price and the provided amount.
    let balanceAfter = await provider.getBalance(minter.address);
    expect(balanceAfter).to.eq(balanceBefore.sub(expected).sub(txCost));

    // Test asc mint price
    const publicDropAscMintPrice = {
      ...publicDrop,
      startPrice: parseEther(".1"),
      endPrice: parseEther("1"),
    };
    await tokenSeaDropInterface.updatePublicDrop(publicDropAscMintPrice, 0);
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0],
      quantities: [1],
      publicDropIndex: 0,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDropAscMintPrice.endPrice,
      minter,
      mintType: MintType.PUBLIC,
    }));

    balanceBefore = await provider.getBalance(minter.address);
    nextTimestamp += 250;
    await time.setNextBlockTimestamp(nextTimestamp);
    expected = expectedPrice({
      startPrice: publicDropAscMintPrice.startPrice,
      endPrice: publicDropAscMintPrice.endPrice,
      startTime: publicDrop.startTime,
      endTime: publicDrop.endTime,
      blockTimestamp: nextTimestamp,
    });

    await expect(
      (tx = marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value }))
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        0
      );

    receipt = await (await tx).wait();
    txCost = receipt.gasUsed.mul(receipt.effectiveGasPrice);
    // Should refund the difference between the expected price and the provided amount.
    balanceAfter = await provider.getBalance(minter.address);
    expect(balanceAfter).to.eq(balanceBefore.sub(expected).sub(txCost));

    // Should allow newly minted tokens to be transferred in Seaport secondary sales.
    expect(await token.balanceOf(minter.address, 0)).to.eq(2);
    const offerItem = {
      itemType: 3, // ERC1155
      token: token.address,
      identifierOrCriteria: toBN(0),
      startAmount: toBN(2),
      endAmount: toBN(2),
    };
    const offer = [offerItem];
    const consideration = [
      getItemETH(parseEther("10"), parseEther(".1"), minter.address),
      getItemETH(parseEther("1"), parseEther(".01"), owner.address),
    ];
    ({ order, value } = await createOrder(
      minter,
      AddressZero,
      offer,
      consideration,
      0 // FULL_OPEN
    ));
    await token
      .connect(minter)
      .setApprovalForAll(marketplaceContract.address, true);
    await marketplaceContract
      .connect(owner)
      .fulfillOrder(order, HashZero, { value });
    expect(await token.balanceOf(owner.address, 0)).to.eq(2);
    expect(await token.balanceOf(minter.address, 0)).to.eq(0);
  });

  it("Should return supportsInterface true for supported interfaces", async () => {
    const supportedInterfacesERC1155SeaDrop = [
      [IERC1155SeaDrop__factory, ISeaDropToken__factory],
    ];
    const supportedInterfacesERC1155ContractMetadata = [
      [
        IERC1155ContractMetadata__factory,
        ISeaDropTokenContractMetadata__factory,
      ],
      [IERC2981__factory, IERC165__factory],
    ];
    const supportedInterfacesContractOffererInterface = [
      [ContractOffererInterface__factory],
    ];

    for (const factories of [
      ...supportedInterfacesERC1155SeaDrop,
      ...supportedInterfacesERC1155ContractMetadata,
      ...supportedInterfacesContractOffererInterface,
    ]) {
      const interfaceId = factories
        .map((factory) => getInterfaceID(factory.createInterface()))
        .reduce((prev, curr) => prev.xor(curr))
        .toHexString();
      expect(await token.supportsInterface(interfaceId)).to.be.true;
    }

    // Ensure the supported interfaces from ERC1155 return true.
    // 0xd9b67a26: ERC1155
    expect(await token.supportsInterface("0xd9b67a26")).to.be.true;
    // 0x0e89341c: ERC1155MetadataURI
    expect(await token.supportsInterface("0x0e89341c")).to.be.true;
    // 0x01ffc9a7: ERC165
    expect(await token.supportsInterface("0x01ffc9a7")).to.be.true;

    // Ensure the interface for ERC-4906 returns true.
    expect(await token.supportsInterface("0x49064906")).to.be.true;

    // Ensure the interface for SIP-5 (getSeaportMetadata) returns true.
    expect(await token.supportsInterface("0x2e778efc")).to.be.true;

    // Ensure invalid interfaces return false.
    const invalidInterfaceIds = ["0x00000000", "0x10000000", "0x00000001"];
    for (const interfaceId of invalidInterfaceIds) {
      expect(await token.supportsInterface(interfaceId)).to.be.false;
    }
  });

  it("Should only let the token owner update the allowed Seaport addresses", async () => {
    await expect(
      tokenSeaDropInterface
        .connect(creator)
        .updateAllowedSeaport([marketplaceContract.address], {
          gasLimit: 100_000,
        })
    ).to.revertedWithCustomError(token, "Unauthorized");

    await expect(
      tokenSeaDropInterface
        .connect(minter)
        .updateAllowedSeaport([marketplaceContract.address], {
          gasLimit: 100_000,
        })
    ).to.revertedWithCustomError(token, "Unauthorized");

    await expect(
      tokenSeaDropInterface.connect(owner).updateAllowedSeaport([AddressZero], {
        gasLimit: 100_000,
      })
    ).to.revertedWithCustomError(token, "AllowedSeaportCannotBeZeroAddress");

    await expect(
      tokenSeaDropInterface.updateAllowedSeaport([marketplaceContract.address])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address]);

    expect(await tokenSeaDropInterface.getAllowedSeaport()).to.deep.eq([
      marketplaceContract.address,
    ]);

    const address1 = `0x${"1".repeat(40)}`;
    const address2 = `0x${"2".repeat(40)}`;
    const address3 = `0x${"3".repeat(40)}`;

    await expect(
      tokenSeaDropInterface.updateAllowedSeaport([
        marketplaceContract.address,
        address1,
      ])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address, address1]);

    expect(await tokenSeaDropInterface.getAllowedSeaport()).to.deep.eq([
      marketplaceContract.address,
      address1,
    ]);

    await expect(tokenSeaDropInterface.updateAllowedSeaport([address2]))
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([address2]);

    expect(await tokenSeaDropInterface.getAllowedSeaport()).to.deep.eq([
      address2,
    ]);

    await expect(
      tokenSeaDropInterface.updateAllowedSeaport([
        address3,
        marketplaceContract.address,
        address2,
        address1,
      ])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([address3, marketplaceContract.address, address2, address1]);

    expect(await tokenSeaDropInterface.getAllowedSeaport()).to.deep.eq([
      address3,
      marketplaceContract.address,
      address2,
      address1,
    ]);

    await expect(
      tokenSeaDropInterface.updateAllowedSeaport([marketplaceContract.address])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address]);

    expect(await tokenSeaDropInterface.getAllowedSeaport()).to.deep.eq([
      marketplaceContract.address,
    ]);
  });

  it("Should let the token owner use admin methods", async () => {
    // Test `updateAllowList` for coverage.
    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await tokenSeaDropInterface.updateAllowList(allowListData);

    await expect(
      tokenSeaDropInterface
        .connect(creator)
        .updateAllowList(allowListData, { gasLimit: 100_000 })
    ).to.be.revertedWithCustomError(token, "Unauthorized");

    // Test `updateSigner` for coverage.
    await tokenSeaDropInterface.updateSigner(`0x${"5".repeat(40)}`, true);

    await expect(
      tokenSeaDropInterface
        .connect(creator)
        .updateSigner(`0x${"5".repeat(40)}`, false, { gasLimit: 100_000 })
    ).to.be.revertedWithCustomError(token, "Unauthorized");

    // Test `updatePayer` for coverage.
    await tokenSeaDropInterface.updatePayer(`0x${"6".repeat(40)}`, true);

    await expect(
      tokenSeaDropInterface
        .connect(creator)
        .updateSigner(`0x${"6".repeat(40)}`, true, { gasLimit: 100_000 })
    ).to.be.revertedWithCustomError(token, "Unauthorized");
  });

  it("Should be able to update the allowed payers", async () => {
    const payer = new ethers.Wallet(randomHex(32), provider);
    const payer2 = new ethers.Wallet(randomHex(32), provider);
    await faucet(payer.address, provider);
    await faucet(payer2.address, provider);

    await expect(
      tokenSeaDropInterface.updatePayer(payer.address, false, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(token, "PayerNotPresent");

    await tokenSeaDropInterface.updatePayer(payer.address, true);

    // Ensure that the same payer cannot be added twice.
    await expect(
      tokenSeaDropInterface.updatePayer(payer.address, true, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(token, "DuplicatePayer");

    // Ensure that the zero address cannot be added as a payer.
    await expect(
      tokenSeaDropInterface.updatePayer(AddressZero, true, {
        gasLimit: 100_000,
      })
    ).to.be.revertedWithCustomError(token, "PayerCannotBeZeroAddress");

    // Remove the original payer for branch coverage.
    await tokenSeaDropInterface.updatePayer(payer.address, false);
    let payers = await tokenSeaDropInterface.getPayers();
    expect(payers).to.deep.eq([]);

    // Add two signers and remove the second for branch coverage.
    await tokenSeaDropInterface.updatePayer(payer.address, true);
    await tokenSeaDropInterface.updatePayer(payer2.address, true);
    await tokenSeaDropInterface.updatePayer(payer2.address, false);
    payers = await tokenSeaDropInterface.getPayers();
    expect(payers).to.deep.eq([payer.address]);
  });

  it("Should only let the owner call update functions", async () => {
    const onlyOwnerMethods = [
      "updateAllowedSeaport",
      "updatePublicDrop",
      "updateAllowList",
      "updateDropURI",
      "updateCreatorPayouts",
      "updateAllowedFeeRecipient",
      "updateSigner",
      "updatePayer",
    ];

    const methodParams: any = {
      updateAllowedSeaport: [[token.address]],
      updatePublicDrop: [publicDrop, 0],
      updateAllowList: [allowListData],
      updateDropURI: ["http://test.com"],
      updateCreatorPayouts: [
        [{ payoutAddress: `0x${"4".repeat(40)}`, basisPoints: 10_000 }],
      ],
      updateAllowedFeeRecipient: [`0x${"4".repeat(40)}`, true],
      updateSigner: [`0x${"4".repeat(40)}`, true],
      updatePayer: [`0x${"4".repeat(40)}`, true],
    };

    for (const method of onlyOwnerMethods) {
      await (tokenSeaDropInterface as any)
        .connect(owner)
        [method](...methodParams[method]);

      await expect(
        (tokenSeaDropInterface as any)
          .connect(creator)
          [method](...methodParams[method], {
            gasLimit: 100_000,
          })
      ).to.be.revertedWithCustomError(token, "Unauthorized");
    }
  });

  it("Should be able to use the multiConfigure method", async () => {
    await tokenSeaDropInterface.updateAllowedFeeRecipient(
      feeRecipient.address,
      false
    );

    const config = {
      maxSupplyTokenIds: [0, 1],
      maxSupplyAmounts: [100, 101],
      baseURI: "https://example1.com",
      contractURI: "https://example2.com",
      seaDropImpl: token.address,
      publicDrops: [publicDrop],
      publicDropsIndexes: [0],
      dropURI: "https://example3.com",
      allowListData,
      creatorPayouts: [{ payoutAddress: creator.address, basisPoints: 10_000 }],
      provenanceHash: `0x${"3".repeat(64)}`,
      allowedFeeRecipients: [feeRecipient.address],
      disallowedFeeRecipients: [],
      allowedPayers: [`0x${"4".repeat(40)}`, `0x${"5".repeat(40)}`],
      disallowedPayers: [],
      allowedSigners: [`0x${"8".repeat(40)}`, `0x${"9".repeat(40)}`],
      disallowedSigners: [],
      royaltyReceiver: `0x${"12".repeat(20)}`,
      royaltyBps: 1_000,
      mintRecipient: AddressZero,
      mintTokenIds: [],
      mintAmounts: [],
    };

    await expect(
      configurer.connect(creator).multiConfigure(token.address, config)
    ).to.be.revertedWithCustomError(token, "Unauthorized");

    // Should revert if maxSupplyTokenIds.length != maxSupplyAmounts.length
    await expect(
      configurer.multiConfigure(token.address, {
        ...config,
        maxSupplyAmounts: config.maxSupplyAmounts.slice(1),
      })
    ).to.be.revertedWithCustomError(token, "MaxSupplyMismatch");

    // Should revert if publicDrops.length != publicDropsIndexes.length
    await expect(
      configurer.multiConfigure(token.address, {
        ...config,
        publicDropsIndexes: config.publicDropsIndexes.slice(1),
      })
    ).to.be.revertedWithCustomError(token, "PublicDropsMismatch");

    await expect(configurer.multiConfigure(token.address, config))
      .to.emit(token, "DropURIUpdated")
      .withArgs("https://example3.com");

    const checkResults = async () => {
      expect(await token.maxSupply(0)).to.eq(100);
      expect(await token.maxSupply(1)).to.eq(101);
      expect(await token.baseURI()).to.eq("https://example1.com");
      expect(await token.contractURI()).to.eq("https://example2.com");
      expect(await token.provenanceHash()).to.eq(`0x${"3".repeat(64)}`);

      const publicDrop = await tokenSeaDropInterface.getPublicDrop(0);
      const creatorPayouts = await tokenSeaDropInterface.getCreatorPayouts();
      const allowListMerkleRoot =
        await tokenSeaDropInterface.getAllowListMerkleRoot();
      const allowedFeeRecipients =
        await tokenSeaDropInterface.getAllowedFeeRecipients();
      const signers = await tokenSeaDropInterface.getSigners();
      const payers = await tokenSeaDropInterface.getPayers();

      expect(publicDrop).to.deep.eq([
        publicDrop.startPrice,
        publicDrop.endPrice,
        publicDrop.startTime,
        publicDrop.endTime,
        publicDrop.restrictFeeRecipients,
        publicDrop.paymentToken,
        publicDrop.fromTokenId,
        publicDrop.toTokenId,
        publicDrop.maxTotalMintableByWallet,
        publicDrop.maxTotalMintableByWalletPerToken,
        publicDrop.feeBps,
      ]);
      expect(creatorPayouts).to.deep.eq([[creator.address, 10_000]]);
      expect(allowListMerkleRoot).to.eq(allowListData.merkleRoot);
      expect(allowedFeeRecipients).to.deep.eq([feeRecipient.address]);
      expect(payers).to.deep.eq(config.allowedPayers);
      expect(signers).to.deep.eq(config.allowedSigners);
      expect(await token.royaltyInfo(0, 100)).to.deep.eq([
        config.royaltyReceiver,
        BigNumber.from(config.royaltyBps).mul(100).div(10_000),
      ]);
    };
    await checkResults();

    // Should not do anything if all fields are zeroed out
    const zeroedConfig = {
      maxSupplyTokenIds: [],
      maxSupplyAmounts: [],
      baseURI: "",
      contractURI: "",
      seaDropImpl: token.address,
      publicDrops: [],
      publicDropsIndexes: [],
      dropURI: "",
      allowListData: {
        merkleRoot: HashZero,
        publicKeyURIs: [],
        allowListURI: "",
      },
      creatorPayouts: [],
      provenanceHash: HashZero,
      allowedFeeRecipients: [],
      disallowedFeeRecipients: [],
      allowedPayers: [],
      disallowedPayers: [],
      allowedSigners: [],
      disallowedSigners: [],
      royaltyReceiver: AddressZero,
      royaltyBps: 0,
      mintRecipient: AddressZero,
      mintTokenIds: [],
      mintAmounts: [],
    };
    await expect(
      configurer.multiConfigure(token.address, zeroedConfig)
    ).to.not.emit(token, "DropURIUpdated");
    await checkResults();

    // Should unset properties
    await expect(
      configurer.multiConfigure(token.address, {
        ...zeroedConfig,
        disallowedFeeRecipients: config.allowedFeeRecipients,
      })
    )
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, false);
    expect(await tokenSeaDropInterface.getPayers()).to.deep.eq(
      config.allowedPayers
    );
    for (const payer of config.allowedPayers) {
      await expect(
        configurer.multiConfigure(token.address, {
          ...zeroedConfig,
          disallowedPayers: [payer],
        })
      )
        .to.emit(token, "PayerUpdated")
        .withArgs(payer, false);
    }
    expect(await tokenSeaDropInterface.getPayers()).to.deep.eq([]);
    expect(await tokenSeaDropInterface.getSigners()).to.deep.eq(
      config.allowedSigners
    );
    for (const signer of config.allowedSigners) {
      await expect(
        configurer.multiConfigure(token.address, {
          ...zeroedConfig,
          disallowedSigners: [signer],
        })
      )
        .to.emit(token, "SignerUpdated")
        .withArgs(signer, false);
    }
    expect(await tokenSeaDropInterface.getSigners()).to.deep.eq([]);

    // Should be able to use the multiConfigure method to mint
    const configWithMint = {
      ...zeroedConfig,
      mintRecipient: minter.address,
      mintTokenIds: [0],
      mintAmounts: [1],
    };
    await expect(configurer.multiConfigure(token.address, configWithMint))
      .to.emit(token, "TransferBatch")
      .withArgs(configurer.address, AddressZero, minter.address, [0], [1]);

    // Should revert if mintAmounts.length != mintAmounts.length
    await expect(
      configurer.multiConfigure(token.address, {
        ...configWithMint,
        mintAmounts: configWithMint.mintAmounts.slice(1),
      })
    ).to.be.revertedWithCustomError(token, "MintAmountsMismatch");

    // Ensure multiConfigureMint can only be used by the owner and configurer.
    await expect(
      tokenSeaDropInterface
        .connect(minter)
        .multiConfigureMint(minter.address, [0], [1], {
          gasLimit: 100_000,
        })
    ).to.revertedWithCustomError(token, "Unauthorized");
  });

  it("Should not allow reentrancy during mint", async () => {
    // Set a public drop with maxTotalMintableByWallet: 1
    // and restrictFeeRecipient: false
    const oneEther = parseEther("1");
    await tokenSeaDropInterface.updatePublicDrop(
      {
        ...publicDrop,
        startPrice: oneEther,
        endPrice: oneEther,
        maxTotalMintableByWallet: 1,
        restrictFeeRecipients: false,
      },
      0
    );

    const MaliciousRecipientFactory = await ethers.getContractFactory(
      "MaliciousRecipient",
      owner
    );
    const maliciousRecipient = await MaliciousRecipientFactory.deploy();

    // Set the creator address to MaliciousRecipient.
    await tokenSeaDropInterface
      .connect(owner)
      .updateCreatorPayouts([
        { payoutAddress: maliciousRecipient.address, basisPoints: 10_000 },
      ]);

    // Should not be able to mint with reentrancy.
    await maliciousRecipient.setStartAttack({ value: oneEther.mul(10) });
    await expect(
      maliciousRecipient.attack(marketplaceContract.address, token.address)
    ).to.be.revertedWithCustomError(marketplaceContract, "NoReentrantCalls");
    expect(await token.totalSupply(0)).to.eq(0);
  });

  it("Should allow multiple creator payout addresses", async () => {
    // Valid cases
    await expect(
      tokenSeaDropInterface.updateCreatorPayouts([
        { payoutAddress: creator.address, basisPoints: 10_000 },
      ])
    ).to.emit(token, "CreatorPayoutsUpdated");
    // .withArgs([[creator.address, 10_000]]);
    let creatorPayouts = await tokenSeaDropInterface.getCreatorPayouts();
    expect(creatorPayouts).to.deep.eq([[creator.address, 10_000]]);

    await expect(
      tokenSeaDropInterface.updateCreatorPayouts([
        { payoutAddress: creator.address, basisPoints: 5_000 },
        { payoutAddress: owner.address, basisPoints: 5_000 },
      ])
    ).to.emit(token, "CreatorPayoutsUpdated");
    // withArgs not working, might be fixed when this is resolved:
    // https://github.com/NomicFoundation/hardhat/issues/3833
    // .withArgs([
    //   [creator.address, 5_000],
    //   [owner.address, 5_000],
    // ]);
    creatorPayouts = await tokenSeaDropInterface.getCreatorPayouts();
    expect(creatorPayouts).to.deep.eq([
      [creator.address, 5_000],
      [owner.address, 5_000],
    ]);

    await expect(
      tokenSeaDropInterface.updateCreatorPayouts([
        { payoutAddress: creator.address, basisPoints: 9_000 },
        { payoutAddress: owner.address, basisPoints: 500 },
        { payoutAddress: minter.address, basisPoints: 500 },
      ])
    ).to.emit(token, "CreatorPayoutsUpdated");
    // .withArgs([
    //   [creator.address, 9_000],
    //   [owner.address, 500],
    //   [minter.address, 500],
    // ]);
    creatorPayouts = await tokenSeaDropInterface.getCreatorPayouts();
    expect(creatorPayouts).to.deep.eq([
      [creator.address, 9_000],
      [owner.address, 500],
      [minter.address, 500],
    ]);

    await expect(
      tokenSeaDropInterface.updateCreatorPayouts([
        { payoutAddress: creator.address, basisPoints: 100 },
        { payoutAddress: owner.address, basisPoints: 100 },
        { payoutAddress: minter.address, basisPoints: 9_800 },
      ])
    ).to.emit(token, "CreatorPayoutsUpdated");
    // .withArgs([
    //   [creator.address, 100],
    //   [owner.address, 100],
    //   [minter.address, 9_800],
    // ]);
    creatorPayouts = await tokenSeaDropInterface.getCreatorPayouts();
    expect(creatorPayouts).to.deep.eq([
      [creator.address, 100],
      [owner.address, 100],
      [minter.address, 9_800],
    ]);

    await expect(
      tokenSeaDropInterface.updateCreatorPayouts([
        { payoutAddress: creator.address, basisPoints: 1_000 },
        { payoutAddress: owner.address, basisPoints: 1_000 },
        { payoutAddress: minter.address, basisPoints: 1_000 },
        { payoutAddress: creator.address, basisPoints: 1_000 },
        { payoutAddress: owner.address, basisPoints: 1_000 },
        { payoutAddress: minter.address, basisPoints: 5_000 },
      ])
    ).to.emit(token, "CreatorPayoutsUpdated");
    // .withArgs([
    //   [creator.address, 1_000],
    //   [owner.address, 1_000],
    //   [minter.address, 1_000],
    //   [creator.address, 1_000],
    //   [owner.address, 1_000],
    //   [minter.address, 5_000],
    // ]);
    creatorPayouts = await tokenSeaDropInterface.getCreatorPayouts();
    expect(creatorPayouts).to.deep.eq([
      [creator.address, 1_000],
      [owner.address, 1_000],
      [minter.address, 1_000],
      [creator.address, 1_000],
      [owner.address, 1_000],
      [minter.address, 5_000],
    ]);

    // Invalid cases
    await expect(
      tokenSeaDropInterface.updateCreatorPayouts(
        [
          { payoutAddress: creator.address, basisPoints: 100 },
          { payoutAddress: owner.address, basisPoints: 100 },
          { payoutAddress: minter.address, basisPoints: 9_700 },
          { payoutAddress: AddressZero, basisPoints: 100 },
        ],
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(
      token,
      "CreatorPayoutAddressCannotBeZeroAddress"
    );

    await expect(
      tokenSeaDropInterface.updateCreatorPayouts(
        [
          { payoutAddress: creator.address, basisPoints: 100 },
          { payoutAddress: owner.address, basisPoints: 0 },
          { payoutAddress: minter.address, basisPoints: 9_900 },
        ],
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(
      token,
      "CreatorPayoutBasisPointsCannotBeZero"
    );

    await expect(
      tokenSeaDropInterface.updateCreatorPayouts(
        [
          { payoutAddress: creator.address, basisPoints: 100 },
          { payoutAddress: owner.address, basisPoints: 10 },
          { payoutAddress: minter.address, basisPoints: 1 },
        ],
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(
      token,
      "InvalidCreatorPayoutTotalBasisPoints"
    );
    await expect(
      tokenSeaDropInterface.updateCreatorPayouts(
        [{ payoutAddress: creator.address, basisPoints: 10_001 }],
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(
      token,
      "InvalidCreatorPayoutTotalBasisPoints"
    );
    await expect(
      tokenSeaDropInterface.updateCreatorPayouts(
        [
          { payoutAddress: creator.address, basisPoints: 9_998 },
          { payoutAddress: owner.address, basisPoints: 1 },
        ],
        { gasLimit: 100_000 }
      )
    ).to.be.revertedWithCustomError(
      token,
      "InvalidCreatorPayoutTotalBasisPoints"
    );
  });

  it("Should handle ERC20 payment tokens without and with conduit", async () => {
    // Deploy the payment token.
    const TestERC20 = await ethers.getContractFactory("TestERC20", minter);
    const paymentToken = await TestERC20.deploy();

    const publicDropERC20PaymentToken = {
      ...publicDrop,
      paymentToken: paymentToken.address,
    };
    await tokenSeaDropInterface.updatePublicDrop(
      publicDropERC20PaymentToken,
      0
    );

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0],
      quantities: [1],
      publicDropIndex: 0,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      paymentToken,
      minter,
      mintType: MintType.PUBLIC,
    });

    // Mint the needed amount of payment tokens to the minter.
    await paymentToken.mint(minter.address, value);

    // Should fail if we have not approved the payment token.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero)
    ).to.be.revertedWith("NOT_AUTHORIZED");

    // Approve the payment token.
    await paymentToken.approve(marketplaceContract.address, value);

    // Now it should succeed.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero)
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        0
      );

    // Confirm the payment token was transferred and user has no balance left.
    expect(await paymentToken.balanceOf(minter.address)).to.eq(0);
    const feeAmount = value.mul(publicDrop.feeBps).div(10_000);
    const creatorAmount = value.sub(feeAmount);
    expect(await paymentToken.balanceOf(feeRecipient.address)).to.eq(feeAmount);
    expect(await paymentToken.balanceOf(creator.address)).to.eq(creatorAmount);

    // Now try with conduit
    await setConduit(token.address, conduitOne.address);
    // Mint one minus the needed amount of payment tokens to the minter.
    await paymentToken.mint(minter.address, value.sub(1));

    // Should fail if we have not approved the payment token.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], conduitKeyOne, AddressZero)
    ).to.be.revertedWith("NOT_AUTHORIZED");

    // Approve the payment token.
    await paymentToken.approve(conduitOne.address, value);

    // It should still fail as we have one minus the needed balance.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], conduitKeyOne, AddressZero)
    ).to.be.revertedWithPanic("0x11");

    // Mint one more payment token to the minter.
    await paymentToken.mint(minter.address, 1);

    // Now it should succeed.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], conduitKeyOne, AddressZero)
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        0
      );

    // Confirm the payment token was transferred and user has no balance left.
    expect(await paymentToken.balanceOf(minter.address)).to.eq(0);
    // Multiply expected balance for feeRecipient and creator by 2 as we minted twice.
    expect(await paymentToken.balanceOf(feeRecipient.address)).to.eq(
      feeAmount.mul(2)
    );
    expect(await paymentToken.balanceOf(creator.address)).to.eq(
      creatorAmount.mul(2)
    );
  });

  it("Should be able to handle minting multiple tokenIds in the same order for the same stage", async () => {
    await token.setMaxSupply(1, 1);
    let { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0, 1],
      quantities: [1, 1],
      publicDropIndex: 0,
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
        0
      );

    expect(await token.balanceOf(minter.address, 0)).to.eq(1);
    expect(await token.balanceOf(minter.address, 1)).to.eq(1);
    expect(
      await token.balanceOfBatch([minter.address, minter.address], [0, 1])
    ).to.deep.eq([1, 1]);

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // MintQuantityExceedsMaxSupply, .withArgs(2, 1)

    // Should revert if duplicate tokenIds are provided.
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0, 1, 0],
      quantities: [1, 1, 1],
      publicDropIndex: 0,
      feeRecipient,
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
    ); // OfferContainsDuplicateTokenId

    // Ensure we cannot exceed maxTotalMintableByWallet with the total mint quantity.
    // We have already minted 2 tokens.
    await tokenSeaDropInterface.updatePublicDrop(
      { ...publicDrop, maxTotalMintableByWallet: 3 },
      0
    );
    await token.setMaxSupply(7, 1);
    await token.setMaxSupply(8, 1);
    expect(await token.balanceOf(minter.address, 7)).to.eq(0);
    expect(await token.balanceOf(minter.address, 8)).to.eq(0);
    ({ order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [7, 8],
      quantities: [1, 1],
      publicDropIndex: 0,
      feeRecipient,
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
    ); // MintQuantityExceedsMaxMintedPerWallet withArgs(4, 3)

    // Update maxTotalMintableByWallet to 4, the order should now succeed.
    await tokenSeaDropInterface.updatePublicDrop(
      { ...publicDrop, maxTotalMintableByWallet: 4 },
      0
    );

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero, { value })
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address, // payer
        0
      );

    expect(await token.balanceOf(minter.address, 7)).to.eq(1);
    expect(await token.balanceOf(minter.address, 8)).to.eq(1);
  });

  it("Should return the expected values for getSeaportMetadata", async () => {
    const getSeaportMetadataSelector = "0x2e778efc";
    const returnData = await minter.call({
      to: token.address,
      data: getSeaportMetadataSelector,
    });

    const [name, schemas] = defaultAbiCoder.decode(
      ["string", "tuple(uint256, bytes)[]"],
      returnData
    );

    const supportedSubstandards = [0, 1, 2];
    const metadata = defaultAbiCoder.encode(
      ["uint256[]"],
      [supportedSubstandards]
    );

    expect({
      name,
      schemas,
    }).to.deep.eq({
      name: "ERC1155SeaDrop",
      schemas: [[BigNumber.from(12), metadata]],
    });
  });

  it("Should be able to mint with 100% fee bps", async () => {
    await tokenSeaDropInterface.updatePublicDrop(
      {
        ...publicDrop,
        feeBps: 10_000, // 100%
      },
      0
    );

    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0],
      quantities: [1],
      publicDropIndex: 0,
      feeRecipient,
      feeBps: 10_000,
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
        0
      );

    expect(await token.balanceOf(minter.address, 0)).to.eq(1);
  });

  it("Should return errors for invalid encodings", async () => {
    const { order, value } = await createMintOrder({
      token,
      tokenSeaDropInterface,
      tokenIds: [0],
      quantities: [1],
      publicDropIndex: 0,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      price: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          { ...order, extraData: "0x01" + order.extraData.slice(4) },
          [],
          HashZero,
          AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // UnsupportedExtraDataVersion
    // withArgs(1)

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          { ...order, extraData: "0x0004" + order.extraData.slice(6) },
          [],
          HashZero,
          AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidSubstandard
    // withArgs(4)

    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(
          { ...order, extraData: order.extraData.slice(0, 20) },
          [],
          HashZero,
          AddressZero,
          { value }
        )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "InvalidContractOrder"
    ); // InvalidExtraDataEncoding
    // withArgs(0)
  });

  it("Should revert on unsupported function selector", async () => {
    await expect(
      owner.sendTransaction({
        to: token.address,
        data: "0x12345678",
        gasLimit: 50_000,
      })
    )
      .to.be.revertedWithCustomError(token, "UnsupportedFunctionSelector")
      .withArgs("0x12345678");
  });
});
