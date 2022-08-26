import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { ERC721SeaDrop } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721ContractMetadata (v${VERSION})`, function () {
  const { provider } = ethers;
  let token: ERC721SeaDrop;
  let owner: Wallet;
  let admin: Wallet;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets
    owner = new ethers.Wallet(randomHex(32), provider);
    admin = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    await faucet(owner.address, provider);
    await faucet(admin.address, provider);

    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy("", "", admin.address, []);
  });

  it("Should only let the owner set and get the base URI", async () => {
    expect(await token.baseURI()).to.equal("");

    await expect(
      token.connect(admin).setBaseURI("http://example.com")
    ).to.be.revertedWith("OnlyOwner");
    expect(await token.baseURI()).to.equal("");

    await expect(token.connect(owner).setBaseURI("http://example.com"))
      .to.emit(token, "BaseURIUpdated")
      .withArgs("http://example.com");
    expect(await token.baseURI()).to.equal("http://example.com");
  });

  it("Should only let the owner set and get the contract URI", async () => {
    expect(await token.contractURI()).to.equal("");

    await expect(
      token.connect(admin).setContractURI("http://example.com")
    ).to.be.revertedWith("OnlyOwner");
    expect(await token.contractURI()).to.equal("");

    await expect(token.connect(owner).setContractURI("http://example.com"))
      .to.emit(token, "ContractURIUpdated")
      .withArgs("http://example.com");
    expect(await token.contractURI()).to.equal("http://example.com");
  });

  it("Should only let the owner set and get the max supply", async () => {
    expect(await token.maxSupply()).to.equal(0);

    await expect(token.connect(admin).setMaxSupply(5)).to.be.revertedWith(
      "OnlyOwner"
    );
    expect(await token.maxSupply()).to.equal(0);

    await expect(token.connect(owner).setMaxSupply(5))
      .to.emit(token, "MaxSupplyUpdated")
      .withArgs(5);
    expect(await token.maxSupply()).to.equal(5);
  });

  it("Should only let the owner notify update of batch token URIs", async () => {
    await expect(
      token.connect(admin).setBatchTokenURIs(5, 10)
    ).to.be.revertedWith("OnlyOwner");

    await expect(token.connect(owner).setBatchTokenURIs(5, 10))
      .to.emit(token, "TokenURIUpdated")
      .withArgs(5, 10);
  });
});
