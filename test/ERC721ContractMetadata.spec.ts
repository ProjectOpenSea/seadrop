import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION, deployERC721SeaDrop, mintTokens } from "./utils/helpers";

import type {
  ConsiderationInterface,
  ERC721SeaDrop,
  IERC721SeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

const { BigNumber } = ethers;
const { AddressZero, HashZero } = ethers.constants;

describe(`ERC721ContractMetadata (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
  let tokenSeaDropInterface: IERC721SeaDrop;

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
    ({ token, tokenSeaDropInterface } = await deployERC721SeaDrop(
      owner,
      marketplaceContract.address
    ));
  });

  it("Should only let the owner set and get the base URI", async () => {
    expect(await token.baseURI()).to.equal("");

    await expect(
      token.connect(bob).setBaseURI("http://example.com")
    ).to.be.revertedWithCustomError(token, "Unauthorized");
    expect(await token.baseURI()).to.equal("");

    // it should not emit BatchMetadataUpdate when totalSupply is 0
    await expect(token.setBaseURI("http://example.com")).to.not.emit(
      token,
      "BatchMetadataUpdate"
    );

    // it should emit BatchMetadataUpdate when totalSupply is greater than 0
    await token.setMaxSupply(1);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter: owner,
      quantity: 1,
    });
    await expect(token.setBaseURI("http://example.com"))
      .to.emit(token, "BatchMetadataUpdate")
      .withArgs(1, await token.totalSupply());
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
    expect(await token.maxSupply()).to.equal(0);

    await expect(
      token.connect(bob).setMaxSupply(10)
    ).to.be.revertedWithCustomError(token, "Unauthorized");
    expect(await token.maxSupply()).to.equal(0);

    await expect(token.setMaxSupply(25))
      .to.emit(token, "MaxSupplyUpdated")
      .withArgs(25);
    expect(await token.maxSupply()).to.equal(25);
  });

  it("Should not let the owner set the max supply over 2**64", async () => {
    await expect(token.setMaxSupply(BigNumber.from(2).pow(70)))
      .to.be.revertedWithCustomError(token, "CannotExceedMaxSupplyOfUint64")
      .withArgs(BigNumber.from(2).pow(70));
  });

  it("Should only let the owner notify update of batch token URIs", async () => {
    await expect(
      token.connect(bob).emitBatchMetadataUpdate(5, 10)
    ).to.be.revertedWithCustomError(token, "Unauthorized");

    await expect(token.emitBatchMetadataUpdate(5, 10))
      .to.emit(token, "BatchMetadataUpdate")
      .withArgs(5, 10);
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

  it("Should return the correct tokenURI based on baseURI's last character", async () => {
    await token.setMaxSupply(2);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter: owner,
      quantity: 2,
    });

    // Revert on nonexistent token
    await expect(token.tokenURI(99)).to.be.revertedWithCustomError(
      token,
      "URIQueryForNonexistentToken"
    );

    // If the baseURI is empty then the tokenURI should be empty
    await expect(token.setBaseURI("")).to.emit(token, "BatchMetadataUpdate");
    expect(await token.baseURI()).to.equal("");
    expect(await token.tokenURI(1)).to.equal("");
    await expect(token.tokenURI(15)).to.be.revertedWithCustomError(
      token,
      "URIQueryForNonexistentToken"
    );

    // If the baseURI ends with "/" then the tokenURI should be baseURI + tokenId
    await expect(token.setBaseURI("http://example.com/")).to.emit(
      token,
      "BatchMetadataUpdate"
    );

    expect(await token.baseURI()).to.equal("http://example.com/");
    expect(await token.tokenURI(1)).to.equal("http://example.com/1");
    expect(await token.tokenURI(2)).to.equal("http://example.com/2");

    // If the baseURI does not end with "/" then the tokenURI should just be baseURI
    await expect(token.setBaseURI("http://example.com")).to.emit(
      token,
      "BatchMetadataUpdate"
    );

    expect(await token.baseURI()).to.equal("http://example.com");
    expect(await token.tokenURI(1)).to.equal("http://example.com");
    expect(await token.tokenURI(2)).to.equal("http://example.com");
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

    // Provenance hash should not be updatable after the first token has minted.
    // Mint a token.
    await token.setMaxSupply(1);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter: owner,
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
