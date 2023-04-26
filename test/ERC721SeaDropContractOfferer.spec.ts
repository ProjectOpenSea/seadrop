import { time } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";

import {
  ContractOffererInterface__factory,
  IERC165__factory,
  IERC2981__factory,
  IERC721__factory,
  INonFungibleSeaDropToken__factory,
  ISeaDropTokenContractMetadata__factory,
} from "../typechain-types";

import { getItemETH, toBN } from "./seaport-utils/encoding";
import { seaportFixture } from "./seaport-utils/fixtures";
import { getInterfaceID, randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import {
  VERSION,
  deployERC721SeaDrop,
  mintTokens,
  setMintRecipientStorageSlot,
} from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";
import { MintType, createMintOrder, expectedPrice } from "./utils/order";

import type { SeaportFixtures } from "./seaport-utils/fixtures";
import type { AwaitedObject } from "./utils/helpers";
import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDrop,
  ERC721SeaDropConfigurer,
} from "../typechain-types";
import type {
  PublicDropStruct,
  SignedMintValidationParamsStruct,
  TokenGatedDropStageStruct,
} from "../typechain-types/src/ERC721SeaDrop";
import type { AllowListDataStruct } from "../typechain-types/src/shim/Shim";
import type { Wallet } from "ethers";

const { BigNumber } = ethers;
const { AddressZero, HashZero } = ethers.constants;
const { defaultAbiCoder, parseEther } = ethers.utils;

describe(`ERC721SeaDropContractOfferer (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;
  let conduitKeyOne: string;
  let createOrder: SeaportFixtures["createOrder"];

  // SeaDrop
  let token: ERC721SeaDrop;
  let configurer: ERC721SeaDropConfigurer;
  let owner: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let publicDrop: AwaitedObject<PublicDropStruct>;
  let tokenGatedDropStage: AwaitedObject<TokenGatedDropStageStruct>;
  let signedMintValidationParams: AwaitedObject<SignedMintValidationParamsStruct>;
  let allowListData: AwaitedObject<AllowListDataStruct>;

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
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, minter, creator, feeRecipient]) {
      await faucet(wallet.address, provider);
    }

    ({ conduitOne, conduitKeyOne, createOrder, marketplaceContract } =
      await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy token
    ({ token, configurer } = await deployERC721SeaDrop(
      owner,
      marketplaceContract.address,
      conduitOne.address
    ));

    publicDrop = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      paymentToken: AddressZero,
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };

    tokenGatedDropStage = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
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

    signedMintValidationParams = {
      minMintPrice: 10,
      paymentToken: AddressZero,
      maxMaxTotalMintableByWallet: 5,
      minStartTime: 50,
      maxEndTime: 100,
      maxMaxTokenSupplyForStage: 100,
      minFeeBps: 5,
      maxFeeBps: 1000,
    };

    allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };

    await token.setMaxSupply(5);
    await configurer.updatePublicDrop(token.address, publicDrop);
    await configurer.updateAllowedFeeRecipient(
      token.address,
      feeRecipient.address,
      true
    );
    await configurer.updateCreatorPayouts(token.address, [
      { payoutAddress: creator.address, basisPoints: 10_000 },
    ]);
  });

  it("Should emit an event when the contract is deployed", async () => {
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    const tx = await ERC721SeaDrop.deploy(
      "",
      "",
      AddressZero,
      marketplaceContract.address,
      conduitOne.address
    );
    const receipt = await tx.deployTransaction.wait();
    const event = (receipt as any).events.filter(
      ({ event }: any) => event === "SeaDropTokenDeployed"
    );
    expect(event).to.not.be.null;
  });

  it("Should not be able to mint until the creator payout is set", async () => {
    const { token: token2, configurer: configurer2 } =
      await deployERC721SeaDrop(
        owner,
        marketplaceContract.address,
        conduitOne.address
      );

    await token2.setMaxSupply(5);
    await configurer2.updatePublicDrop(token2.address, publicDrop);
    await configurer2.updateAllowedFeeRecipient(
      token2.address,
      feeRecipient.address,
      true
    );

    expect(await configurer2.getCreatorPayouts(token2.address)).to.deep.equal(
      []
    );
    await expect(
      configurer2.updateCreatorPayouts(token2.address, [])
    ).to.be.revertedWithCustomError(token2, "CreatorPayoutsNotSet");

    let { order, value } = await createMintOrder({
      token: token2,
      configurer: configurer2,
      quantity: 1,
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

    await configurer2.updateCreatorPayouts(token2.address, [
      { payoutAddress: creator.address, basisPoints: 1_000 },
      { payoutAddress: owner.address, basisPoints: 9_000 },
    ]);

    ({ order, value } = await createMintOrder({
      token: token2,
      configurer: configurer2,
      quantity: 1,
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
    )
      .to.emit(token2, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // quantity
        publicDrop.endPrice,
        publicDrop.paymentToken,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
      );
  });

  it("Should only let the token owner update the drop URI", async () => {
    await expect(
      configurer
        .connect(creator)
        .updateDropURI(token.address, "http://test.com")
    ).to.revertedWithCustomError(token, "OnlyOwner");

    await expect(configurer.updateDropURI(token.address, "http://test.com"))
      .to.emit(token, "DropURIUpdated")
      .withArgs("http://test.com");
  });

  it("Should only let the owner update the allowed fee recipients", async () => {
    await configurer.updateAllowedFeeRecipient(
      token.address,
      feeRecipient.address,
      false
    );
    expect(await configurer.getAllowedFeeRecipients(token.address)).to.deep.eq(
      []
    );

    await expect(
      configurer.updateAllowedFeeRecipient(token.address, AddressZero, true)
    ).to.be.revertedWithCustomError(token, "FeeRecipientCannotBeZeroAddress");

    await expect(
      configurer.updateAllowedFeeRecipient(
        token.address,
        feeRecipient.address,
        true
      )
    )
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, true);

    await expect(
      configurer.updateAllowedFeeRecipient(
        token.address,
        feeRecipient.address,
        true
      )
    ).to.be.revertedWithCustomError(token, "DuplicateFeeRecipient");

    expect(await configurer.getAllowedFeeRecipients(token.address)).to.deep.eq([
      feeRecipient.address,
    ]);

    // Now let's disallow the feeRecipient
    await expect(
      configurer.updateAllowedFeeRecipient(
        token.address,
        feeRecipient.address,
        false
      )
    )
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, false);

    expect(await configurer.getAllowedFeeRecipients(token.address)).to.deep.eq(
      []
    );

    await expect(
      configurer.updateAllowedFeeRecipient(
        token.address,
        feeRecipient.address,
        false
      )
    ).to.be.revertedWithCustomError(token, "FeeRecipientNotPresent");
  });

  it("Should handle desc and asc mint prices", async () => {
    const publicDropDescMintPrice = {
      ...publicDrop,
      startPrice: parseEther("1"),
      endPrice: parseEther(".1"),
    };
    await configurer.updatePublicDrop(token.address, publicDropDescMintPrice);

    let { order, value } = await createMintOrder({
      token,
      configurer,
      quantity: 1,
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
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // quantity
        expected,
        publicDrop.paymentToken,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
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
    await configurer.updatePublicDrop(token.address, publicDropAscMintPrice);
    ({ order, value } = await createMintOrder({
      token,
      configurer,
      quantity: 1,
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
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // quantity
        expected,
        publicDrop.paymentToken,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
      );

    receipt = await (await tx).wait();
    txCost = receipt.gasUsed.mul(receipt.effectiveGasPrice);
    // Should refund the difference between the expected price and the provided amount.
    balanceAfter = await provider.getBalance(minter.address);
    expect(balanceAfter).to.eq(balanceBefore.sub(expected).sub(txCost));

    // Should allow newly minted tokens to be transferred in Seaport secondary sales.
    expect(await token.ownerOf(1)).to.eq(minter.address);
    expect(await token.ownerOf(2)).to.eq(minter.address);
    const offerItem = {
      itemType: 2, // ERC721
      token: token.address,
      identifierOrCriteria: toBN(1),
      startAmount: toBN(1),
      endAmount: toBN(1),
    };
    const offer = [
      { ...offerItem, identifierOrCriteria: toBN(1) },
      { ...offerItem, identifierOrCriteria: toBN(2) },
    ];
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
    expect(await token.ownerOf(1)).to.eq(owner.address);
    expect(await token.ownerOf(2)).to.eq(owner.address);
  });

  it("Should only let the owner set the provenance hash", async () => {
    await token.setMaxSupply(1);
    expect(await token.provenanceHash()).to.equal(HashZero);

    const defaultProvenanceHash = `0x${"0".repeat(64)}`;
    const firstProvenanceHash = `0x${"1".repeat(64)}`;
    const secondProvenanceHash = `0x${"2".repeat(64)}`;

    await expect(
      token.connect(creator).setProvenanceHash(firstProvenanceHash)
    ).to.revertedWithCustomError(token, "OnlyOwner");

    await expect(token.setProvenanceHash(firstProvenanceHash))
      .to.emit(token, "ProvenanceHashUpdated")
      .withArgs(defaultProvenanceHash, firstProvenanceHash);

    // Provenance hash should not be updatable after the first token has minted.
    // Mint a token.
    await mintTokens({
      marketplaceContract,
      token,
      minter,
      quantity: 1,
    });

    await expect(
      token.setProvenanceHash(secondProvenanceHash)
    ).to.be.revertedWithCustomError(
      token,
      "ProvenanceHashCannotBeSetAfterMintStarted"
    );

    expect(await token.provenanceHash()).to.equal(firstProvenanceHash);
  });

  it("Should only let allowed seaport or conduit call the ERC1155 safeTransferFrom", async () => {
    await token.setMaxSupply(3);

    const safeTransferFrom1155Selector = "0xf242432a";
    const encodedParams = defaultAbiCoder.encode(
      ["address", "address", "uint256", "uint256", "bytes"],
      [token.address, AddressZero, 0, 1, []]
    );
    const data = safeTransferFrom1155Selector + encodedParams.slice(2);

    await setMintRecipientStorageSlot(token, minter);
    await whileImpersonating(
      marketplaceContract.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          impersonatedSigner.sendTransaction({ to: token.address, data })
        )
          .to.emit(token, "Transfer")
          .withArgs(AddressZero, minter.address, 1);
      }
    );

    // Mint as conduit
    await setMintRecipientStorageSlot(token, minter);
    await whileImpersonating(
      conduitOne.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          impersonatedSigner.sendTransaction({ to: token.address, data })
        )
          .to.emit(token, "Transfer")
          .withArgs(AddressZero, minter.address, 2);
      }
    );

    // Mint as owner
    await expect(
      owner.sendTransaction({ to: token.address, data, gasLimit: 100_000 })
    )
      .to.be.revertedWithCustomError(
        token,
        "InvalidCallerOnlyAllowedSeaportOrConduit"
      )
      .withArgs(owner.address);

    // Mint with wrong "from" address
    const dataWrongFrom =
      safeTransferFrom1155Selector +
      defaultAbiCoder
        .encode(
          ["address", "address", "uint256", "uint256", "bytes"],
          [marketplaceContract.address, minter.address, 0, 1, []]
        )
        .slice(2);
    await whileImpersonating(
      conduitOne.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          impersonatedSigner.sendTransaction({
            to: token.address,
            data: dataWrongFrom,
          })
        )
          .to.be.revertedWithCustomError(
            token,
            "InvalidCallerOnlyAllowedSeaportOrConduit"
          )
          .withArgs(conduitOne.address);
      }
    );
  });

  it("Should return supportsInterface true for supported interfaces", async () => {
    // const supportedInterfacesERC721SeaDrop = [
    //   [
    //     INonFungibleSeaDropToken__factory,
    //     ISeaDropTokenContractMetadata__factory,
    //   ],
    //   [IERC165__factory],
    // ];
    const supportedInterfacesERC721ContractMetadata = [
      [ISeaDropTokenContractMetadata__factory, IERC2981__factory],
      [IERC2981__factory, IERC165__factory],
    ];
    const supportedInterfacesERC721A = [
      [IERC721__factory, IERC165__factory],
      [IERC165__factory],
    ];

    for (const factories of [
      // ...supportedInterfacesERC721SeaDrop,
      ...supportedInterfacesERC721ContractMetadata,
      ...supportedInterfacesERC721A,
    ]) {
      const interfaceId = factories
        .map((factory) => getInterfaceID(factory.createInterface()))
        .reduce((prev, curr) => prev.xor(curr))
        .toHexString();
      expect(await token.supportsInterface(interfaceId)).to.be.true;
    }

    // Ensure the interface `INonFungibleSeaDropToken` returns true.
    // expect(await token.supportsInterface("0x1890fe8e")).to.be.true;
    // TODO uncomment above once interface id is derived

    // Ensure the supported interfaces from ERC721A return true.
    // 0x80ac58cd: ERC721
    expect(await token.supportsInterface("0x80ac58cd")).to.be.true;
    // 0x5b5e139f: ERC721Metadata
    expect(await token.supportsInterface("0x5b5e139f")).to.be.true;
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
      configurer
        .connect(creator)
        .updateAllowedSeaport(token.address, [marketplaceContract.address])
    ).to.revertedWithCustomError(token, "OnlyOwner");

    await expect(
      configurer
        .connect(minter)
        .updateAllowedSeaport(token.address, [marketplaceContract.address])
    ).to.revertedWithCustomError(token, "OnlyOwner");

    await expect(
      configurer.updateAllowedSeaport(token.address, [
        marketplaceContract.address,
      ])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address]);

    const address1 = `0x${"1".repeat(40)}`;
    const address2 = `0x${"2".repeat(40)}`;
    const address3 = `0x${"3".repeat(40)}`;

    await expect(
      configurer.updateAllowedSeaport(token.address, [
        marketplaceContract.address,
        address1,
      ])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address, address1]);

    await expect(configurer.updateAllowedSeaport(token.address, [address2]))
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([address2]);

    await expect(
      configurer.updateAllowedSeaport(token.address, [
        address3,
        marketplaceContract.address,
        address2,
        address1,
      ])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([address3, marketplaceContract.address, address2, address1]);

    await expect(
      configurer.updateAllowedSeaport(token.address, [
        marketplaceContract.address,
      ])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address]);
  });

  it("Should let the token owner use admin methods", async () => {
    // Test `updateAllowList` for coverage.
    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await configurer.updateAllowList(token.address, allowListData);

    await expect(
      configurer.connect(creator).updateAllowList(token.address, allowListData)
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Test `updateTokenGatedDrop` for coverage.

    await configurer.updateTokenGatedDrop(
      token.address,
      `0x${"4".repeat(40)}`,
      tokenGatedDropStage
    );

    await expect(
      configurer
        .connect(creator)
        .updateTokenGatedDrop(
          token.address,
          `0x${"4".repeat(40)}`,
          tokenGatedDropStage
        )
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Test `updateSigner` for coverage.
    await configurer.updateSignedMintValidationParams(
      token.address,
      `0x${"5".repeat(40)}`,
      signedMintValidationParams
    );

    await expect(
      configurer
        .connect(creator)
        .updateSignedMintValidationParams(
          token.address,
          `0x${"5".repeat(40)}`,
          signedMintValidationParams
        )
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Test `updatePayer` for coverage.
    await configurer.updatePayer(token.address, `0x${"6".repeat(40)}`, true);

    await expect(
      configurer
        .connect(creator)
        .updateSignedMintValidationParams(
          token.address,
          `0x${"6".repeat(40)}`,
          signedMintValidationParams
        )
    ).to.be.revertedWithCustomError(token, "OnlyOwner");
  });

  it("Should be able to update the allowed payers", async () => {
    const payer = new ethers.Wallet(randomHex(32), provider);
    const payer2 = new ethers.Wallet(randomHex(32), provider);
    await faucet(payer.address, provider);
    await faucet(payer2.address, provider);

    await expect(
      configurer.updatePayer(token.address, payer.address, false)
    ).to.be.revertedWithCustomError(token, "PayerNotPresent");

    await configurer.updatePayer(token.address, payer.address, true);

    // Ensure that the same payer cannot be added twice.
    await expect(
      configurer.updatePayer(token.address, payer.address, true)
    ).to.be.revertedWithCustomError(token, "DuplicatePayer");

    // Ensure that the zero address cannot be added as a payer.
    await expect(
      configurer.updatePayer(token.address, AddressZero, true)
    ).to.be.revertedWithCustomError(token, "PayerCannotBeZeroAddress");

    // Remove the original payer for branch coverage.
    await configurer.updatePayer(token.address, payer.address, false);
    expect(await configurer.getPayers(token.address)).to.deep.eq([]);

    // Add two signers and remove the second for branch coverage.
    await configurer.updatePayer(token.address, payer.address, true);
    await configurer.updatePayer(token.address, payer2.address, true);
    await configurer.updatePayer(token.address, payer2.address, false);
    expect(await configurer.getPayers(token.address)).to.deep.eq([
      payer.address,
    ]);
  });

  it("Should only let the owner call update functions", async () => {
    const onlyOwnerMethods = [
      "updateAllowedSeaport",
      "updatePublicDrop",
      "updateAllowList",
      "updateTokenGatedDrop",
      "updateDropURI",
      "updateCreatorPayouts",
      "updateAllowedFeeRecipient",
      "updateSignedMintValidationParams",
      "updatePayer",
    ];

    const methodParams: any = {
      updateAllowedSeaport: [[token.address]],
      updatePublicDrop: [publicDrop],
      updateAllowList: [allowListData],
      updateTokenGatedDrop: [`0x${"4".repeat(40)}`, tokenGatedDropStage],
      updateDropURI: ["http://test.com"],
      updateCreatorPayouts: [
        [{ payoutAddress: `0x${"4".repeat(40)}`, basisPoints: 10_000 }],
      ],
      updateAllowedFeeRecipient: [`0x${"4".repeat(40)}`, true],
      updateSignedMintValidationParams: [
        `0x${"4".repeat(40)}`,
        signedMintValidationParams,
      ],
      updatePayer: [`0x${"4".repeat(40)}`, true],
    };

    for (const method of onlyOwnerMethods) {
      await (configurer as any)
        .connect(owner)
        [method](token.address, ...methodParams[method]);

      await expect(
        (configurer as any)
          .connect(creator)
          [method](token.address, ...methodParams[method])
      ).to.be.revertedWithCustomError(token, "OnlyOwner");
    }
  });

  it("Should be able to use the multiConfigure method", async () => {
    await configurer.updateAllowedFeeRecipient(
      token.address,
      feeRecipient.address,
      false
    );

    const config = {
      maxSupply: 100,
      baseURI: "https://example1.com",
      contractURI: "https://example2.com",
      seaDropImpl: token.address,
      publicDrop,
      dropURI: "https://example3.com",
      allowListData,
      creatorPayouts: [{ payoutAddress: creator.address, basisPoints: 10_000 }],
      provenanceHash: `0x${"3".repeat(64)}`,
      allowedFeeRecipients: [feeRecipient.address],
      disallowedFeeRecipients: [],
      allowedPayers: [`0x${"4".repeat(40)}`, `0x${"5".repeat(40)}`],
      disallowedPayers: [],
      tokenGatedAllowedNftTokens: [
        `0x${"6".repeat(40)}`,
        `0x${"7".repeat(40)}`,
      ],
      tokenGatedDropStages: [
        tokenGatedDropStage,
        {
          ...tokenGatedDropStage,
          price: tokenGatedDropStage.startPrice + "1",
          endPrice: tokenGatedDropStage.endPrice + "1",
        },
      ],
      disallowedTokenGatedAllowedNftTokens: [],
      signers: [`0x${"8".repeat(40)}`, `0x${"9".repeat(40)}`],
      signedMintValidationParams: [
        signedMintValidationParams,
        { ...signedMintValidationParams, minEndTime: 200 },
      ],
      disallowedSigners: [],
      royaltyReceiver: `0x${"12".repeat(20)}`,
      royaltyBps: 1_000,
    };

    await expect(
      configurer.connect(creator).multiConfigure(token.address, config)
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Should revert if tokenGatedAllowedNftToken.length != tokenGatedDropStages.length
    await expect(
      configurer.multiConfigure(token.address, {
        ...config,
        tokenGatedAllowedNftTokens: config.tokenGatedAllowedNftTokens.slice(1),
      })
    ).to.be.revertedWithCustomError(token, "TokenGatedMismatch");

    // Should revert if signers.length != signedMintValidationParams.length
    await expect(
      configurer.multiConfigure(token.address, {
        ...config,
        signers: config.signers.slice(1),
      })
    ).to.be.revertedWithCustomError(token, "SignersMismatch");

    await expect(configurer.multiConfigure(token.address, config))
      .to.emit(token, "DropURIUpdated")
      .withArgs("https://example3.com");

    const checkResults = async () => {
      expect(await token.maxSupply()).to.eq(100);
      expect(await token.baseURI()).to.eq("https://example1.com");
      expect(await token.contractURI()).to.eq("https://example2.com");
      expect(await configurer.getPublicDrop(token.address)).to.deep.eq([
        publicDrop.startPrice,
        publicDrop.endPrice,
        publicDrop.paymentToken,
        publicDrop.startTime,
        publicDrop.endTime,
        publicDrop.maxTotalMintableByWallet,
        publicDrop.feeBps,
        publicDrop.restrictFeeRecipients,
      ]);
      expect(await configurer.getAllowListMerkleRoot(token.address)).to.eq(
        allowListData.merkleRoot
      );
      expect(await configurer.getCreatorPayouts(token.address)).to.deep.eq([
        [creator.address, 10_000],
      ]);
      expect(
        await configurer.getAllowedFeeRecipients(token.address)
      ).to.deep.eq([feeRecipient.address]);
      expect(await configurer.getPayers(token.address)).to.deep.eq(
        config.allowedPayers
      );
      expect(await token.provenanceHash()).to.eq(`0x${"3".repeat(64)}`);
      expect(
        await configurer.getTokenGatedAllowedTokens(token.address)
      ).to.deep.eq(config.tokenGatedAllowedNftTokens);
      for (const [i, allowed] of config.tokenGatedAllowedNftTokens.entries()) {
        expect(
          await configurer.getTokenGatedDrop(token.address, allowed)
        ).to.deep.eq([
          BigNumber.from(config.tokenGatedDropStages[i].startPrice),
          BigNumber.from(config.tokenGatedDropStages[i].endPrice),
          config.tokenGatedDropStages[i].paymentToken,
          config.tokenGatedDropStages[i].maxMintablePerRedeemedToken,
          config.tokenGatedDropStages[i].maxTotalMintableByWallet,
          config.tokenGatedDropStages[i].startTime,
          config.tokenGatedDropStages[i].endTime,
          config.tokenGatedDropStages[i].dropStageIndex,
          config.tokenGatedDropStages[i].maxTokenSupplyForStage,
          config.tokenGatedDropStages[i].feeBps,
          config.tokenGatedDropStages[i].restrictFeeRecipients,
        ]);
      }
      expect(await configurer.getSigners(token.address)).to.deep.eq(
        config.signers
      );
      for (const [i, signer] of config.signers.entries()) {
        expect(
          await configurer.getSignedMintValidationParams(token.address, signer)
        ).to.deep.eq([
          config.signedMintValidationParams[i].minMintPrice,
          config.signedMintValidationParams[i].paymentToken,
          config.signedMintValidationParams[i].maxMaxTotalMintableByWallet,
          config.signedMintValidationParams[i].minStartTime,
          config.signedMintValidationParams[i].maxEndTime,
          config.signedMintValidationParams[i].maxMaxTokenSupplyForStage,
          config.signedMintValidationParams[i].minFeeBps,
          config.signedMintValidationParams[i].maxFeeBps,
        ]);
      }
      expect(await token.royaltyInfo(0, 100)).to.deep.eq([
        config.royaltyReceiver,
        BigNumber.from(config.royaltyBps).mul(100).div(10_000),
      ]);
    };
    await checkResults();

    // Should not do anything if all fields are zeroed out
    const zeroedConfig = {
      maxSupply: 0,
      baseURI: "",
      contractURI: "",
      seaDropImpl: token.address,
      publicDrop: {
        startPrice: 0,
        endPrice: 0,
        paymentToken: AddressZero,
        maxTotalMintableByWallet: 0,
        startTime: 0,
        endTime: 0,
        feeBps: 0,
        restrictFeeRecipients: true,
      },
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
      tokenGatedAllowedNftTokens: [],
      tokenGatedDropStages: [],
      disallowedTokenGatedAllowedNftTokens: [],
      signers: [],
      signedMintValidationParams: [],
      disallowedSigners: [],
      royaltyReceiver: AddressZero,
      royaltyBps: 0,
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
    await expect(
      configurer.multiConfigure(token.address, {
        ...zeroedConfig,
        disallowedPayers: config.allowedPayers,
      })
    )
      .to.emit(token, "PayerUpdated")
      .withArgs(config.allowedPayers[0], false);
    await expect(
      configurer.multiConfigure(token.address, {
        ...zeroedConfig,
        disallowedTokenGatedAllowedNftTokens: [
          config.tokenGatedAllowedNftTokens[0],
        ],
      })
    )
      .to.emit(token, "TokenGatedDropStageUpdated")
      .withArgs(config.tokenGatedAllowedNftTokens[0], [
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
        false,
      ]);
    await expect(
      configurer.multiConfigure(token.address, {
        ...zeroedConfig,
        disallowedSigners: [config.signers[0]],
      })
    )
      .to.emit(token, "SignedMintValidationParamsUpdated")
      .withArgs(config.signers[0], [0, AddressZero, 0, 0, 0, 0, 0, 0]);
  });

  it("Should not allow reentrancy during mint", async () => {
    // Set a public drop with maxTotalMintableByWallet: 1
    // and restrictFeeRecipient: false
    const oneEther = parseEther("1");
    await configurer.updatePublicDrop(token.address, {
      ...publicDrop,
      startPrice: oneEther,
      endPrice: oneEther,
      maxTotalMintableByWallet: 1,
      restrictFeeRecipients: false,
    });

    const MaliciousRecipientFactory = await ethers.getContractFactory(
      "MaliciousRecipient",
      owner
    );
    const maliciousRecipient = await MaliciousRecipientFactory.deploy();

    // Set the creator address to MaliciousRecipient.
    await configurer
      .connect(owner)
      .updateCreatorPayouts(token.address, [
        { payoutAddress: maliciousRecipient.address, basisPoints: 10_000 },
      ]);

    // Should not be able to mint with reentrancy.
    await maliciousRecipient.setStartAttack({ value: oneEther.mul(10) });
    await expect(
      maliciousRecipient.attack(marketplaceContract.address, token.address)
    ).to.be.revertedWithCustomError(marketplaceContract, "NoReentrantCalls");
    expect(await token.totalSupply()).to.eq(0);
  });

  it("Should allow multiple creator payout addresses", async () => {
    // Valid cases
    await expect(
      configurer.updateCreatorPayouts(token.address, [
        { payoutAddress: creator.address, basisPoints: 10_000 },
      ])
    ).to.emit(token, "CreatorPayoutsUpdated");
    // .withArgs([[creator.address, 10_000]]);
    expect(await configurer.getCreatorPayouts(token.address)).to.deep.eq([
      [creator.address, 10_000],
    ]);

    await expect(
      configurer.updateCreatorPayouts(token.address, [
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
    expect(await configurer.getCreatorPayouts(token.address)).to.deep.eq([
      [creator.address, 5_000],
      [owner.address, 5_000],
    ]);

    await expect(
      configurer.updateCreatorPayouts(token.address, [
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
    expect(await configurer.getCreatorPayouts(token.address)).to.deep.eq([
      [creator.address, 9_000],
      [owner.address, 500],
      [minter.address, 500],
    ]);

    await expect(
      configurer.updateCreatorPayouts(token.address, [
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
    expect(await configurer.getCreatorPayouts(token.address)).to.deep.eq([
      [creator.address, 100],
      [owner.address, 100],
      [minter.address, 9_800],
    ]);

    await expect(
      configurer.updateCreatorPayouts(token.address, [
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
    expect(await configurer.getCreatorPayouts(token.address)).to.deep.eq([
      [creator.address, 1_000],
      [owner.address, 1_000],
      [minter.address, 1_000],
      [creator.address, 1_000],
      [owner.address, 1_000],
      [minter.address, 5_000],
    ]);

    // Invalid cases
    await expect(
      configurer.updateCreatorPayouts(token.address, [
        { payoutAddress: creator.address, basisPoints: 100 },
        { payoutAddress: owner.address, basisPoints: 100 },
        { payoutAddress: minter.address, basisPoints: 9_700 },
        { payoutAddress: AddressZero, basisPoints: 100 },
      ])
    ).to.be.revertedWithCustomError(
      token,
      "CreatorPayoutAddressCannotBeZeroAddress"
    );

    await expect(
      configurer.updateCreatorPayouts(token.address, [
        { payoutAddress: creator.address, basisPoints: 100 },
        { payoutAddress: owner.address, basisPoints: 0 },
        { payoutAddress: minter.address, basisPoints: 9_900 },
      ])
    ).to.be.revertedWithCustomError(
      token,
      "CreatorPayoutBasisPointsCannotBeZero"
    );

    await expect(
      configurer.updateCreatorPayouts(token.address, [
        { payoutAddress: creator.address, basisPoints: 100 },
        { payoutAddress: owner.address, basisPoints: 10 },
        { payoutAddress: minter.address, basisPoints: 1 },
      ])
    ).to.be.revertedWithCustomError(
      token,
      "InvalidCreatorPayoutTotalBasisPoints"
    );
    await expect(
      configurer.updateCreatorPayouts(token.address, [
        { payoutAddress: creator.address, basisPoints: 10_001 },
      ])
    ).to.be.revertedWithCustomError(
      token,
      "InvalidCreatorPayoutTotalBasisPoints"
    );
    await expect(
      configurer.updateCreatorPayouts(token.address, [
        { payoutAddress: creator.address, basisPoints: 9_998 },
        { payoutAddress: owner.address, basisPoints: 1 },
      ])
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
    await configurer.updatePublicDrop(
      token.address,
      publicDropERC20PaymentToken
    );

    const { order, value } = await createMintOrder({
      token,
      configurer,
      quantity: 1,
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
    ).to.be.revertedWithPanic(0x11);

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
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // quantity
        publicDrop.startPrice,
        paymentToken.address,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
      );

    // Confirm the payment token was transferred and user has no balance left.
    expect(await paymentToken.balanceOf(minter.address)).to.eq(0);
    const feeAmount = value.mul(publicDrop.feeBps).div(10_000);
    const creatorAmount = value.sub(feeAmount);
    expect(await paymentToken.balanceOf(feeRecipient.address)).to.eq(feeAmount);
    expect(await paymentToken.balanceOf(creator.address)).to.eq(creatorAmount);

    // Now try with conduit
    // Mint one minus the needed amount of payment tokens to the minter.
    await paymentToken.mint(minter.address, value.sub(1));

    // Should fail if we have not approved the payment token.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], conduitKeyOne, AddressZero)
    ).to.be.revertedWithPanic(0x11);

    // Approve the payment token.
    await paymentToken.approve(marketplaceContract.address, value);

    // It should still fail as we have one minus the needed balance.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], conduitKeyOne, AddressZero)
    ).to.be.revertedWithPanic(0x11);

    // Mint one more payment token to the minter.
    await paymentToken.mint(minter.address, 1);

    // Now it should succeed.
    await expect(
      marketplaceContract
        .connect(minter)
        .fulfillAdvancedOrder(order, [], HashZero, AddressZero)
    )
      .to.emit(token, "SeaDropMint")
      .withArgs(
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        1, // quantity
        publicDrop.startPrice,
        paymentToken.address,
        publicDrop.feeBps,
        _PUBLIC_DROP_STAGE_INDEX
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

    const supportedSubstandards = [0, 1, 2, 3];
    const metadata = defaultAbiCoder.encode(
      ["uint256[]"],
      [supportedSubstandards]
    );

    expect({
      name,
      schemas,
    }).to.deep.eq({
      name: "ERC721SeaDrop",
      schemas: [[BigNumber.from(12), metadata]],
    });
  });

  it("Should return errors for invalid encodings", async () => {
    const { order, value } = await createMintOrder({
      token,
      configurer,
      quantity: 1,
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
});
