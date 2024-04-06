import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION, deployERC1155SeaDrop, mintTokens } from "./utils/helpers";

import type {
  ConsiderationInterface,
  ERC1155SeaDrop,
  IERC1155SeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

const { BigNumber } = ethers;
const { AddressZero, HashZero } = ethers.constants;

describe(`ERC1155ContractMetadata (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;

  // SeaDrop
  let token: ERC1155SeaDrop;
  let tokenSeaDropInterface: IERC1155SeaDrop;

  // Wallets
  let owner: Wallet;
  let bob: Wallet;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets
    owner = new ethers.Wallet(randomHex(32), provider);
    bob = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, bob]) {
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
  });

  it("Should return the name and symbol", async () => {
    expect(await token.name()).to.equal("Test1155");
    expect(await token.symbol()).to.equal("T1155");
  });

  it("Should only let the owner set and get the base URI", async () => {
    expect(await token.baseURI()).to.equal("");

    await expect(
      token.connect(bob).setBaseURI("http://example.com")
    ).to.be.revertedWithCustomError(token, "Unauthorized");
    expect(await token.baseURI()).to.equal("");

    // it should emit BatchMetadataUpdate
    await token.setMaxSupply(1, 1);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter: owner,
      tokenId: 1,
      quantity: 1,
    });
    await expect(token.setBaseURI("http://example.com"))
      .to.emit(token, "BatchMetadataUpdate")
      .withArgs(0, BigNumber.from(2).pow(256).sub(1));
    expect(await token.baseURI()).to.equal("http://example.com");
  });

  it("Should only let the owner set and get the contract URI", async () => {
    expect(await token.contractURI()).to.equal("");

    await expect(
      token.connect(bob).setContractURI("http://example.com")
    ).to.be.revertedWithCustomError(token, "Unauthorized");
    expect(await token.contractURI()).to.equal("");

    await expect(token.setContractURI("http://example.com"))
      .to.emit(token, "ContractURIUpdated")
      .withArgs("http://example.com");
    expect(await token.contractURI()).to.equal("http://example.com");
  });

  it("Should only let the owner set and get the max supply", async () => {
    for (const tokenId of [0, 1, 2]) {
      expect(await token.maxSupply(tokenId)).to.equal(0);

      await expect(
        token.connect(bob).setMaxSupply(0, 10)
      ).to.be.revertedWithCustomError(token, "Unauthorized");
      expect(await token.maxSupply(tokenId)).to.equal(0);

      await expect(token.setMaxSupply(tokenId, 25))
        .to.emit(token, "MaxSupplyUpdated")
        .withArgs(tokenId, 25);
      expect(await token.maxSupply(tokenId)).to.equal(25);
    }
  });

  it("Should not let the owner set the max supply over 2**64", async () => {
    await expect(token.setMaxSupply(0, BigNumber.from(2).pow(70)))
      .to.be.revertedWithCustomError(token, "CannotExceedMaxSupplyOfUint64")
      .withArgs(BigNumber.from(2).pow(70));
  });

  it("Should not let the owner set the max supply over the totalMinted", async () => {
    await token.setMaxSupply(1, 3);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter: owner,
      tokenId: 1,
      quantity: 3,
    });
    expect(await token.totalSupply(1)).to.equal(3);

    await expect(token.setMaxSupply(1, 2))
      .to.be.revertedWithCustomError(
        token,
        "NewMaxSupplyCannotBeLessThenTotalMinted"
      )
      .withArgs(2, 3);
  });

  it("Should only let the owner notify update of batch token URIs", async () => {
    await expect(
      token.connect(bob).emitBatchMetadataUpdate(5, 10)
    ).to.be.revertedWithCustomError(token, "Unauthorized");

    await expect(token.emitBatchMetadataUpdate(5, 10))
      .to.emit(token, "BatchMetadataUpdate")
      .withArgs(5, 10);

    // Should emit URI() event from 1155 spec if only one token id
    await expect(token.emitBatchMetadataUpdate(0, 0))
      .to.emit(token, "URI")
      .withArgs("", 0);
    await expect(token.emitBatchMetadataUpdate(7, 7))
      .to.emit(token, "URI")
      .withArgs("", 7);
  });

  it("Should only let the owner update the royalties address and basis points", async () => {
    expect(await token.royaltyInfo(0, 100)).to.deep.equal([AddressZero, 0]);

    await expect(
      token.connect(bob).setDefaultRoyalty(owner.address, 100)
    ).to.be.revertedWithCustomError(token, "Unauthorized");

    await expect(
      token.setDefaultRoyalty(owner.address, 10_001)
    ).to.be.revertedWithCustomError(token, "RoyaltyOverflow");
    await expect(
      token.setDefaultRoyalty(AddressZero, 200)
    ).to.be.revertedWithCustomError(token, "RoyaltyReceiverIsZeroAddress");

    await expect(token.setDefaultRoyalty(bob.address, 100))
      .to.emit(token, "RoyaltyInfoUpdated")
      .withArgs(bob.address, 100);
    await expect(token.setDefaultRoyalty(bob.address, 500))
      .to.emit(token, "RoyaltyInfoUpdated")
      .withArgs(bob.address, 500);

    expect(await token.royaltyInfo(0, 100)).to.deep.equal([
      bob.address,
      BigNumber.from(5),
    ]);
    expect(await token.royaltyInfo(1, 100_000)).to.deep.equal([
      bob.address,
      BigNumber.from(5000),
    ]);

    // interface id for EIP-2981 is 0x2a55205a
    expect(await token.supportsInterface("0x2a55205a")).to.equal(true);
  });

  it("Should only let the owner set the provenance hash", async () => {
    expect(await token.provenanceHash()).to.equal(HashZero);

    const defaultProvenanceHash = `0x${"0".repeat(64)}`;
    const firstProvenanceHash = `0x${"1".repeat(64)}`;
    const secondProvenanceHash = `0x${"2".repeat(64)}`;

    await expect(
      token.connect(bob).setProvenanceHash(firstProvenanceHash)
    ).to.revertedWithCustomError(token, "Unauthorized");

    await expect(token.setProvenanceHash(firstProvenanceHash))
      .to.emit(token, "ProvenanceHashUpdated")
      .withArgs(defaultProvenanceHash, firstProvenanceHash);

    // Provenance hash should not be updatable after it has already been set.
    await expect(
      token.setProvenanceHash(secondProvenanceHash)
    ).to.be.revertedWithCustomError(
      token,
      "ProvenanceHashCannotBeSetAfterAlreadyBeingSet"
    );

    expect(await token.provenanceHash()).to.equal(firstProvenanceHash);
  });

  it("Should handle incrementing counts on batchMint", async () => {
    // Deploy token
    const ERC1155SeaDropWithBatchMint = await ethers.getContractFactory(
      "ERC1155SeaDropWithBatchMint",
      owner
    );
    const token = await ERC1155SeaDropWithBatchMint.deploy(
      AddressZero,
      marketplaceContract.address,
      "Test1155",
      "T1155"
    );
    await token.setMaxSupply(0, 1);
    await token.setMaxSupply(1, 1);

    expect(await token.totalMinted(0)).to.equal(0);
    expect(await token.totalMinted(1)).to.equal(0);

    await token.batchMint(owner.address, [0, 1], [1, 1], []);

    expect(await token.totalMinted(0)).to.equal(1);
    expect(await token.totalMinted(1)).to.equal(1);

    await expect(token.batchMint(owner.address, [0, 1], [1, 1], []))
      .to.be.revertedWithCustomError(token, "MintExceedsMaxSupply")
      .withArgs(2, 1);

    expect(await token.totalMinted(0)).to.equal(1);
    expect(await token.totalMinted(1)).to.equal(1);
  });
});
