import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION, mintTokens } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type {
  ConduitInterface,
  ConsiderationInterface,
  ERC721SeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;
  let conduitOne: ConduitInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
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
    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy(
      "",
      "",
      marketplaceContract.address,
      conduitOne.address
    );
  });

  it("Should be able to transfer successfully", async () => {
    await mintTokens({
      marketplaceContract,
      token,
      minter,
      quantity: 5,
    });

    await token
      .connect(minter)
      .transferFrom(minter.address, creator.address, 1);
    await token
      .connect(minter)
      ["safeTransferFrom(address,address,uint256)"](
        minter.address,
        creator.address,
        2
      );
    await token
      .connect(minter)
      ["safeTransferFrom(address,address,uint256,bytes)"](
        minter.address,
        creator.address,
        3,
        Buffer.from("dadb0d", "hex")
      );
    expect(await token.balanceOf(creator.address)).to.eq(3);

    await token.connect(minter).setApprovalForAll(creator.address, true);
    await token.connect(minter).approve(creator.address, 4);
  });

  it("Should only let the token owner burn their own token", async () => {
    await token.setMaxSupply(3);

    // Mint 3 tokens to the minter.
    await mintTokens({
      marketplaceContract,
      token,
      minter,
      quantity: 3,
    });

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.ownerOf(2)).to.equal(minter.address);
    expect(await token.ownerOf(3)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(3);

    // Only the owner or approved of the minted token should be able to burn it.
    await expect(token.connect(owner).burn(1)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );
    await expect(token.connect(creator).burn(1)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );
    await expect(token.connect(creator).burn(2)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );
    await expect(token.connect(creator).burn(3)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );

    expect(await token.ownerOf(1)).to.equal(minter.address);
    expect(await token.ownerOf(2)).to.equal(minter.address);
    expect(await token.ownerOf(3)).to.equal(minter.address);
    expect(await token.totalSupply()).to.equal(3);

    await token.connect(minter).burn(1);

    expect(await token.totalSupply()).to.equal(2);

    await token.connect(minter).setApprovalForAll(creator.address, true);
    await token.connect(creator).burn(2);

    expect(await token.totalSupply()).to.equal(1);

    await token.connect(minter).setApprovalForAll(creator.address, false);
    await expect(token.connect(creator).burn(3)).to.be.revertedWithCustomError(
      token,
      "TransferCallerNotOwnerNorApproved"
    );

    await token.connect(minter).approve(owner.address, 3);
    await token.connect(owner).burn(3);

    expect(await token.totalSupply()).to.equal(0);

    await expect(token.ownerOf(1)).to.be.revertedWithCustomError(
      token,
      "OwnerQueryForNonexistentToken"
    );
    await expect(token.ownerOf(2)).to.be.revertedWithCustomError(
      token,
      "OwnerQueryForNonexistentToken"
    );
    expect(await token.totalSupply()).to.equal(0);

    // Should not be able to burn a nonexistent token.
    for (const tokenId of [0, 1, 2, 3]) {
      await expect(
        token.connect(minter).burn(tokenId)
      ).to.be.revertedWithCustomError(token, "OwnerQueryForNonexistentToken");
    }
  });

  it("Should allow the contract owner to withdraw all funds in the contract", async () => {
    await expect(
      token.connect(minter).withdraw()
    ).to.be.revertedWithCustomError(token, "OnlyOwner");

    await expect(token.connect(owner).withdraw()).to.be.revertedWithCustomError(
      token,
      "NoBalanceToWithdraw"
    );

    // Send some balance to the contract.
    await mintTokens({
      marketplaceContract,
      token,
      minter,
      quantity: 1,
    });
    await token.connect(minter).approve(owner.address, 1, { value: 100 });

    let contractBalance = await provider.getBalance(token.address);
    expect(contractBalance).to.equal(100);

    const ownerBalanceBefore = await provider.getBalance(owner.address);
    const tx = await token.connect(owner).withdraw();
    const receipt = await tx.wait();
    const txCost = receipt.gasUsed.mul(receipt.effectiveGasPrice);

    const ownerBalanceAfter = await provider.getBalance(owner.address);
    expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.sub(txCost).add(100));

    contractBalance = await provider.getBalance(token.address);
    expect(contractBalance).to.equal(0);

    // Set the owner to a contract without a payable fallback function to get coverage for WithdrawalFailed.
    // Note: If the below storage slot changes, the updated value can be found
    // with `forge inspect ERC721SeaDrop storage-layout`
    const ownerStorageSlot = "0xa";
    const ownerStorageValue = "0x" + token.address.slice(2).padStart(64, "0");
    await provider.send("hardhat_setStorageAt", [
      token.address,
      ownerStorageSlot,
      ownerStorageValue,
    ]);
    expect(await token.owner()).to.equal(token.address);
    await token.connect(minter).approve(owner.address, 1, { value: 100 });
    await whileImpersonating(
      token.address,
      provider,
      async (impersonatedSigner) => {
        await expect(token.connect(impersonatedSigner).withdraw())
          .to.be.revertedWithCustomError(token, "WithdrawalFailed")
          .withArgs("0x");
      }
    );
  });
});
