import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { ERC721PartnerSeaDrop } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721ContractMetadata (v${VERSION})`, function () {
  const { provider } = ethers;
  let token: ERC721PartnerSeaDrop;
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
    for (const wallet of [owner, admin]) {
      await faucet(wallet.address, provider);
    }

    // Deploy token
    const ERC721PartnerSeaDrop = await ethers.getContractFactory(
      "ERC721PartnerSeaDrop",
      owner
    );
    token = await ERC721PartnerSeaDrop.deploy("", "", admin.address, []);
  });

  it("Should only let the owner set and get the base URI", async () => {
    expect(await token.baseURI()).to.equal("");

    await expect(
      token.connect(admin).setBaseURI("http://example.com")
    ).to.be.revertedWith("OnlyOwner");
    expect(await token.baseURI()).to.equal("");

    await expect(token.connect(owner).setBaseURI("http://example.com"))
      .to.emit(token, "BatchMetadataUpdate")
      .withArgs(0, await token.totalSupply());
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

  it("Should not let the owner set the max supply over 2**64", async () => {
    await expect(
      token.connect(owner).setMaxSupply(ethers.BigNumber.from(2).pow(70))
    ).to.be.revertedWith(
      `CannotExceedMaxSupplyOfUint64(${ethers.BigNumber.from(2).pow(70)})`
    );
  });

  it("Should only let the owner notify update of batch token URIs", async () => {
    await expect(
      token.connect(admin).emitBatchMetadataUpdate(5, 10)
    ).to.be.revertedWith("OnlyOwner");

    await expect(token.connect(owner).emitBatchMetadataUpdate(5, 10))
      .to.emit(token, "BatchMetadataUpdate")
      .withArgs(5, 10);
  });

  it("Should only let the owner update the royalties address and basis points", async () => {
    expect(await token.royaltyAddress()).to.equal(ethers.constants.AddressZero);
    expect(await token.royaltyBasisPoints()).to.equal(0);

    await expect(
      token.connect(admin).setRoyaltyInfo([owner.address, 100])
    ).to.be.revertedWith("OnlyOwner");

    await expect(
      token.connect(owner).setRoyaltyInfo([owner.address, 10_001])
    ).to.be.revertedWith("InvalidRoyaltyBasisPoints(10001)");
    await expect(
      token.connect(owner).setRoyaltyInfo([ethers.constants.AddressZero, 200])
    ).to.be.revertedWith(`RoyaltyAddressCannotBeZeroAddress()`);

    await expect(token.connect(owner).setRoyaltyInfo([admin.address, 100]))
      .to.emit(token, "RoyaltyInfoUpdated")
      .withArgs(admin.address, 100);
    await expect(token.connect(owner).setRoyaltyInfo([admin.address, 500])) // 5%
      .to.emit(token, "RoyaltyInfoUpdated")
      .withArgs(admin.address, 500);

    expect(await token.royaltyAddress()).to.equal(admin.address);
    expect(await token.royaltyBasisPoints()).to.equal(500);

    expect(await token.royaltyInfo(1, 100_000)).to.deep.equal([
      admin.address,
      ethers.BigNumber.from(5000),
    ]);
    // 0x2a55205a is interface id for EIP-2981
    expect(await token.supportsInterface("0x2a55205a")).to.equal(true);
  });
});
