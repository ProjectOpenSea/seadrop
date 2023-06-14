import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721RaribleDropBurnable, IRaribleDrop } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721RaribleDropBurnable (v${VERSION})`, function () {
  const { provider } = ethers;
  let raribleDrop: IRaribleDrop;
  let token: ERC721RaribleDropBurnable;
  let owner: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let approved: Wallet;

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
    approved = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, minter, creator, approved]) {
      await faucet(wallet.address, provider);
    }

    // Deploy RaribleDrop
    const RaribleDrop = await ethers.getContractFactory("RaribleDrop", owner);
    raribleDrop = await RaribleDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721RaribleDropBurnable = await ethers.getContractFactory(
      "ERC721RaribleDropBurnable",
      owner
    );
    token = await ERC721RaribleDropBurnable.deploy("", "", [raribleDrop.address]);
  });

  it("Should only let the token owner burn their own token", async () => {
    await token.setMaxSupply(3);

    // Mint three tokens to the minter.
    await whileImpersonating(
      raribleDrop.address,
      provider,
      async (impersonatedSigner) => {
        await token.connect(impersonatedSigner).mintRaribleDrop(minter.address, 3);
      }
    );

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.ownerOf(2)).to.equal(minter.address);
    expect(await token.ownerOf(3)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(3);

    // Only the owner or approved of the minted token should be able to burn it.
    await expect(token.connect(owner).burn(1)).to.be.revertedWith(
      "TransferCallerNotOwnerNorApproved()"
    );
    await expect(token.connect(approved).burn(1)).to.be.revertedWith(
      "TransferCallerNotOwnerNorApproved()"
    );
    await expect(token.connect(approved).burn(2)).to.be.revertedWith(
      "TransferCallerNotOwnerNorApproved()"
    );
    await expect(token.connect(owner).burn(3)).to.be.revertedWith(
      "TransferCallerNotOwnerNorApproved()"
    );

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.ownerOf(2)).to.equal(minter.address);
    expect(await token.ownerOf(3)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(3);

    await token.connect(minter).burn(1);

    expect(await token.totalSupply()).to.equal(2);

    await token.connect(minter).setApprovalForAll(approved.address, true);
    await token.connect(approved).burn(2);

    expect(await token.totalSupply()).to.equal(1);

    await token.connect(minter).setApprovalForAll(approved.address, false);
    await expect(token.connect(approved).burn(3)).to.be.revertedWith(
      "TransferCallerNotOwnerNorApproved()"
    );

    await token.connect(minter).approve(owner.address, 3);
    await token.connect(owner).burn(3);

    expect(await token.totalSupply()).to.equal(0);

    await expect(token.ownerOf(1)).to.be.revertedWith(
      "OwnerQueryForNonexistentToken()"
    );
    await expect(token.ownerOf(2)).to.be.revertedWith(
      "OwnerQueryForNonexistentToken()"
    );
    expect(await token.totalSupply()).to.equal(0);

    // Should not be able to burn a nonexistent token.
    for (const tokenId of [0, 1, 2, 3]) {
      await expect(token.connect(minter).burn(tokenId)).to.be.revertedWith(
        "OwnerQueryForNonexistentToken()"
      );
    }
  });
});
