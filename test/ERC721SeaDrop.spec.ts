import { expect } from "chai";
import { ethers, network } from "hardhat";

import {
  IERC165__factory,
  IERC2981__factory,
  IERC721__factory,
  INonFungibleRaribleDropToken__factory,
  IRaribleDropTokenContractMetadata__factory,
} from "../typechain-types";

import { getInterfaceID, randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721RaribleDrop, IRaribleDrop } from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/ERC721PartnerRaribleDrop";
import type { Wallet } from "ethers";

describe(`ERC721RaribleDrop (v${VERSION})`, function () {
  const { provider } = ethers;
  let raribleDrop: IRaribleDrop;
  let token: ERC721RaribleDrop;
  let owner: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let publicDrop: PublicDropStruct;

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

    // Deploy RaribleDrop
    const RaribleDrop = await ethers.getContractFactory("RaribleDrop", owner);
    raribleDrop = await RaribleDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721RaribleDrop = await ethers.getContractFactory(
      "ERC721RaribleDrop",
      owner
    );
    token = await ERC721RaribleDrop.deploy("", "", [raribleDrop.address]);

    publicDrop = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };
  });

  it("Should emit an event when the contract is deployed", async () => {
    const ERC721RaribleDrop = await ethers.getContractFactory(
      "ERC721RaribleDrop",
      owner
    );
    const tx = await ERC721RaribleDrop.deploy("", "", [raribleDrop.address]);
    const receipt = await tx.deployTransaction.wait();
    const event = (receipt as any).events.filter(
      ({ event }: any) => event === "RaribleDropTokenDeployed"
    );
    expect(event).to.not.be.null;
  });

  it("Should not be able to mint until the creator address is updated to non-zero", async () => {
    await token.connect(owner).updatePublicDrop(raribleDrop.address, publicDrop);
    await token.setMaxSupply(5);

    const feeRecipient = new ethers.Wallet(randomHex(32), provider);
    await token.updateAllowedFeeRecipient(
      raribleDrop.address,
      feeRecipient.address,
      true
    );

    await expect(
      raribleDrop.mintPublic(
        token.address,
        feeRecipient.address,
        ethers.constants.AddressZero,
        1,
        { value: publicDrop.mintPrice }
      )
    ).to.be.revertedWith("CreatorPayoutAddressCannotBeZeroAddress");

    await token.updateAllowedFeeRecipient(
      raribleDrop.address,
      feeRecipient.address,
      false
    );
  });

  it("Should only let the token owner update the drop URI", async () => {
    await expect(
      token.connect(creator).updateDropURI(raribleDrop.address, "http://test.com")
    ).to.revertedWith("OnlyOwner");

    await expect(
      token.connect(owner).updateDropURI(raribleDrop.address, "http://test.com")
    )
      .to.emit(raribleDrop, "DropURIUpdated")
      .withArgs(token.address, "http://test.com");
  });

  it("Should only let the owner update the allowed fee recipients", async () => {
    const feeRecipient = new ethers.Wallet(randomHex(32), provider);

    expect(await raribleDrop.getAllowedFeeRecipients(token.address)).to.deep.eq([]);

    expect(
      await raribleDrop.getFeeRecipientIsAllowed(
        token.address,
        feeRecipient.address
      )
    ).to.be.false;

    await expect(
      token.updateAllowedFeeRecipient(
        raribleDrop.address,
        ethers.constants.AddressZero,
        true
      )
    ).to.be.revertedWith("FeeRecipientCannotBeZeroAddress");

    await expect(
      token.updateAllowedFeeRecipient(
        raribleDrop.address,
        feeRecipient.address,
        true
      )
    )
      .to.emit(raribleDrop, "AllowedFeeRecipientUpdated")
      .withArgs(token.address, feeRecipient.address, true);

    await expect(
      token.updateAllowedFeeRecipient(
        raribleDrop.address,
        feeRecipient.address,
        true
      )
    ).to.be.revertedWith("DuplicateFeeRecipient");

    expect(await raribleDrop.getAllowedFeeRecipients(token.address)).to.deep.eq([
      feeRecipient.address,
    ]);

    expect(
      await raribleDrop.getFeeRecipientIsAllowed(
        token.address,
        feeRecipient.address
      )
    ).to.be.true;

    // Now let's disallow the feeRecipient
    await expect(
      token.updateAllowedFeeRecipient(
        raribleDrop.address,
        feeRecipient.address,
        false
      )
    )
      .to.emit(raribleDrop, "AllowedFeeRecipientUpdated")
      .withArgs(token.address, feeRecipient.address, false);

    expect(await raribleDrop.getAllowedFeeRecipients(token.address)).to.deep.eq([]);

    expect(
      await raribleDrop.getFeeRecipientIsAllowed(
        token.address,
        feeRecipient.address
      )
    ).to.be.false;

    await expect(
      token.updateAllowedFeeRecipient(
        raribleDrop.address,
        feeRecipient.address,
        false
      )
    ).to.be.revertedWith("FeeRecipientNotPresent");
  });

  it("Should only let the owner set the provenance hash", async () => {
    await token.setMaxSupply(1);
    expect(await token.provenanceHash()).to.equal(ethers.constants.HashZero);

    const defaultProvenanceHash = `0x${"0".repeat(64)}`;
    const firstProvenanceHash = `0x${"1".repeat(64)}`;
    const secondProvenanceHash = `0x${"2".repeat(64)}`;

    await expect(
      token.connect(creator).setProvenanceHash(firstProvenanceHash)
    ).to.revertedWith("OnlyOwner");

    await expect(token.connect(owner).setProvenanceHash(firstProvenanceHash))
      .to.emit(token, "ProvenanceHashUpdated")
      .withArgs(defaultProvenanceHash, firstProvenanceHash);

    // Provenance hash should not be updatable after the first token has minted.
    // Mint a token.
    await whileImpersonating(
      raribleDrop.address,
      provider,
      async (impersonatedSigner) => {
        await token.connect(impersonatedSigner).mintRaribleDrop(minter.address, 1);
      }
    );

    await expect(
      token.connect(owner).setProvenanceHash(secondProvenanceHash)
    ).to.be.revertedWith("ProvenanceHashCannotBeSetAfterMintStarted");

    expect(await token.provenanceHash()).to.equal(firstProvenanceHash);
  });

  it("Should only let allowed raribleDrop call seaDropMint", async () => {
    await token.setMaxSupply(1);

    await whileImpersonating(
      raribleDrop.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          token.connect(impersonatedSigner).mintRaribleDrop(minter.address, 1)
        )
          .to.emit(token, "Transfer")
          .withArgs(ethers.constants.AddressZero, minter.address, 1);

        await expect(
          token.connect(impersonatedSigner).mintRaribleDrop(minter.address, 1)
        ).to.be.revertedWith("MintQuantityExceedsMaxSupply(2, 1)");
      }
    );

    await expect(
      token.connect(owner).mintRaribleDrop(minter.address, 1)
    ).to.be.revertedWith("OnlyAllowedRaribleDrop");
  });

  it("Should return supportsInterface true for supported interfaces", async () => {
    const supportedInterfacesERC721RaribleDrop = [
      [
        INonFungibleRaribleDropToken__factory,
        IRaribleDropTokenContractMetadata__factory,
      ],
      [IERC165__factory],
    ];
    const supportedInterfacesERC721ContractMetadata = [
      [IRaribleDropTokenContractMetadata__factory, IERC2981__factory],
      [IERC2981__factory, IERC165__factory],
    ];
    const supportedInterfacesERC721A = [
      [IERC721__factory, IERC165__factory],
      [IERC165__factory],
    ];

    for (const factories of [
      ...supportedInterfacesERC721RaribleDrop,
      ...supportedInterfacesERC721ContractMetadata,
      ...supportedInterfacesERC721A,
    ]) {
      const interfaceId = factories
        .map((factory) => getInterfaceID(factory.createInterface()))
        .reduce((prev, curr) => prev.xor(curr))
        .toHexString();
      expect(await token.supportsInterface(interfaceId)).to.be.true;
    }

    // Ensure the interface that RaribleDrop 1.0 strictly checks for
    // in the modifier `onlyINonFungibleRaribleDropToken` returns true,
    // otherwise the contract will not be able to interact with RaribleDrop 1.0.
    expect(await token.supportsInterface("0x1890fe8e")).to.be.true;

    // Ensure the interface for ERC-4906 returns true.
    expect(await token.supportsInterface("0x49064906")).to.be.true;

    // Ensure invalid interfaces return false.
    const invalidInterfaceIds = ["0x00000000", "0x10000000", "0x00000001"];
    for (const interfaceId of invalidInterfaceIds) {
      expect(await token.supportsInterface(interfaceId)).to.be.false;
    }
  });

  it("Should only let the token owner update the allowed RaribleDrop addresses", async () => {
    await expect(
      token.connect(creator).updateAllowedRaribleDrop([raribleDrop.address])
    ).to.revertedWith("OnlyOwner");

    await expect(
      token.connect(minter).updateAllowedRaribleDrop([raribleDrop.address])
    ).to.revertedWith("OnlyOwner");

    await expect(token.updateAllowedRaribleDrop([raribleDrop.address]))
      .to.emit(token, "AllowedRaribleDropUpdated")
      .withArgs([raribleDrop.address]);

    const address1 = `0x${"1".repeat(40)}`;
    const address2 = `0x${"2".repeat(40)}`;
    const address3 = `0x${"3".repeat(40)}`;

    await expect(token.updateAllowedRaribleDrop([raribleDrop.address, address1]))
      .to.emit(token, "AllowedRaribleDropUpdated")
      .withArgs([raribleDrop.address, address1]);

    await expect(token.updateAllowedRaribleDrop([address2]))
      .to.emit(token, "AllowedRaribleDropUpdated")
      .withArgs([address2]);

    await expect(
      token.updateAllowedRaribleDrop([
        address3,
        raribleDrop.address,
        address2,
        address1,
      ])
    )
      .to.emit(token, "AllowedRaribleDropUpdated")
      .withArgs([address3, raribleDrop.address, address2, address1]);

    await expect(token.updateAllowedRaribleDrop([raribleDrop.address]))
      .to.emit(token, "AllowedRaribleDropUpdated")
      .withArgs([raribleDrop.address]);
  });

  it("Should let the token owner use admin methods", async () => {
    // Test `updateAllowList` for coverage.
    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(raribleDrop.address, allowListData);

    await expect(
      token.connect(creator).updateAllowList(raribleDrop.address, allowListData)
    ).to.be.revertedWith("OnlyOwner");

    // Test `updateTokenGatedDrop` for coverage.
    const dropStage = {
      mintPrice: "10000000000000000", // 0.01 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 100,
      restrictFeeRecipients: true,
    };
    await token.updateTokenGatedDrop(
      raribleDrop.address,
      `0x${"4".repeat(40)}`,
      dropStage
    );

    await expect(
      token
        .connect(creator)
        .updateTokenGatedDrop(raribleDrop.address, `0x${"4".repeat(40)}`, dropStage)
    ).to.be.revertedWith("OnlyOwner");

    const signedMintValidationParams = {
      minMintPrice: 10,
      maxMaxTotalMintableByWallet: 5,
      minStartTime: 50,
      maxEndTime: 100,
      maxMaxTokenSupplyForStage: 100,
      minFeeBps: 5,
      maxFeeBps: 1000,
    };

    // Test `updateSigner` for coverage.
    await token.updateSignedMintValidationParams(
      raribleDrop.address,
      `0x${"5".repeat(40)}`,
      signedMintValidationParams
    );

    await expect(
      token
        .connect(creator)
        .updateSignedMintValidationParams(
          raribleDrop.address,
          `0x${"5".repeat(40)}`,
          signedMintValidationParams
        )
    ).to.be.revertedWith("OnlyOwner");

    // Test `updatePayer` for coverage.
    await token.updatePayer(raribleDrop.address, `0x${"6".repeat(40)}`, true);

    await expect(
      token
        .connect(creator)
        .updateSignedMintValidationParams(
          raribleDrop.address,
          `0x${"6".repeat(40)}`,
          signedMintValidationParams
        )
    ).to.be.revertedWith("OnlyOwner");
  });

  it("Should be able to update the allowed payers", async () => {
    const payer = new ethers.Wallet(randomHex(32), provider);
    const payer2 = new ethers.Wallet(randomHex(32), provider);
    await faucet(payer.address, provider);
    await faucet(payer2.address, provider);

    await expect(
      token.updatePayer(raribleDrop.address, payer.address, false)
    ).to.be.revertedWith("PayerNotPresent");

    await token.updatePayer(raribleDrop.address, payer.address, true);

    // Ensure that the same payer cannot be added twice.
    await expect(
      token.updatePayer(raribleDrop.address, payer.address, true)
    ).to.be.revertedWith("DuplicatePayer()");

    // Ensure that the zero address cannot be added as a payer.
    await expect(
      token.updatePayer(raribleDrop.address, ethers.constants.AddressZero, true)
    ).to.be.revertedWith("PayerCannotBeZeroAddress()");

    // Remove the original payer for branch coverage.
    await token.updatePayer(raribleDrop.address, payer.address, false);
    expect(await raribleDrop.getPayerIsAllowed(token.address, payer.address)).to.eq(
      false
    );

    // Add two signers and remove the second for branch coverage.
    await token.updatePayer(raribleDrop.address, payer.address, true);
    await token.updatePayer(raribleDrop.address, payer2.address, true);
    await token.updatePayer(raribleDrop.address, payer2.address, false);
    expect(await raribleDrop.getPayerIsAllowed(token.address, payer.address)).to.eq(
      true
    );
    expect(
      await raribleDrop.getPayerIsAllowed(token.address, payer2.address)
    ).to.eq(false);
  });

  it("Should only let the owner call update functions", async () => {
    const onlyOwnerMethods = [
      "updateAllowedRaribleDrop",
      "updatePublicDrop",
      "updateAllowList",
      "updateTokenGatedDrop",
      "updateDropURI",
      "updateCreatorPayoutAddress",
      "updateAllowedFeeRecipient",
      "updateSignedMintValidationParams",
      "updatePayer",
    ];

    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };

    const dropStage = {
      mintPrice: "10000000000000000", // 0.01 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 100,
      restrictFeeRecipients: true,
    };

    const signedMintValidationParams = {
      minMintPrice: 10,
      maxMaxTotalMintableByWallet: 5,
      minStartTime: 50,
      maxEndTime: 100,
      maxMaxTokenSupplyForStage: 100,
      minFeeBps: 5,
      maxFeeBps: 1000,
    };

    const methodParams: any = {
      updateAllowedRaribleDrop: [[raribleDrop.address]],
      updatePublicDrop: [raribleDrop.address, publicDrop],
      updateAllowList: [raribleDrop.address, allowListData],
      updateTokenGatedDrop: [raribleDrop.address, `0x${"4".repeat(40)}`, dropStage],
      updateDropURI: [raribleDrop.address, "http://test.com"],
      updateCreatorPayoutAddress: [raribleDrop.address, `0x${"4".repeat(40)}`],
      updateAllowedFeeRecipient: [raribleDrop.address, `0x${"4".repeat(40)}`, true],
      updateSignedMintValidationParams: [
        raribleDrop.address,
        `0x${"4".repeat(40)}`,
        signedMintValidationParams,
      ],
      updatePayer: [raribleDrop.address, `0x${"4".repeat(40)}`, true],
    };

    const paramsWithNonRaribleDrop = (method: string) => [
      creator.address,
      ...methodParams[method].slice(1),
    ];

    for (const method of onlyOwnerMethods) {
      await (token as any).connect(owner)[method](...methodParams[method]);

      await expect(
        (token as any).connect(creator)[method](...methodParams[method])
      ).to.be.revertedWith("OnlyOwner()");

      if (method !== "updateAllowedRaribleDrop") {
        await expect(
          (token as any).connect(owner)[method](...paramsWithNonRaribleDrop(method))
        ).to.be.revertedWith("OnlyAllowedRaribleDrop()");
      }
    }
  });

  it("Should be able to transfer successfully", async () => {
    await token.connect(owner).updatePublicDrop(raribleDrop.address, publicDrop);
    await token.setMaxSupply(5);

    const feeRecipient = new ethers.Wallet(randomHex(32), provider);
    await token.updateAllowedFeeRecipient(
      raribleDrop.address,
      feeRecipient.address,
      true
    );
    await token.updateCreatorPayoutAddress(raribleDrop.address, creator.address);
    await raribleDrop
      .connect(minter)
      .mintPublic(
        token.address,
        feeRecipient.address,
        ethers.constants.AddressZero,
        5,
        { value: ethers.BigNumber.from(publicDrop.mintPrice).mul(5) }
      );

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
    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };
    const tokenGatedDropStage = {
      mintPrice: "10000000000000000", // 0.01 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 100,
      restrictFeeRecipients: true,
    };
    const signedMintValidationParams = {
      minMintPrice: 10,
      maxMaxTotalMintableByWallet: 5,
      minStartTime: 50,
      maxEndTime: 100,
      maxMaxTokenSupplyForStage: 100,
      minFeeBps: 5,
      maxFeeBps: 1000,
    };
    const config = {
      maxSupply: 100,
      baseURI: "https://example1.com",
      contractURI: "https://example2.com",
      seaDropImpl: raribleDrop.address,
      publicDrop,
      dropURI: "https://example3.com",
      allowListData,
      creatorPayoutAddress: creator.address,
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
          mintPrice: tokenGatedDropStage.mintPrice + "1",
        },
      ],
      disallowedTokenGatedAllowedNftTokens: [],
      signers: [`0x${"8".repeat(40)}`, `0x${"9".repeat(40)}`],
      signedMintValidationParams: [
        signedMintValidationParams,
        {
          ...signedMintValidationParams,
          minMintPrice: signedMintValidationParams.minMintPrice + 1,
        },
      ],
      disallowedSigners: [],
    };

    await expect(
      token.connect(creator).multiConfigure(config)
    ).to.be.revertedWith("OnlyOwner()");

    // Should revert if tokenGatedAllowedNftToken.length != tokenGatedDropStages.length
    await expect(
      token.connect(owner).multiConfigure({
        ...config,
        tokenGatedAllowedNftTokens: config.tokenGatedAllowedNftTokens.slice(1),
      })
    ).to.be.revertedWith("TokenGatedMismatch");

    // Should revert if signers.length != signedMintValidationParams.length
    await expect(
      token.connect(owner).multiConfigure({
        ...config,
        signers: config.signers.slice(1),
      })
    ).to.be.revertedWith("SignersMismatch");

    await expect(token.connect(owner).multiConfigure(config))
      .to.emit(raribleDrop, "DropURIUpdated")
      .withArgs(token.address, "https://example3.com");

    const checkResults = async () => {
      expect(await token.maxSupply()).to.eq(100);
      expect(await token.baseURI()).to.eq("https://example1.com");
      expect(await token.contractURI()).to.eq("https://example2.com");
      expect(await raribleDrop.getPublicDrop(token.address)).to.deep.eq([
        ethers.BigNumber.from(publicDrop.mintPrice),
        publicDrop.startTime,
        publicDrop.endTime,
        publicDrop.maxTotalMintableByWallet,
        publicDrop.feeBps,
        publicDrop.restrictFeeRecipients,
      ]);
      expect(await raribleDrop.getAllowListMerkleRoot(token.address)).to.eq(
        allowListData.merkleRoot
      );
      expect(await raribleDrop.getCreatorPayoutAddress(token.address)).to.eq(
        creator.address
      );
      expect(await raribleDrop.getAllowedFeeRecipients(token.address)).to.deep.eq([
        feeRecipient.address,
      ]);
      expect(await raribleDrop.getPayers(token.address)).to.deep.eq(
        config.allowedPayers
      );
      expect(await token.provenanceHash()).to.eq(`0x${"3".repeat(64)}`);
      expect(
        await raribleDrop.getTokenGatedAllowedTokens(token.address)
      ).to.deep.eq(config.tokenGatedAllowedNftTokens);
      for (const [i, allowed] of config.tokenGatedAllowedNftTokens.entries()) {
        expect(
          await raribleDrop.getTokenGatedDrop(token.address, allowed)
        ).to.deep.eq([
          ethers.BigNumber.from(config.tokenGatedDropStages[i].mintPrice),
          config.tokenGatedDropStages[i].maxTotalMintableByWallet,
          config.tokenGatedDropStages[i].startTime,
          config.tokenGatedDropStages[i].endTime,
          config.tokenGatedDropStages[i].dropStageIndex,
          config.tokenGatedDropStages[i].maxTokenSupplyForStage,
          config.tokenGatedDropStages[i].feeBps,
          config.tokenGatedDropStages[i].restrictFeeRecipients,
        ]);
      }
      expect(await raribleDrop.getSigners(token.address)).to.deep.eq(
        config.signers
      );
      for (const [i, signer] of config.signers.entries()) {
        expect(
          await raribleDrop.getSignedMintValidationParams(token.address, signer)
        ).to.deep.eq([
          ethers.BigNumber.from(
            config.signedMintValidationParams[i].minMintPrice
          ),
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
      seaDropImpl: raribleDrop.address,
      publicDrop: {
        mintPrice: 0,
        maxTotalMintableByWallet: 0,
        startTime: 0,
        endTime: 0,
        feeBps: 0,
        restrictFeeRecipients: true,
      },
      dropURI: "",
      allowListData: {
        merkleRoot: ethers.constants.HashZero,
        publicKeyURIs: [],
        allowListURI: "",
      },
      creatorPayoutAddress: ethers.constants.AddressZero,
      provenanceHash: ethers.constants.HashZero,
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
      raribleDrop,
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
      .to.emit(raribleDrop, "AllowedFeeRecipientUpdated")
      .withArgs(token.address, feeRecipient.address, false);
    await expect(
      token.connect(owner).multiConfigure({
        ...zeroedConfig,
        disallowedPayers: config.allowedPayers,
      })
    )
      .to.emit(raribleDrop, "PayerUpdated")
      .withArgs(token.address, config.allowedPayers[0], false);
    await expect(
      token.connect(owner).multiConfigure({
        ...zeroedConfig,
        disallowedTokenGatedAllowedNftTokens: [
          config.tokenGatedAllowedNftTokens[0],
        ],
      })
    )
      .to.emit(raribleDrop, "TokenGatedDropStageUpdated")
      .withArgs(token.address, config.tokenGatedAllowedNftTokens[0], [
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
    )
      .to.emit(raribleDrop, "SignedMintValidationParamsUpdated")
      .withArgs(token.address, config.signers[0], [0, 0, 0, 0, 0, 0, 0]);
  });
});
