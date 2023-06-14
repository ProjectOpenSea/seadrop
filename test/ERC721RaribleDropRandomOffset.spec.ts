import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721RaribleDropRandomOffset, IRaribleDrop } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721RaribleDropRandomOffset (v${VERSION})`, function () {
  const { provider } = ethers;
  let raribleDrop: IRaribleDrop;
  let token: ERC721RaribleDropRandomOffset;
  let owner: Wallet;
  let creator: Wallet;
  let minter: Wallet;

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
    const ERC721RaribleDropRandomOffset = await ethers.getContractFactory(
      "ERC721RaribleDropRandomOffset",
      owner
    );
    token = await ERC721RaribleDropRandomOffset.deploy("", "", [raribleDrop.address]);
  });

  it("Should only let the owner call setRandomOffset once the max supply is reached", async () => {
    await token.setMaxSupply(100);

    await expect(token.connect(owner).setRandomOffset()).to.be.revertedWith(
      "NotFullyMinted()"
    );

    // Mint to the max supply.
    await whileImpersonating(
      raribleDrop.address,
      provider,
      async (impersonatedSigner) => {
        await token
          .connect(impersonatedSigner)
          .mintRaribleDrop(minter.address, 100);
      }
    );

    expect(await token.randomOffset()).to.equal(ethers.constants.Zero);

    await token.connect(owner).setRandomOffset();

    await expect(token.connect(owner).setRandomOffset()).to.be.revertedWith(
      "AlreadyRevealed()"
    );

    expect(await token.randomOffset()).to.not.equal(ethers.constants.Zero);
  });

  it("Should return the tokenURI correctly offset by randomOffset", async () => {
    await token.setMaxSupply(100);

    await expect(token.tokenURI(1)).to.be.revertedWith(
      "URIQueryForNonexistentToken()"
    );

    // Mint to the max supply.
    await whileImpersonating(
      raribleDrop.address,
      provider,
      async (impersonatedSigner) => {
        await token
          .connect(impersonatedSigner)
          .mintRaribleDrop(minter.address, 100);
      }
    );

    expect(await token.tokenURI(1)).to.equal("");

    await token.setBaseURI("http://example.com/");

    expect(await token.tokenURI(1)).to.equal("http://example.com/");

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
