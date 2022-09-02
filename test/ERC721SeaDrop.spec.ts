import { expect } from "chai";
import { ethers, network } from "hardhat";

import {
  IERC165__factory,
  IERC721__factory,
  INonFungibleSeaDropToken__factory,
  ISeaDropTokenContractMetadata__factory,
} from "../typechain-types";

import { getInterfaceID, randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type { PublicDropStruct } from "../typechain-types/src/ERC721PartnerSeaDrop";
import type { Wallet } from "ethers";

describe(`ERC721SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let owner: Wallet;
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
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy("", "", [seadrop.address]);

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
    await token.connect(owner).updatePublicDrop(seadrop.address, publicDrop);
    await token.setMaxSupply(5);

    const feeRecipient = new ethers.Wallet(randomHex(32), provider);
    await token.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      true
    );

    await expect(
      seadrop.mintPublic(
        token.address,
        feeRecipient.address,
        ethers.constants.AddressZero,
        1,
        { value: publicDrop.mintPrice }
      )
    ).to.be.revertedWith("CreatorPayoutAddressCannotBeZeroAddress");

    await token.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      false
    );
  });

  it("Should only let the token owner update the drop URI", async () => {
    await expect(
      token.connect(creator).updateDropURI(seadrop.address, "http://test.com")
    ).to.revertedWith("OnlyOwner");

    await expect(
      token.connect(owner).updateDropURI(seadrop.address, "http://test.com")
    )
      .to.emit(seadrop, "DropURIUpdated")
      .withArgs(token.address, "http://test.com");
  });

  it("Should only let the owner update the allowed fee recipients", async () => {
    const feeRecipient = new ethers.Wallet(randomHex(32), provider);

    expect(await seadrop.getAllowedFeeRecipients(token.address)).to.deep.eq([]);

    expect(
      await seadrop.getFeeRecipientIsAllowed(
        token.address,
        feeRecipient.address
      )
    ).to.be.false;

    await expect(
      token.updateAllowedFeeRecipient(
        seadrop.address,
        ethers.constants.AddressZero,
        true
      )
    ).to.be.revertedWith("FeeRecipientCannotBeZeroAddress");

    await expect(
      token.updateAllowedFeeRecipient(
        seadrop.address,
        feeRecipient.address,
        true
      )
    )
      .to.emit(seadrop, "AllowedFeeRecipientUpdated")
      .withArgs(token.address, feeRecipient.address, true);

    await expect(
      token.updateAllowedFeeRecipient(
        seadrop.address,
        feeRecipient.address,
        true
      )
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
      token.updateAllowedFeeRecipient(
        seadrop.address,
        feeRecipient.address,
        false
      )
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
      token.updateAllowedFeeRecipient(
        seadrop.address,
        feeRecipient.address,
        false
      )
    ).to.be.revertedWith("FeeRecipientNotPresent");
  });

  it("Should only let the owner set the provenance hash", async () => {
    expect(await token.provenanceHash()).to.equal(ethers.constants.HashZero);

    const defaultProvenanceHash = `0x${"0".repeat(64)}`;
    const firstProvenanceHash = `0x${"1".repeat(64)}`;
    const secondProvenanceHash = `0x${"2".repeat(64)}`;

    await expect(
      token.connect(creator).setProvenanceHash(firstProvenanceHash)
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

  it("Should only let allowed seadrop call seaDropMint", async () => {
    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          token.connect(impersonatedSigner).mintSeaDrop(minter.address, 1)
        )
          .to.emit(token, "Transfer")
          .withArgs(ethers.constants.AddressZero, minter.address, 0);
      }
    );

    await expect(
      token.connect(owner).mintSeaDrop(minter.address, 1)
    ).to.be.revertedWith("OnlySeaDrop");
  });

  it("Should not let the minter exceed the max supply", async () => {
    await whileImpersonating(
      seadrop.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          token
            .connect(impersonatedSigner)
            .mintSeaDrop(
              minter.address,
              ethers.BigNumber.from(2).pow(64).add(1)
            )
        ).to.be.revertedWith(
          `CannotExceedMaxSupply(${ethers.BigNumber.from(
            "18446744073709551617"
          )}, ${ethers.BigNumber.from("18446744073709551615")})`
        );
      }
    );
  });

  it("Should return supportsInterface true for supported interfaces", async () => {
    const supportedInterfacesERC721SeaDrop = [
      [
        INonFungibleSeaDropToken__factory,
        ISeaDropTokenContractMetadata__factory,
        IERC165__factory,
      ],
      [ISeaDropTokenContractMetadata__factory],
    ];
    const supportedInterfacesERC721A = [
      [IERC721__factory, IERC165__factory],
      [IERC165__factory],
    ];

    for (const factories of [
      ...supportedInterfacesERC721SeaDrop,
      ...supportedInterfacesERC721A,
    ]) {
      const interfaceId = factories
        .map((factory) => getInterfaceID(factory.createInterface()))
        .reduce((prev, curr) => prev.xor(curr))
        .toHexString();
      expect(await token.supportsInterface(interfaceId)).to.be.true;
    }

    // Ensure invalid interfaces return false.
    const invalidInterfaceIds = ["0x00000000", "0x10000000", "0x00000001"];
    for (const interfaceId of invalidInterfaceIds) {
      expect(await token.supportsInterface(interfaceId)).to.be.false;
    }
  });

  it("Should only let the token owner update the allowed SeaDrop addresses", async () => {
    await expect(
      token.connect(creator).updateAllowedSeaDrop([seadrop.address])
    ).to.revertedWith("OnlyOwner");

    await expect(
      token.connect(minter).updateAllowedSeaDrop([seadrop.address])
    ).to.revertedWith("OnlyOwner");

    await expect(token.updateAllowedSeaDrop([seadrop.address]))
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([seadrop.address]);

    const address1 = `0x${"1".repeat(40)}`;
    const address2 = `0x${"2".repeat(40)}`;
    const address3 = `0x${"3".repeat(40)}`;

    await expect(token.updateAllowedSeaDrop([seadrop.address, address1]))
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([seadrop.address, address1]);

    await expect(token.updateAllowedSeaDrop([address2]))
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([address2]);

    await expect(
      token.updateAllowedSeaDrop([
        address3,
        seadrop.address,
        address2,
        address1,
      ])
    )
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([address3, seadrop.address, address2, address1]);

    await expect(token.updateAllowedSeaDrop([seadrop.address]))
      .to.emit(token, "AllowedSeaDropUpdated")
      .withArgs([seadrop.address]);
  });

  it("Should let the token owner use admin methods", async () => {
    // Test `updateAllowList` for coverage.
    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    await expect(
      token.connect(creator).updateAllowList(seadrop.address, allowListData)
    ).to.be.revertedWith("OnlyOwner");

    // Test `updateTokenGatedDrop` for coverage.
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
    await token.updateTokenGatedDrop(
      seadrop.address,
      `0x${"4".repeat(40)}`,
      dropStage
    );

    await expect(
      token
        .connect(creator)
        .updateTokenGatedDrop(seadrop.address, `0x${"4".repeat(40)}`, dropStage)
    ).to.be.revertedWith("OnlyOwner");

    // Test `updateSigner` for coverage.
    await token.updateSigner(seadrop.address, `0x${"5".repeat(40)}`, true);

    await expect(
      token
        .connect(creator)
        .updateSigner(seadrop.address, `0x${"5".repeat(40)}`, true)
    ).to.be.revertedWith("OnlyOwner");
  });
});
