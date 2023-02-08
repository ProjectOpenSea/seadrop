import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721SeaDropRandomOffset, ISeaDrop } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721SeaDropRandomOffset (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDropRandomOffset;
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

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", owner);
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721SeaDropRandomOffset = await ethers.getContractFactory(
      "ERC721SeaDropRandomOffset",
      owner
    );
    token = await ERC721SeaDropRandomOffset.deploy("", "", [seadrop.address]);
  });

  it("Should only let the owner call setRandomOffset once the max supply is reached", async () => {
    await token.setMaxSupply(100);

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
