import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type {
  ERC721PartnerSeaDropBurnable,
  ISeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721PartnerSeaDropBurnable (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721PartnerSeaDropBurnable;
  let owner: Wallet;
  let admin: Wallet;
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
    admin = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    approved = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, admin, minter, creator, approved]) {
      await faucet(wallet.address, provider);
    }

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", owner);
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721PartnerSeaDropBurnable = await ethers.getContractFactory(
      "ERC721PartnerSeaDropBurnable",
      owner
    );
    token = await ERC721PartnerSeaDropBurnable.deploy("", "", admin.address, [
      seadrop.address,
    ]);
  });

  it("Should only let the token owner burn their own token", async () => {
    await token.setMaxSupply(1);

    // Mint two tokens to the minter.
    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await token.connect(impersonatedSigner).mintSeaDrop(minter.address, 2);
      }
    );

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(2);

    // Only the owner or approved of the minted token should be able to burn it.
    await expect(token.connect(admin).burn(1)).to.be.revertedWith(
      "BurnNotOwnerOrApproved()"
    );
    await expect(token.connect(owner).burn(1)).to.be.revertedWith(
      "BurnNotOwnerOrApproved()"
    );
    await expect(token.connect(approved).burn(1)).to.be.revertedWith(
      "BurnNotOwnerOrApproved()"
    );
    await expect(token.connect(approved).burn(2)).to.be.revertedWith(
      "BurnNotOwnerOrApproved()"
    );

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(2);

    await token.connect(minter).burn(1);

    expect(await token.totalSupply()).to.equal(1);

    await token.connect(minter).approve(approved.address, 1);
    await token.connect(approved).burn(2);

    expect(await token.totalSupply()).to.equal(0);

    await expect(token.ownerOf(1)).to.be.revertedWith(
      "OwnerQueryForNonexistentToken()"
    );
    await expect(token.ownerOf(2)).to.be.revertedWith(
      "OwnerQueryForNonexistentToken()"
    );
    expect(await token.totalSupply()).to.equal(0);

    // Should not be able to burn a nonexistent token.
    for (const tokenId of [0, 1, 2]) {
      await expect(token.connect(minter).burn(tokenId)).to.be.revertedWith(
        "OwnerQueryForNonexistentToken()"
      );
    }
  });
});
