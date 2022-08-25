import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let owner: Wallet;
  let admin: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;

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
    payer = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    await faucet(owner.address, provider);
    await faucet(admin.address, provider);
    await faucet(payer.address, provider);
    await faucet(minter.address, provider);
    await faucet(creator.address, provider);

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", owner);
    seadrop = await SeaDrop.deploy();

    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy("", "", admin.address, [
      seadrop.address,
    ]);
  });

  it("Should only let the token owner update the creator payout address", async () => {
    expect(await seadrop.getCreatorPayoutAddress(token.address)).to.equal(
      ethers.constants.AddressZero
    );

    await expect(
      token
        .connect(admin)
        .updateCreatorPayoutAddress(seadrop.address, creator.address)
    ).to.revertedWith("OnlyOwner");

    expect(await seadrop.getCreatorPayoutAddress(token.address)).to.equal(
      ethers.constants.AddressZero
    );

    await expect(
      token
        .connect(owner)
        .updateCreatorPayoutAddress(
          seadrop.address,
          ethers.constants.AddressZero
        )
    ).to.be.reverted; // TODO find out why hardhat not recognizing revertedWith("CreatorPayoutAddressCannotBeZeroAddress")

    await expect(
      token
        .connect(owner)
        .updateCreatorPayoutAddress(seadrop.address, creator.address)
    ).to.emit(seadrop, "CreatorPayoutAddressUpdated");

    expect(await seadrop.getCreatorPayoutAddress(token.address)).to.equal(
      creator.address
    );
  });

  it("Should only let the token owner or admin update the drop URI", async () => {
    await expect(
      token.connect(creator).updateDropURI(seadrop.address, "http://test.com")
    ).to.revertedWith("OnlyOwnerOrAdministrator");

    await expect(
      token.connect(owner).updateDropURI(seadrop.address, "http://test.com")
    ).to.emit(seadrop, "DropURIUpdated");

    await expect(
      token.connect(admin).updateDropURI(seadrop.address, "http://test.com")
    ).to.emit(seadrop, "DropURIUpdated");
  });

  it("Should only let the owner or admin update the public drop parameters", async () => {
    const publicDrop = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxMintsPerWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };

    // Only the owner should be able to call `updatePublicDrop`,
    // but they cannot update feeBps or restrictFeeRecipients.

    await expect(
      token.connect(creator).updatePublicDrop(seadrop.address, publicDrop)
    ).to.be.revertedWith("OnlyOwner");

    await expect(
      token.connect(admin).updatePublicDrop(seadrop.address, publicDrop)
    ).to.be.revertedWith("OnlyOwner");

    await expect(
      token.connect(owner).updatePublicDrop(seadrop.address, publicDrop)
    ).to.emit(seadrop, "PublicDropUpdated");

    // The owner should not be able to update the fee.
    await expect(
      token.connect(owner).updatePublicDrop(seadrop.address, publicDrop)
    ).to.emit(seadrop, "PublicDropUpdated");
    // Ensure public drop fee parameters were not changed.
    expect((await seadrop.getPublicDrop(token.address))[3]).to.eq(0);
    expect((await seadrop.getPublicDrop(token.address))[4]).to.eq(true);

    // Now try from the admin using `updatePublicDropFee`.
    await expect(
      token.connect(admin).updatePublicDropFee(seadrop.address, 50)
    ).to.emit(seadrop, "PublicDropUpdated");
    // Ensure public drop fee parameters were updated.
    expect((await seadrop.getPublicDrop(token.address))[3]).to.eq(50);
    expect((await seadrop.getPublicDrop(token.address))[4]).to.eq(true);
  });

  it("Should only let the admin update the allowed fee recipients", async () => {
    const feeRecipient = new ethers.Wallet(randomHex(32), provider);

    expect(await seadrop.getAllowedFeeRecipients(token.address)).to.deep.eq([]);

    expect(
      await seadrop.getFeeRecipientIsAllowed(
        token.address,
        feeRecipient.address
      )
    ).to.be.false;

    await expect(
      token
        .connect(owner)
        .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true)
    ).to.be.revertedWith("OnlyAdministrator");

    expect(await seadrop.getAllowedFeeRecipients(token.address)).to.deep.eq([]);

    await expect(
      token
        .connect(admin)
        .updateAllowedFeeRecipient(
          seadrop.address,
          ethers.constants.AddressZero,
          true
        )
    ).to.be.reverted; // TODO find out why hardhat not recognizing revertedWith("FeeRecipientCannotBeZeroAddress")

    await expect(
      token
        .connect(admin)
        .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true)
    ).to.emit(seadrop, "AllowedFeeRecipientUpdated");

    await expect(
      token
        .connect(admin)
        .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true)
    ).to.be.reverted; // TODO find out why hardhat not recognizing revertedWith("DuplicateFeeRecipient")

    expect(await seadrop.getAllowedFeeRecipients(token.address)).to.deep.eq([
      feeRecipient.address,
    ]);

    expect(
      await seadrop.getFeeRecipientIsAllowed(
        token.address,
        feeRecipient.address
      )
    ).to.be.true;

    // Now let's disallow the feeRecipient
    await expect(
      token
        .connect(admin)
        .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, false)
    ).to.emit(seadrop, "AllowedFeeRecipientUpdated");

    expect(await seadrop.getAllowedFeeRecipients(token.address)).to.deep.eq([]);

    expect(
      await seadrop.getFeeRecipientIsAllowed(
        token.address,
        feeRecipient.address
      )
    ).to.be.false;

    await expect(
      token
        .connect(admin)
        .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, false)
    ).to.be.reverted; // TODO find out why hardhat not recognizing revertedWith("FeeRecipientNotPresent")
  });

  it("Should only let the owner set the provenance hash", async () => {
    expect(await token.provenanceHash()).to.equal(ethers.constants.HashZero);

    const firstProvenanceHash =
      "0x1111111111111111111111111111111111111111111111111111111111111111";
    const secondProvenanceHash =
      "0x2222222222222222222222222222222222222222222222222222222222222222";

    await expect(
      token.connect(creator).setProvenanceHash(firstProvenanceHash)
    ).to.revertedWith("OnlyOwner");

    await expect(
      token.connect(admin).setProvenanceHash(firstProvenanceHash)
    ).to.revertedWith("OnlyOwner");

    await expect(
      token.connect(owner).setProvenanceHash(firstProvenanceHash)
    ).to.emit(token, "ProvenanceHashUpdated");

    // Provenance hash should not be updatable after the first token has minted
    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await token.connect(impersonatedSigner).mintSeaDrop(minter.address, 1);
      }
    );

    await expect(
      token.connect(owner).setProvenanceHash(secondProvenanceHash)
    ).to.be.revertedWith("ProvenanceHashCannotBeSetAfterMintStarted");

    expect(await token.provenanceHash()).to.equal(firstProvenanceHash);
  });
});
