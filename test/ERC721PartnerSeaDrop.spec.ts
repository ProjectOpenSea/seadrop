import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721PartnerSeaDrop, ISeaDrop } from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/ERC721PartnerSeaDrop";
import type { Wallet } from "ethers";

describe(`ERC721PartnerSeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721PartnerSeaDrop;
  let owner: Wallet;
  let admin: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let publicDrop: PublicDropStruct;

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
    const ERC721PartnerSeaDrop = await ethers.getContractFactory(
      "ERC721PartnerSeaDrop",
      owner
    );
    token = await ERC721PartnerSeaDrop.deploy("", "", admin.address, [
      seadrop.address,
    ]);

    publicDrop = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };
  });

  it("Should not be able to mint until the creator address is updated to non-zero", async () => {
    await token.connect(admin).updatePublicDrop(seadrop.address, publicDrop);
    await token.connect(owner).updatePublicDrop(seadrop.address, publicDrop);
    await token.setMaxSupply(5);

    const feeRecipient = new ethers.Wallet(randomHex(32), provider);
    await token
      .connect(admin)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true);

    await expect(
      seadrop.mintPublic(
        token.address,
        feeRecipient.address,
        ethers.constants.AddressZero,
        1,
        { value: publicDrop.mintPrice }
      )
    ).to.be.revertedWith("CreatorPayoutAddressCannotBeZeroAddress");

    await token
      .connect(admin)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, false);
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
    ).to.be.revertedWith("CreatorPayoutAddressCannotBeZeroAddress");

    await expect(
      token
        .connect(owner)
        .updateCreatorPayoutAddress(seadrop.address, creator.address)
    )
      .to.emit(seadrop, "CreatorPayoutAddressUpdated")
      .withArgs(token.address, creator.address);

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
    )
      .to.emit(seadrop, "DropURIUpdated")
      .withArgs(token.address, "http://test.com");

    await expect(
      token.connect(admin).updateDropURI(seadrop.address, "http://test.com")
    )
      .to.emit(seadrop, "DropURIUpdated")
      .withArgs(token.address, "http://test.com");
  });

  it("Should only let the owner or admin update the public drop parameters", async () => {
    // Only the admin should be able to set `feeBps`.
    await expect(
      token.connect(creator).updatePublicDrop(seadrop.address, publicDrop)
    ).to.be.revertedWith("OnlyOwner");

    await expect(
      token.connect(owner).updatePublicDrop(seadrop.address, publicDrop)
    ).to.be.revertedWith("AdministratorMustInitializeWithFee()");

    // Ensure public drop fee parameters were not changed.
    expect((await seadrop.getPublicDrop(token.address))[4]).to.eq(0);
    expect((await seadrop.getPublicDrop(token.address))[5]).to.eq(false);

    // Now from the admin.
    await expect(
      token.connect(admin).updatePublicDrop(seadrop.address, publicDrop)
    )
      .to.emit(seadrop, "PublicDropUpdated")
      .withArgs(token.address, [
        0, // mint price
        0, // start time
        0, // end time
        1, // maxTotalMintableByWallet (1 = initialized)
        1000, // fee bps
        true, // restrict fee recipients
      ]);

    // Ensure public drop fee parameters were updated.
    expect((await seadrop.getPublicDrop(token.address))[4]).to.eq(1000);
    expect((await seadrop.getPublicDrop(token.address))[5]).to.eq(true);

    // Now the owner should be able to update freely (without changing feeBps)
    await expect(
      token
        .connect(owner)
        .updatePublicDrop(seadrop.address, { ...publicDrop, feeBps: 1 })
    )
      .to.emit(seadrop, "PublicDropUpdated")
      .withArgs(token.address, [
        publicDrop.mintPrice,
        publicDrop.startTime,
        publicDrop.endTime,
        publicDrop.maxTotalMintableByWallet,
        1000, // fee bps
        true, // restrict fee recipients
      ]);

    // Ensure public drop fee parameters were not updated.
    expect((await seadrop.getPublicDrop(token.address))[4]).to.eq(1000);
    expect((await seadrop.getPublicDrop(token.address))[5]).to.eq(true);
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
    ).to.be.revertedWith("FeeRecipientCannotBeZeroAddress");

    await expect(
      token
        .connect(admin)
        .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true)
    )
      .to.emit(seadrop, "AllowedFeeRecipientUpdated")
      .withArgs(token.address, feeRecipient.address, true);

    await expect(
      token
        .connect(admin)
        .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true)
    ).to.be.revertedWith("DuplicateFeeRecipient");

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
    )
      .to.emit(seadrop, "AllowedFeeRecipientUpdated")
      .withArgs(token.address, feeRecipient.address, false);

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
    ).to.be.revertedWith("FeeRecipientNotPresent");
  });

  it("Should only let the owner set the provenance hash", async () => {
    await token.setMaxSupply(1);
    expect(await token.provenanceHash()).to.equal(ethers.constants.HashZero);

    const defaultProvenanceHash = `0x${"0".repeat(64)}`;
    const firstProvenanceHash = `0x${"1".repeat(64)}`;
    const secondProvenanceHash = `0x${"2".repeat(64)}`;

    await expect(
      token.connect(creator).setProvenanceHash(firstProvenanceHash)
    ).to.revertedWith("OnlyOwner");

    await expect(
      token.connect(admin).setProvenanceHash(firstProvenanceHash)
    ).to.revertedWith("OnlyOwner");

    await expect(token.connect(owner).setProvenanceHash(firstProvenanceHash))
      .to.emit(token, "ProvenanceHashUpdated")
      .withArgs(defaultProvenanceHash, firstProvenanceHash);

    // Provenance hash should not be updatable after the first token has minted.
    // Mint a token.
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

  it("Should only let the token owner or admin update the allowed SeaDrop addresses", async () => {
    await expect(
      token.connect(creator).updateAllowedSeaDrop([seadrop.address])
    ).to.revertedWith("OnlyOwnerOrAdministrator");

    await expect(
      token.connect(minter).updateAllowedSeaDrop([seadrop.address])
    ).to.revertedWith("OnlyOwnerOrAdministrator");

    await expect(token.connect(owner).updateAllowedSeaDrop([seadrop.address]))
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([seadrop.address]);

    const address1 = `0x${"1".repeat(40)}`;
    const address2 = `0x${"2".repeat(40)}`;
    const address3 = `0x${"3".repeat(40)}`;

    await expect(
      token.connect(admin).updateAllowedSeaDrop([seadrop.address, address1])
    )
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([seadrop.address, address1]);

    await expect(token.connect(admin).updateAllowedSeaDrop([address2]))
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([address2]);

    await expect(
      token
        .connect(admin)
        .updateAllowedSeaDrop([address3, seadrop.address, address2, address1])
    )
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([address3, seadrop.address, address2, address1]);

    await expect(token.connect(admin).updateAllowedSeaDrop([seadrop.address]))
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([seadrop.address]);
  });

  it("Should only let allowed seadrop call seaDropMint", async () => {
    await token.setMaxSupply(1);

    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          token.connect(impersonatedSigner).mintSeaDrop(minter.address, 1)
        )
          .to.emit(token, "Transfer")
          .withArgs(ethers.constants.AddressZero, minter.address, 1);

        await expect(
          token.connect(impersonatedSigner).mintSeaDrop(minter.address, 1)
        ).to.be.revertedWith("MintQuantityExceedsMaxSupply(2, 1)");
      }
    );

    await expect(
      token.connect(owner).mintSeaDrop(minter.address, 1)
    ).to.be.revertedWith("OnlyAllowedSeaDrop");
  });

  it("Should only let the owner and administrator call update functions", async () => {
    const onlyOwnerOrAdministratorMethods = [
      "updateAllowedSeaDrop",
      "updatePublicDrop",
      "updateAllowList",
      "updateTokenGatedDrop",
      "updateDropURI",
      "updateSignedMintValidationParams",
      "updatePayer",
    ];

    const OnlyAdministratorMethods = ["updateAllowedFeeRecipient"];

    const onlyOwnerMethods = ["updateCreatorPayoutAddress"];

    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };

    const dropStage = {
      mintPrice: "10000000000000000", // 0.01 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 100,
      restrictFeeRecipients: true,
    };

    const signedMintValidationParams = {
      minMintPrice: 10,
      maxMaxTotalMintableByWallet: 5,
      minStartTime: 50,
      maxEndTime: 100,
      maxMaxTokenSupplyForStage: 100,
      minFeeBps: 5,
      maxFeeBps: 1000,
    };

    const methodParams: any = {
      updateAllowedSeaDrop: [[seadrop.address]],
      updatePublicDrop: [seadrop.address, publicDrop],
      updateAllowList: [seadrop.address, allowListData],
      updateTokenGatedDrop: [seadrop.address, `0x${"4".repeat(40)}`, dropStage],
      updateDropURI: [seadrop.address, "http://test.com"],
      updateCreatorPayoutAddress: [seadrop.address, `0x${"4".repeat(40)}`],
      updateAllowedFeeRecipient: [seadrop.address, `0x${"4".repeat(40)}`, true],
      updateSignedMintValidationParams: [
        seadrop.address,
        `0x${"4".repeat(40)}`,
        signedMintValidationParams,
      ],
      updatePayer: [seadrop.address, `0x${"4".repeat(40)}`, true],
    };

    const paramsWithNonSeaDrop = (method: string) => [
      creator.address,
      ...methodParams[method].slice(1),
    ];

    for (const method of onlyOwnerOrAdministratorMethods) {
      await (token as any).connect(admin)[method](...methodParams[method]);

      // Set to a new random payer to avoid error `DuplicatePayer()`
      if (method === "updatePayer") methodParams.updatePayer[1] = randomHex(20);

      await (token as any).connect(owner)[method](...methodParams[method]);

      await expect(
        (token as any).connect(creator)[method](...methodParams[method])
      ).to.be.revertedWith("OnlyOwnerOrAdministrator()");

      if (method !== "updateAllowedSeaDrop") {
        await expect(
          (token as any).connect(admin)[method](...paramsWithNonSeaDrop(method))
        ).to.be.revertedWith("OnlyAllowedSeaDrop()");
      }
    }

    for (const method of OnlyAdministratorMethods) {
      await (token as any).connect(admin)[method](...methodParams[method]);

      await expect(
        (token as any).connect(owner)[method](...methodParams[method])
      ).to.be.revertedWith("OnlyAdministrator()");

      await expect(
        (token as any).connect(creator)[method](...methodParams[method])
      ).to.be.revertedWith("OnlyAdministrator()");

      await expect(
        (token as any).connect(admin)[method](...paramsWithNonSeaDrop(method))
      ).to.be.revertedWith("OnlyAllowedSeaDrop()");
    }

    for (const method of onlyOwnerMethods) {
      await (token as any).connect(owner)[method](...methodParams[method]);

      await expect(
        (token as any).connect(admin)[method](...methodParams[method])
      ).to.be.revertedWith("OnlyOwner()");

      await expect(
        (token as any).connect(creator)[method](...methodParams[method])
      ).to.be.revertedWith("OnlyOwner()");

      await expect(
        (token as any).connect(owner)[method](...paramsWithNonSeaDrop(method))
      ).to.be.revertedWith("OnlyAllowedSeaDrop()");
    }
  });
});
