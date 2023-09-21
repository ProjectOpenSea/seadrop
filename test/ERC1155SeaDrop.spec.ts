import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import {
  VERSION,
  deployERC1155SeaDrop,
  mintTokens,
  openseaConduitAddress,
} from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type {
  ConsiderationInterface,
  ERC1155SeaDrop,
  IERC1155SeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC1155SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;

  // SeaDrop
  let token: ERC1155SeaDrop;
  let tokenSeaDropInterface: IERC1155SeaDrop;

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

    ({ marketplaceContract } = await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy token
    ({ token, tokenSeaDropInterface } = await deployERC1155SeaDrop(
      owner,
      marketplaceContract.address
    ));
  });

  it("Should be able to transfer successfully", async () => {
    await token.setMaxSupply(0, 5);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter,
      tokenId: 0,
      quantity: 5,
    });

    await expect(
      token
        .connect(minter)
        .safeTransferFrom(token.address, creator.address, 0, 1, "0x")
    )
      .to.be.revertedWithCustomError(token, "InvalidCallerOnlyAllowedSeaport")
      .withArgs(minter.address);

    await token
      .connect(minter)
      .safeTransferFrom(minter.address, creator.address, 0, 1, "0x");

    await token.connect(minter).setApprovalForAll(creator.address, true);
    await token
      .connect(creator)
      .safeBatchTransferFrom(minter.address, creator.address, [0], [2], "0x");

    expect(await token.balanceOf(creator.address, 0)).to.eq(3);
    expect(await token.balanceOf(minter.address, 0)).to.eq(2);

    // Should auto-approve the conduit to transfer.
    expect(
      await token.isApprovedForAll(creator.address, openseaConduitAddress)
    ).to.eq(true);
    expect(
      await token.isApprovedForAll(minter.address, openseaConduitAddress)
    ).to.eq(true);
    await whileImpersonating(
      openseaConduitAddress,
      provider,
      async (impersonatedSigner) => {
        console.log(await impersonatedSigner.getAddress());
        await token
          .connect(impersonatedSigner)
          .safeTransferFrom(creator.address, minter.address, 0, 1, "0x");
        await token
          .connect(impersonatedSigner)
          .safeBatchTransferFrom(
            creator.address,
            minter.address,
            [0],
            [1],
            Buffer.from("dadb0d", "hex")
          );
      }
    );

    // Should not allow a non-approved address to transfer.
    await expect(
      token
        .connect(owner)
        .safeTransferFrom(minter.address, creator.address, 0, 1, "0x")
    ).to.be.revertedWithCustomError(token, "NotOwnerNorApproved");
    await expect(
      token
        .connect(owner)
        .safeBatchTransferFrom(
          minter.address,
          creator.address,
          [0],
          [1],
          Buffer.from("dadb0d", "hex")
        )
    ).to.be.revertedWithCustomError(token, "NotOwnerNorApproved");
  });

  it("Should only let the token owner or approved burn their token", async () => {
    const tokenId = 2;
    expect(await token.balanceOf(minter.address, tokenId)).to.equal(0);
    expect(await token.totalSupply(tokenId)).to.equal(0);
    expect(await token.maxSupply(tokenId)).to.equal(0);

    // Mint 3 tokens to the minter.
    await token.setMaxSupply(tokenId, 6);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
      minter,
      tokenId,
      quantity: 6,
    });

    expect(await token.balanceOf(minter.address, tokenId)).to.equal(6);
    expect(await token.totalSupply(tokenId)).to.equal(6);
    expect(await token.maxSupply(tokenId)).to.equal(6);

    // Only the owner or approved of the minted token should be able to burn it.
    await expect(
      token.connect(owner).burn(minter.address, tokenId, 1)
    ).to.be.revertedWithCustomError(token, "NotOwnerNorApproved");
    await expect(
      token.connect(creator).batchBurn(minter.address, [tokenId], [2])
    ).to.be.revertedWithCustomError(token, "NotOwnerNorApproved");

    expect(await token.balanceOf(minter.address, tokenId)).to.equal(6);
    expect(await token.totalSupply(tokenId)).to.equal(6);

    await token.connect(minter).burn(minter.address, tokenId, 1);

    expect(await token.totalSupply(tokenId)).to.equal(5);

    await token.connect(minter).setApprovalForAll(creator.address, true);
    await token.connect(creator).burn(minter.address, tokenId, 1);

    expect(await token.totalSupply(tokenId)).to.equal(4);

    await token.connect(minter).setApprovalForAll(creator.address, false);
    await expect(
      token.connect(creator).burn(minter.address, tokenId, 1)
    ).to.be.revertedWithCustomError(token, "NotOwnerNorApproved");

    await token.connect(minter).burn(minter.address, tokenId, 1);
    expect(await token.balanceOf(minter.address, tokenId)).to.eq(3);
    expect(await token.totalSupply(tokenId)).to.equal(3);

    await expect(
      token.connect(minter).burn(minter.address, tokenId, 4)
    ).to.be.revertedWithCustomError(token, "InsufficientBalance");

    // Should not be able to burn a nonexistent token.
    for (const tokenId of [20, 15, 29, 31]) {
      await expect(
        token.connect(minter).burn(minter.address, tokenId, 1)
      ).to.be.revertedWithCustomError(token, "InsufficientBalance");
      await expect(
        token.connect(minter).batchBurn(minter.address, [tokenId], [1])
      ).to.be.revertedWithCustomError(token, "InsufficientBalance");
    }

    // Should revert if trying to burn more than the balance.
    await expect(
      token.connect(minter).batchBurn(minter.address, [0, tokenId], [1, 1])
    ).to.be.revertedWithCustomError(token, "InsufficientBalance");

    await token.connect(minter).batchBurn(minter.address, [tokenId], [1]);
    expect(await token.balanceOf(minter.address, tokenId)).to.eq(2);
    expect(await token.totalSupply(tokenId)).to.equal(2);

    await token.connect(minter).batchBurn(minter.address, [tokenId], [2]);
    expect(await token.balanceOf(minter.address, tokenId)).to.eq(0);
    expect(await token.totalSupply(tokenId)).to.equal(0);
  });
});
