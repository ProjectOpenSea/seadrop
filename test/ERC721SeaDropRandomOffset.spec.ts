import { expect } from "chai";
import { ethers, network } from "hardhat";

import { IERC721SeaDrop__factory } from "../typechain-types";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION, mintTokens } from "./utils/helpers";

import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDropRandomOffset,
  IERC721SeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721SeaDropRandomOffset (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDropRandomOffset;
  let tokenSeaDropInterface: IERC721SeaDrop;

  // Wallets
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

    ({ conduitOne, marketplaceContract } = await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy configurer
    const ERC721SeaDropConfigurer = await ethers.getContractFactory(
      "ERC721SeaDropConfigurer",
      owner
    );
    const configurer = await ERC721SeaDropConfigurer.deploy();

    // Deploy token
    const ERC721SeaDropRandomOffset = await ethers.getContractFactory(
      "ERC721SeaDropRandomOffset",
      owner
    );
    token = await ERC721SeaDropRandomOffset.deploy(
      configurer.address,
      marketplaceContract.address,
      conduitOne.address,
      "",
      ""
    );

    tokenSeaDropInterface = IERC721SeaDrop__factory.connect(
      token.address,
      owner
    );
  });

  it("Should only let the owner call setRandomOffset once the max supply is reached", async () => {
    await token.setMaxSupply(100);

    await expect(
      token.connect(minter).setRandomOffset()
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    await expect(token.setRandomOffset()).to.be.revertedWithCustomError(
      token,
      "NotFullyMinted"
    );

    // Mint to the max supply.
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter,
      quantity: 100,
    });

    expect(await token.randomOffset()).to.equal(ethers.constants.Zero);

    await token.setRandomOffset();

    await expect(token.setRandomOffset()).to.be.revertedWithCustomError(
      token,
      "AlreadyRevealed"
    );

    expect(await token.randomOffset()).to.not.equal(ethers.constants.Zero);
  });

  it("Should return the tokenURI correctly offset by randomOffset", async () => {
    await token.setMaxSupply(100);

    await expect(token.tokenURI(1)).to.be.revertedWithCustomError(
      token,
      "URIQueryForNonexistentToken"
    );

    // Mint to the max supply.
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter,
      quantity: 100,
    });

    expect(await token.tokenURI(1)).to.equal("");

    await token.setBaseURI("http://example.com/");

    expect(await token.tokenURI(1)).to.equal("http://example.com/");

    await expect(token.setRandomOffset())
      .to.emit(token, "BatchMetadataUpdate")
      .withArgs(1, 100);

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
