import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type {
  ERC721PartnerSeaDropRandomOffset,
  ISeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721PartnerSeaDropRandomOffset (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721PartnerSeaDropRandomOffset;
  let owner: Wallet;
  let admin: Wallet;
  let creator: Wallet;
  let minter: Wallet;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    await network.provider.send("hardhat_mine", ["0x15b3"]);
    // Set the wallets
    owner = new ethers.Wallet(randomHex(32), provider);
    admin = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, admin, minter, creator]) {
      await faucet(wallet.address, provider);
    }

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", owner);
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721PartnerSeaDropRandomOffset = await ethers.getContractFactory(
      "ERC721PartnerSeaDropRandomOffset",
      owner
    );
    token = await ERC721PartnerSeaDropRandomOffset.deploy(
      "",
      "",
      admin.address,
      [seadrop.address]
    );
  });

  it("Should only let the owner call allowReveal", async () => {
    await token.setMaxSupply(100);

    await expect(token.connect(admin).allowReveal()).to.be.revertedWith(
      "OnlyOwner()"
    );

    // Mint to the max supply.
    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await token
          .connect(impersonatedSigner)
          .mintSeaDrop(minter.address, 100);
      }
    );

    await expect(token.connect(admin).allowReveal()).to.be.revertedWith(
      "OnlyOwner()"
    );

    expect(await token.randomOffset()).to.equal(ethers.constants.Zero);

    await token.connect(owner).allowReveal();

    expect(await token.randomOffset()).to.equal(ethers.constants.Zero);

    await network.provider.send("hardhat_mine", ["0x37"]);

    await token.connect(owner).setRandomOffset();

    expect(await token.randomOffset()).to.not.equal(ethers.constants.Zero);

    await expect(token.connect(owner).setRandomOffset()).to.be.revertedWith(
      "AlreadyRevealed()"
    );

    expect(await token.randomOffset()).to.not.equal(ethers.constants.Zero);
  });

  it("Should only allow setRandomOffset once the max supply is reached", async () => {
    await token.setMaxSupply(100);

    await expect(token.connect(minter).setRandomOffset()).to.be.revertedWith(
      "RevealNotAllowed()"
    );

    await expect(token.connect(owner).setRandomOffset()).to.be.revertedWith(
      "RevealNotAllowed()"
    );

    expect(await token.randomOffset()).to.equal(ethers.constants.Zero);

    await token.connect(owner).allowReveal();

    await expect(token.connect(minter).setRandomOffset()).to.be.revertedWith(
      "NotFullyMinted()"
    );

    expect(await token.randomOffset()).to.equal(ethers.constants.Zero);

    await expect(token.connect(owner).setRandomOffset()).to.be.revertedWith(
      "NotFullyMinted()"
    );

    // Mint to the max supply.
    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await token
          .connect(impersonatedSigner)
          .mintSeaDrop(minter.address, 100);
      }
    );

    await token.connect(minter).setRandomOffset();
    await network.provider.send("hardhat_mine", ["0x37"]);
    await token.connect(owner).setRandomOffset();

    expect(await token.randomOffset()).to.not.equal(ethers.constants.Zero);
  });

  it("Should return the tokenURI correctly offset by randomOffset", async () => {
    await token.setMaxSupply(100);

    await token.connect(owner).allowReveal();

    await expect(token.tokenURI(1)).to.be.revertedWith(
      "URIQueryForNonexistentToken()"
    );

    // Mint to the max supply.
    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await token
          .connect(impersonatedSigner)
          .mintSeaDrop(minter.address, 100);
      }
    );

    expect(await token.tokenURI(1)).to.equal("");

    await token.setBaseURI("http://example.com/");

    expect(await token.tokenURI(1)).to.equal("http://example.com/");

    await token.connect(owner).setRandomOffset();
    await network.provider.send("hardhat_mine", ["0x37"]);
    await token.connect(owner).setRandomOffset();

    const randomOffset = (await token.randomOffset()).toNumber();

    expect(randomOffset).to.be.greaterThan(0);
    expect(randomOffset).to.be.lessThanOrEqual(100);

    const startTokenId = 1;

    expect(await token.tokenURI(1)).to.equal(
      `http://example.com/${((1 + randomOffset) % 100) + startTokenId}`
    );
    expect(await token.tokenURI(100)).to.equal(
      `http://example.com/${((100 + randomOffset) % 100) + startTokenId}`
    );

    const tokenUri2 = 101 - randomOffset;
    const tokenUri1 = 100 - randomOffset;
    const tokenUri100 = 99 - randomOffset;
    const tokenUri99 = 98 - randomOffset;
    expect(await token.tokenURI(tokenUri2)).to.equal(`http://example.com/2`);
    expect(await token.tokenURI(tokenUri1)).to.equal(`http://example.com/1`);
    expect(await token.tokenURI(tokenUri100)).to.equal(
      `http://example.com/100`
    );
    expect(await token.tokenURI(tokenUri99)).to.equal(`http://example.com/99`);
  });
});
