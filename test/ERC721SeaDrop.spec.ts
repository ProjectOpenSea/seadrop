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

import { seaportFixture } from "./seaport-utils/fixtures";
import { getInterfaceID, randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import {
  VERSION,
  mintTokens,
  setMintRecipientStorageSlot,
} from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";
import { MintType, createMintOrder } from "./utils/order";

import type { AwaitedObject } from "./utils/helpers";
import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDrop,
} from "../typechain-types";
import type { SeaDropStructsErrorsAndEvents } from "../typechain-types/src/shim/Shim";
import type { BigNumberish, Wallet } from "ethers";

type AllowListDataStruct = SeaDropStructsErrorsAndEvents.AllowListDataStruct;
type PublicDropStruct = SeaDropStructsErrorsAndEvents.PublicDropStruct;
type SignedMintValidationParamsStruct =
  SeaDropStructsErrorsAndEvents.SignedMintValidationParamsStruct;
type TokenGatedDropStageStruct =
  SeaDropStructsErrorsAndEvents.TokenGatedDropStageStruct;

const { BigNumber } = ethers;
const { AddressZero, HashZero } = ethers.constants;
const { parseEther } = ethers.utils;

describe(`ERC721SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
  let owner: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let publicDrop: AwaitedObject<PublicDropStruct>;
  let tokenGatedDropStage: AwaitedObject<TokenGatedDropStageStruct>;
  let signedMintValidationParams: AwaitedObject<SignedMintValidationParamsStruct>;
  let allowListData: AwaitedObject<AllowListDataStruct>;

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

    // Add eth to wallets
    for (const wallet of [owner, minter, creator]) {
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

    publicDrop = {
      startPrice: parseEther("0.1"),
      endPrice: parseEther("0.1"),
      paymentToken: AddressZero,
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
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
      minMintPrices: [{ paymentToken: AddressZero, minMintPrice: 10 }],
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
  });

  it("Should emit an event when the contract is deployed", async () => {
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    const tx = await ERC721SeaDrop.deploy(
      "",
      "",
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
    await token.connect(owner).updatePublicDrop(publicDrop);
    await token.setMaxSupply(5);

    const feeRecipient = new ethers.Wallet(randomHex(32), provider);
    await token.updateAllowedFeeRecipient(feeRecipient.address, true);

    const { order, value } = await createMintOrder({
      token,
      quantity: 1,
      feeRecipient,
      feeBps: publicDrop.feeBps,
      startPrice: publicDrop.startPrice,
      minter,
      mintType: MintType.PUBLIC,
    });

    await expect(
      marketplaceContract.fulfillAdvancedOrder(
        order,
        [],
        HashZero,
        AddressZero,
        { value }
      )
    )
      .to.be.revertedWithCustomError(
        marketplaceContract,
        "InvalidContractOrder"
      )
      .withArgs(token.address.toLowerCase().padEnd(66, "0"));
    // ERC721SeaDrop reverts with `CreatorPayoutAddressCannotBeZeroAddress`,
    // but Seaport reverts with `InvalidContractOrder`

    await token.updateAllowedFeeRecipient(feeRecipient.address, false);
  });

  it("Should only let the token owner update the drop URI", async () => {
    await expect(
      token.connect(creator).updateDropURI("http://test.com")
    ).to.revertedWithCustomError(token, "OnlyOwner");

    await expect(token.connect(owner).updateDropURI("http://test.com"))
      .to.emit(token, "DropURIUpdated")
      .withArgs("http://test.com");
  });

  it("Should only let the owner update the allowed fee recipients", async () => {
    const feeRecipient = new ethers.Wallet(randomHex(32), provider);

    expect(await token.getAllowedFeeRecipients()).to.deep.eq([]);

    await expect(
      token.updateAllowedFeeRecipient(AddressZero, true)
    ).to.be.revertedWithCustomError(token, "FeeRecipientCannotBeZeroAddress");

    await expect(token.updateAllowedFeeRecipient(feeRecipient.address, true))
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, true);

    await expect(
      token.updateAllowedFeeRecipient(feeRecipient.address, true)
    ).to.be.revertedWithCustomError(token, "DuplicateFeeRecipient");

    expect(await token.getAllowedFeeRecipients()).to.deep.eq([
      feeRecipient.address,
    ]);

    // Now let's disallow the feeRecipient
    await expect(token.updateAllowedFeeRecipient(feeRecipient.address, false))
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, false);

    expect(await token.getAllowedFeeRecipients()).to.deep.eq([]);

    await expect(
      token.updateAllowedFeeRecipient(feeRecipient.address, false)
    ).to.be.revertedWithCustomError(token, "FeeRecipientNotPresent");
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

    await expect(token.connect(owner).setProvenanceHash(firstProvenanceHash))
      .to.emit(token, "ProvenanceHashUpdated")
      .withArgs(defaultProvenanceHash, firstProvenanceHash);

    // Provenance hash should not be updatable after the first token has minted.
    // Mint a token.
    await mintTokens({
      marketplaceContract,
      provider,
      token,
      minter,
      quantity: 1,
    });

    await expect(
      token.connect(owner).setProvenanceHash(secondProvenanceHash)
    ).to.be.revertedWithCustomError(
      token,
      "ProvenanceHashCannotBeSetAfterMintStarted"
    );

    expect(await token.provenanceHash()).to.equal(firstProvenanceHash);
  });

  it("Should only let allowed seaport or conduit call the ERC1155 safeTransferFrom", async () => {
    await token.setMaxSupply(3);

    await setMintRecipientStorageSlot(provider, token, minter);
    await whileImpersonating(
      marketplaceContract.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          token
            .connect(impersonatedSigner)
            ["safeTransferFrom(address,address,uint256,uint256,bytes)"](
              token.address,
              minter.address,
              0,
              1,
              []
            )
        )
          .to.emit(token, "Transfer")
          .withArgs(AddressZero, minter.address, 1);
      }
    );

    // Mint as conduit
    await setMintRecipientStorageSlot(provider, token, minter);
    await whileImpersonating(
      conduitOne.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          token
            .connect(impersonatedSigner)
            ["safeTransferFrom(address,address,uint256,uint256,bytes)"](
              token.address,
              minter.address,
              0,
              1,
              []
            )
        )
          .to.emit(token, "Transfer")
          .withArgs(AddressZero, minter.address, 2);
      }
    );

    // Mint as owner
    await setMintRecipientStorageSlot(provider, token, minter);
    await expect(
      token
        .connect(owner)
        ["safeTransferFrom(address,address,uint256,uint256,bytes)"](
          token.address,
          minter.address,
          0,
          1,
          []
        )
    )
      .to.be.revertedWithCustomError(
        token,
        "InvalidCallerOnlyAllowedSeaportOrConduit"
      )
      .withArgs(owner.address);
  });

  it("Should return supportsInterface true for supported interfaces", async () => {
    const supportedInterfacesERC721SeaDrop = [
      [
        INonFungibleSeaDropToken__factory,
        ISeaDropTokenContractMetadata__factory,
        ContractOffererInterface__factory,
      ],
      [IERC165__factory],
    ];
    const supportedInterfacesERC721ContractMetadata = [
      [ISeaDropTokenContractMetadata__factory, IERC2981__factory],
      [IERC2981__factory, IERC165__factory],
    ];
    const supportedInterfacesERC721A = [
      [IERC721__factory, IERC165__factory],
      [IERC165__factory],
    ];

    for (const factories of [
      ...supportedInterfacesERC721SeaDrop,
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

    // Ensure the interface for ERC721Metadata (from ERC721A) returns true.
    expect(await token.supportsInterface("0x5b5e139f")).to.be.true;

    // Ensure the interface for ERC-4906 returns true.
    expect(await token.supportsInterface("0x49064906")).to.be.true;

    // Ensure invalid interfaces return false.
    const invalidInterfaceIds = ["0x00000000", "0x10000000", "0x00000001"];
    for (const interfaceId of invalidInterfaceIds) {
      expect(await token.supportsInterface(interfaceId)).to.be.false;
    }
  });

  it("Should only let the token owner update the allowed Seaport addresses", async () => {
    await expect(
      token.connect(creator).updateAllowedSeaport([marketplaceContract.address])
    ).to.revertedWithCustomError(token, "OnlyOwner");

    await expect(
      token.connect(minter).updateAllowedSeaport([marketplaceContract.address])
    ).to.revertedWithCustomError(token, "OnlyOwner");

    await expect(token.updateAllowedSeaport([marketplaceContract.address]))
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address]);

    const address1 = `0x${"1".repeat(40)}`;
    const address2 = `0x${"2".repeat(40)}`;
    const address3 = `0x${"3".repeat(40)}`;

    await expect(
      token.updateAllowedSeaport([marketplaceContract.address, address1])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([marketplaceContract.address, address1]);

    await expect(token.updateAllowedSeaport([address2]))
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([address2]);

    await expect(
      token.updateAllowedSeaport([
        address3,
        marketplaceContract.address,
        address2,
        address1,
      ])
    )
      .to.emit(token, "AllowedSeaportUpdated")
      .withArgs([address3, marketplaceContract.address, address2, address1]);

    await expect(token.updateAllowedSeaport([marketplaceContract.address]))
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
    await token.updateAllowList(allowListData);

    await expect(
      token.connect(creator).updateAllowList(allowListData)
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Test `updateTokenGatedDrop` for coverage.

    await token.updateTokenGatedDrop(
      `0x${"4".repeat(40)}`,
      tokenGatedDropStage
    );

    await expect(
      token
        .connect(creator)
        .updateTokenGatedDrop(`0x${"4".repeat(40)}`, tokenGatedDropStage)
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Test `updateSigner` for coverage.
    await token.updateSignedMintValidationParams(
      `0x${"5".repeat(40)}`,
      signedMintValidationParams
    );

    await expect(
      token
        .connect(creator)
        .updateSignedMintValidationParams(
          `0x${"5".repeat(40)}`,
          signedMintValidationParams
        )
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Test `updatePayer` for coverage.
    await token.updatePayer(`0x${"6".repeat(40)}`, true);

    await expect(
      token
        .connect(creator)
        .updateSignedMintValidationParams(
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
      token.updatePayer(payer.address, false)
    ).to.be.revertedWithCustomError(token, "PayerNotPresent");

    await token.updatePayer(payer.address, true);

    // Ensure that the same payer cannot be added twice.
    await expect(
      token.updatePayer(payer.address, true)
    ).to.be.revertedWithCustomError(token, "DuplicatePayer");

    // Ensure that the zero address cannot be added as a payer.
    await expect(
      token.updatePayer(AddressZero, true)
    ).to.be.revertedWithCustomError(token, "PayerCannotBeZeroAddress");

    // Remove the original payer for branch coverage.
    await token.updatePayer(payer.address, false);
    expect(await token.getPayers()).to.deep.eq([]);

    // Add two signers and remove the second for branch coverage.
    await token.updatePayer(payer.address, true);
    await token.updatePayer(payer2.address, true);
    await token.updatePayer(payer2.address, false);
    expect(await token.getPayers()).to.deep.eq([payer.address]);
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
      await (token as any).connect(owner)[method](...methodParams[method]);

      await expect(
        (token as any).connect(creator)[method](...methodParams[method])
      ).to.be.revertedWithCustomError(token, "OnlyOwner");
    }
  });

  it("Should be able to transfer successfully", async () => {
    await mintTokens({
      marketplaceContract,
      provider,
      token,
      minter,
      quantity: 5,
    });

    await token
      .connect(minter)
      .transferFrom(minter.address, creator.address, 1);
    await token
      .connect(minter)
      ["safeTransferFrom(address,address,uint256)"](
        minter.address,
        creator.address,
        2
      );
    await token
      .connect(minter)
      ["safeTransferFrom(address,address,uint256,bytes)"](
        minter.address,
        creator.address,
        3,
        Buffer.from("dadb0d", "hex")
      );
    expect(await token.balanceOf(creator.address)).to.eq(3);

    await token.connect(minter).setApprovalForAll(creator.address, true);
    await token.connect(minter).approve(creator.address, 4);
  });

  it("Should be able to use the multiConfigure method", async () => {
    const feeRecipient = new ethers.Wallet(randomHex(32), provider);
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
          startPrice: tokenGatedDropStage.startPrice + "1",
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
    };

    await expect(
      token.connect(creator).multiConfigure(config)
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    // Should revert if tokenGatedAllowedNftToken.length != tokenGatedDropStages.length
    await expect(
      token.connect(owner).multiConfigure({
        ...config,
        tokenGatedAllowedNftTokens: config.tokenGatedAllowedNftTokens.slice(1),
      })
    ).to.be.revertedWithCustomError(token, "TokenGatedMismatch");

    // Should revert if signers.length != signedMintValidationParams.length
    await expect(
      token.connect(owner).multiConfigure({
        ...config,
        signers: config.signers.slice(1),
      })
    ).to.be.revertedWithCustomError(token, "SignersMismatch");

    await expect(token.connect(owner).multiConfigure(config))
      .to.emit(token, "DropURIUpdated")
      .withArgs("https://example3.com");

    const checkResults = async () => {
      expect(await token.maxSupply()).to.eq(100);
      expect(await token.baseURI()).to.eq("https://example1.com");
      expect(await token.contractURI()).to.eq("https://example2.com");
      expect(await token.getPublicDrop()).to.deep.eq([
        publicDrop.startPrice,
        publicDrop.endPrice,
        publicDrop.paymentToken,
        publicDrop.startTime,
        publicDrop.endTime,
        publicDrop.maxTotalMintableByWallet,
        publicDrop.feeBps,
        publicDrop.restrictFeeRecipients,
      ]);
      expect(await token.getAllowListMerkleRoot()).to.eq(
        allowListData.merkleRoot
      );
      expect(await token.getCreatorPayouts()).to.deep.eq([
        [creator.address, 10_000],
      ]);
      expect(await token.getAllowedFeeRecipients()).to.deep.eq([
        feeRecipient.address,
      ]);
      expect(await token.getPayers()).to.deep.eq(config.allowedPayers);
      expect(await token.provenanceHash()).to.eq(`0x${"3".repeat(64)}`);
      expect(await token.getTokenGatedAllowedTokens()).to.deep.eq(
        config.tokenGatedAllowedNftTokens
      );
      for (const [i, allowed] of config.tokenGatedAllowedNftTokens.entries()) {
        expect(await token.getTokenGatedDrop(allowed)).to.deep.eq([
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
      expect(await token.getSigners()).to.deep.eq(config.signers);
      for (const [i, signer] of config.signers.entries()) {
        expect(await token.getSignedMintValidationParams(signer)).to.deep.eq([
          [
            [
              config.signedMintValidationParams[i].minMintPrices[0]
                .paymentToken,
              BigNumber.from(
                config.signedMintValidationParams[i].minMintPrices[0]
                  .minMintPrice as BigNumberish
              ),
            ],
          ],
          config.signedMintValidationParams[i].maxMaxTotalMintableByWallet,
          config.signedMintValidationParams[i].minStartTime,
          config.signedMintValidationParams[i].maxEndTime,
          config.signedMintValidationParams[i].maxMaxTokenSupplyForStage,
          config.signedMintValidationParams[i].minFeeBps,
          config.signedMintValidationParams[i].maxFeeBps,
        ]);
      }
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
    };
    await expect(token.connect(owner).multiConfigure(zeroedConfig)).to.not.emit(
      token,
      "DropURIUpdated"
    );
    await checkResults();

    // Should unset properties
    await expect(
      token.connect(owner).multiConfigure({
        ...zeroedConfig,
        disallowedFeeRecipients: config.allowedFeeRecipients,
      })
    )
      .to.emit(token, "AllowedFeeRecipientUpdated")
      .withArgs(feeRecipient.address, false);
    await expect(
      token.connect(owner).multiConfigure({
        ...zeroedConfig,
        disallowedPayers: config.allowedPayers,
      })
    )
      .to.emit(token, "PayerUpdated")
      .withArgs(config.allowedPayers[0], false);
    await expect(
      token.connect(owner).multiConfigure({
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
      token.connect(owner).multiConfigure({
        ...zeroedConfig,
        disallowedSigners: [config.signers[0]],
      })
    ).to.emit(token, "SignedMintValidationParamsUpdated");
    // .withArgs(config.signers[0], [[], 0, 0, 0, 0, 0, 0]);
    // Can uncomment the line above once this is fixed:
    // https://github.com/NomicFoundation/hardhat/issues/3080#issuecomment-1496878645
  });

  it("Should not allow reentrancy during mint", async () => {
    // Set a public drop with maxTotalMintableByWallet: 1
    // and restrictFeeRecipient: false
    await token.setMaxSupply(10);
    const oneEther = parseEther("1");
    await token.connect(owner).updatePublicDrop({
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
    await token
      .connect(owner)
      .updateCreatorPayouts([
        { payoutAddress: maliciousRecipient.address, basisPoints: 10_000 },
      ]);

    // Should not be able to mint with reentrancy.
    await maliciousRecipient.setStartAttack({ value: oneEther.mul(10) });
    await expect(
      maliciousRecipient.attack(marketplaceContract.address, token.address)
    ).to.be.revertedWithCustomError(marketplaceContract, "NoReentrantCalls");
    expect(await token.totalSupply()).to.eq(0);
  });

  it("Should only let the token owner burn their own token", async () => {
    await token.setMaxSupply(3);

    // Mint 3 tokens to the minter.
    await mintTokens({
      marketplaceContract,
      provider,
      token,
      minter,
      quantity: 3,
    });

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.ownerOf(2)).to.equal(minter.address);
    expect(await token.ownerOf(3)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(3);

    // Only the owner or approved of the minted token should be able to burn it.
    await expect(token.connect(owner).burn(1)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );
    await expect(token.connect(creator).burn(1)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );
    await expect(token.connect(creator).burn(2)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );
    await expect(token.connect(creator).burn(3)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.ownerOf(2)).to.equal(minter.address);
    expect(await token.ownerOf(3)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(3);

    await token.connect(minter).burn(1);

    expect(await token.totalSupply()).to.equal(2);

    await token.connect(minter).setApprovalForAll(creator.address, true);
    await token.connect(creator).burn(2);

    expect(await token.totalSupply()).to.equal(1);

    await token.connect(minter).setApprovalForAll(creator.address, false);
    await expect(token.connect(creator).burn(3)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );

    await token.connect(minter).approve(owner.address, 3);
    await token.connect(owner).burn(3);

    expect(await token.totalSupply()).to.equal(0);

    await expect(token.ownerOf(1)).to.be.revertedWithCustomError(
      token,
      "OwnerQueryForNonexistentToken"
    );
    await expect(token.ownerOf(2)).to.be.revertedWithCustomError(
      token,
      "OwnerQueryForNonexistentToken"
    );
    expect(await token.totalSupply()).to.equal(0);

    // Should not be able to burn a nonexistent token.
    for (const tokenId of [0, 1, 2, 3]) {
      await expect(
        token.connect(minter).burn(tokenId)
      ).to.be.revertedWithCustomError(token, "OwnerQueryForNonexistentToken");
    }
  });
});
