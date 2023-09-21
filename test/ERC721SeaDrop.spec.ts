import { expect } from "chai";
import { ethers, network } from "hardhat";

import { seaportFixture } from "./seaport-utils/fixtures";
import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import {
  VERSION,
  deployERC721SeaDrop,
  mintTokens,
  openseaConduitAddress,
} from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type {
  ConsiderationInterface,
  ERC721SeaDrop,
  IERC721SeaDrop,
} from "../typechain-types";
import type { Wallet } from "ethers";

describe(`ERC721SeaDrop (v${VERSION})`, function () {
  const { provider } = ethers;

  // Seaport
  let marketplaceContract: ConsiderationInterface;

  // SeaDrop
  let token: ERC721SeaDrop;
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

    ({ marketplaceContract } = await seaportFixture(owner));
  });

  beforeEach(async () => {
    // Deploy token
    ({ token, tokenSeaDropInterface } = await deployERC721SeaDrop(
      owner,
      marketplaceContract.address
    ));
  });

  it("Should be able to transfer successfully", async () => {
    await token.setMaxSupply(5);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
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
        await token
          .connect(impersonatedSigner)
          .transferFrom(creator.address, minter.address, 1);
        await token
          .connect(impersonatedSigner)
          ["safeTransferFrom(address,address,uint256)"](
            creator.address,
            minter.address,
            2
          );
        await token
          .connect(impersonatedSigner)
          ["safeTransferFrom(address,address,uint256,bytes)"](
            creator.address,
            minter.address,
            3,
            Buffer.from("dadb0d", "hex")
          );
      }
    );

    // Should not allow a non-approved address to transfer.
    await expect(
      token.connect(owner).transferFrom(minter.address, creator.address, 1)
    ).to.be.revertedWithCustomError(token, "TransferCallerNotOwnerNorApproved");
    await expect(
      token
        .connect(owner)
        ["safeTransferFrom(address,address,uint256)"](
          minter.address,
          creator.address,
          2
        )
    ).to.be.revertedWithCustomError(token, "TransferCallerNotOwnerNorApproved");
    await expect(
      token
        .connect(owner)
        ["safeTransferFrom(address,address,uint256,bytes)"](
          minter.address,
          creator.address,
          3,
          Buffer.from("dadb0d", "hex")
        )
    ).to.be.revertedWithCustomError(token, "TransferCallerNotOwnerNorApproved");
  });

  it("Should only let the token owner or approved burn their token", async () => {
    // Mint 3 tokens to the minter.
    await token.setMaxSupply(3);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
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
    ).to.be.revertedWithCustomError(token, "Unauthorized");

    await expect(token.connect(owner).withdraw()).to.be.revertedWithCustomError(
      token,
      "NoBalanceToWithdraw"
    );

    // Send some balance to the contract.
    await token.setMaxSupply(1);
    await mintTokens({
      marketplaceContract,
      token,
      tokenSeaDropInterface,
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

    // Owner storage slot from solady's Ownable.sol
    const ownerStorageSlot =
      "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffff74873927";

    const revertedRecipientFactory = await ethers.getContractFactory(
      "RevertedRecipient"
    );
    const revertedRecipient = await revertedRecipientFactory.deploy();
    // token.address will revert with no data, and RevertedRecipient will revert with custom error.
    const ownerAddresses = [token.address, revertedRecipient.address];

    for (const ownerAddress of ownerAddresses) {
      const ownerStorageValue = "0x" + ownerAddress.slice(2).padStart(64, "0");
      await provider.send("hardhat_setStorageAt", [
        token.address,
        ownerStorageSlot,
        ownerStorageValue,
      ]);
      expect(await token.owner()).to.equal(ownerAddress); // If this starts failing, see NOTE above.
      await token.connect(minter).approve(owner.address, 1, { value: 100 });
      await whileImpersonating(
        ownerAddress,
        provider,
        async (impersonatedSigner) => {
          await expect(token.connect(impersonatedSigner).withdraw()).to.be
            .reverted;
        }
      );
    }
  });
});
