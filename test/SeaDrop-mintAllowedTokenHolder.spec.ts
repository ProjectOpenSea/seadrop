import { expect } from "chai";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type {
  ERC721PartnerRaribleDrop,
  IRaribleDrop,
  TestERC721,
} from "../typechain-types";
import type { TokenGatedDropStageStruct } from "../typechain-types/src/RaribleDrop";
import type { Wallet } from "ethers";

describe(`RaribleDrop - Mint Allowed Token Holder (v${VERSION})`, function () {
  const { provider } = ethers;
  let raribleDrop: IRaribleDrop;
  let token: ERC721PartnerRaribleDrop;
  let allowedNftToken: TestERC721;
  let owner: Wallet;
  let admin: Wallet;
  let creator: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let dropStage: TokenGatedDropStageStruct;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets.
    owner = new ethers.Wallet(randomHex(32), provider);
    admin = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets.
    for (const wallet of [owner, admin, minter]) {
      await faucet(wallet.address, provider);
    }

    // Deploy Raribledrop.
    const RaribleDrop = await ethers.getContractFactory("RaribleDrop");
    raribleDrop = await RaribleDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token.
    const RaribleDropToken = await ethers.getContractFactory(
      "ERC721PartnerRaribleDrop",
      owner
    );
    token = await RaribleDropToken.deploy("", "", admin.address, [raribleDrop.address]);

    // Deploy the allowed NFT token.
    const AllowedNftToken = await ethers.getContractFactory("TestERC721");
    allowedNftToken = await AllowedNftToken.deploy();

    // Configure token.
    await token.setMaxSupply(100);
    await token.updateCreatorPayoutAddress(raribleDrop.address, creator.address);
    await token
      .connect(admin)
      .updateAllowedFeeRecipient(raribleDrop.address, feeRecipient.address, true);

    // Create the drop stage object.
    dropStage = {
      mintPrice: "10000000000000000", // 0.01 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 500,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 100,
      restrictFeeRecipients: true,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token
      .connect(admin)
      .updateTokenGatedDrop(
        raribleDrop.address,
        allowedNftToken.address,
        dropStage
      );
    await token
      .connect(owner)
      .updateTokenGatedDrop(
        raribleDrop.address,
        allowedNftToken.address,
        dropStage
      );
  });

  it("Should mint a token to a user with the allowed NFT token", async () => {
    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Ensure the token id is not already redeemed.
    expect(
      await raribleDrop.getAllowedNftTokenIdIsRedeemed(
        token.address,
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.be.false;

    // Mint the token to the minter and verify the expected event was emitted.
    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        1, // mint quantity
        dropStage.mintPrice,
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    // Ensure the token id was redeemed.
    expect(
      await raribleDrop.getAllowedNftTokenIdIsRedeemed(
        token.address,
        mintParams.allowedNftToken,
        mintParams.allowedNftTokenIds[0]
      )
    ).to.be.true;

    expect(await raribleDrop.getTokenGatedAllowedTokens(token.address)).to.deep.eq([
      allowedNftToken.address,
    ]);
  });

  it("Should mint a token to a user with the allowed NFT token when the payer is different from the minter", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // The payer must be allowed first.
    await expect(
      raribleDrop
        .connect(owner)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    ).to.be.revertedWith("PayerNotAllowed");

    // Allow the payer.
    await token
      .connect(owner)
      .updatePayer(raribleDrop.address, owner.address, true);

    await expect(
      raribleDrop
        .connect(owner)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        owner.address,
        1, // mint quantity
        dropStage.mintPrice,
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(1);
  });

  it("Should mint a token to a user with the allowed NFT token when the mint is free", async () => {
    // Create the free mint drop stage object.
    const dropStageFreeMint = { ...dropStage, mintPrice: 0 };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(
      raribleDrop.address,
      allowedNftToken.address,
      dropStageFreeMint
    );

    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams
        )
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        1, // mint quantity
        0, // free
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(1);
  });

  it("Should revert if the allowed NFT token has already been redeemed", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    )
      .to.emit(raribleDrop, "RaribleDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        1, // mint quantity
        dropStage.mintPrice,
        dropStage.feeBps,
        dropStage.dropStageIndex
      );

    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    ).to.be.revertedWith(
      `TokenGatedTokenIdAlreadyRedeemed("${token.address}", "${allowedNftToken.address}", 0)`
    );
  });

  it("Should revert if the minter does not own the allowed NFT token passed into the call", async () => {
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the owner.
    await allowedNftToken.mint(owner.address, 0);

    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    ).to.be.revertedWith(
      `TokenGatedNotTokenOwner("${token.address}", "${allowedNftToken.address}", 0)`
    );
  });

  it("Should revert if the drop stage is not active", async () => {
    // Create the drop stage object.
    const dropStageExpired = {
      ...dropStage,
      endTime: Math.round(Date.now() / 1000) - 500,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(
      raribleDrop.address,
      allowedNftToken.address,
      dropStageExpired
    );

    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    await expect(
      raribleDrop.mintAllowedTokenHolder(
        token.address,
        feeRecipient.address,
        ethers.constants.AddressZero,
        mintParams
      )
    ).to.be.revertedWith(
      `NotActive(${mostRecentBlockTimestamp + 1}, ${dropStage.startTime}, ${
        dropStageExpired.endTime
      })`
    );
  });

  it("Should not mint an allowed token holder stage with a different fee recipient", async () => {
    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Expect the transaction to revert since an incorrect fee recipient was given.
    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          creator.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    ).to.be.revertedWith("FeeRecipientNotAllowed()");
  });

  it("Should not mint an allowed token holder stage with a different token contract", async () => {
    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter.
    await allowedNftToken.mint(minter.address, 0);

    // Deploy a new ERC721PartnerRaribleDrop.
    const RaribleDropToken = await ethers.getContractFactory(
      "ERC721PartnerRaribleDrop"
    );
    const differentToken = await RaribleDropToken.deploy("", "", owner.address, [
      raribleDrop.address,
    ]);

    // Update the fee recipient and creator payout address for the new token.
    await differentToken.setMaxSupply(1000);
    await differentToken
      .connect(owner)
      .updateAllowedFeeRecipient(raribleDrop.address, feeRecipient.address, true);

    await differentToken.updateCreatorPayoutAddress(
      raribleDrop.address,
      creator.address
    );

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    // Expect the transaction to revert since a different token address was given.
    // Transaction will revert with NotActive() because startTime and endTime for
    // a nonexistent drop stage will be 0.
    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          differentToken.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    ).to.be.revertedWith(`NotActive(${mostRecentBlockTimestamp + 1}, 0, 0)`);
  });

  it("Should not mint an allowed token holder stage with different mint params", async () => {
    // Deploy a different allowed NFT token.
    const AllowedNftToken = await ethers.getContractFactory("TestERC721");
    const differentAllowedNftToken = await AllowedNftToken.deploy();

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: differentAllowedNftToken.address,
      allowedNftTokenIds: [0],
    };

    // Mint an allowedNftToken to the minter with a tokenId not included in the mintParams.
    await allowedNftToken.mint(minter.address, 0);

    // Get block.timestamp for custom error.
    const mostRecentBlock = await ethers.provider.getBlock(
      await ethers.provider.getBlockNumber()
    );
    const mostRecentBlockTimestamp = mostRecentBlock.timestamp;

    // Expect the transaction to revert since a different token address was passed to the mintParams.
    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: dropStage.mintPrice }
        )
    ).to.be.revertedWith(`NotActive(${mostRecentBlockTimestamp + 1}, 0, 0)`);
  });

  it("Should not mint an allowed token holder stage after exceeding max mints per wallet", async () => {
    // Create an array of tokenIds with length exceeding maxTotalMintableByWallet.
    const tokenIds = [...Array(20).keys()];

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: tokenIds,
    };

    // Mint the tokenIds in the mintParams to the minter.
    for (const id of tokenIds) {
      await allowedNftToken.mint(minter.address, id);
    }

    // Calculate the value to send with the mint transaction.
    const mintValue = ethers.BigNumber.from(dropStage.mintPrice).mul(
      tokenIds.length
    );

    // Expect the transaction to revert since the mint quantity exceeds the
    // max total mintable by a wallet.
    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: mintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxMintedPerWallet(${tokenIds.length}, ${dropStage.maxTotalMintableByWallet})`
    );
  });

  it("Should not mint an allowed token holder stage after exceeding max token supply for stage", async () => {
    // Create a new drop stage object.
    const newDropStage = {
      ...dropStage,
      maxTotalMintableByWallet: 20,
      maxTokenSupplyForStage: 5,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token
      .connect(admin)
      .updateTokenGatedDrop(
        raribleDrop.address,
        allowedNftToken.address,
        newDropStage
      );
    await token
      .connect(owner)
      .updateTokenGatedDrop(
        raribleDrop.address,
        allowedNftToken.address,
        newDropStage
      );

    // Create an array of tokenIds with length exceeding maxTotalMintableByWallet.
    const tokenIds = [...Array(20).keys()];

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: tokenIds,
    };

    // Mint the tokenIds in the mintParams to the minter.
    for (const id of tokenIds) {
      await allowedNftToken.mint(minter.address, id);
    }

    // Calculate the value to send with the mint transaction.
    const mintValue = ethers.BigNumber.from(dropStage.mintPrice).mul(
      tokenIds.length
    );

    // Expect the transaction to revert since the mint quantity exceeds the
    // max total mintable by a wallet.
    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintParams,
          { value: mintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxTokenSupplyForStage(${tokenIds.length}, 5)`
    );
  });

  it("Should not mint an allowed token holder stage after exceeding max token supply", async () => {
    const newDropStage = {
      ...dropStage,
      maxTotalMintableByWallet: 110,
      maxTokenSupplyForStage: 110,
    };

    // Update the token gated drop for the deployed allowed NFT token.
    await token.updateTokenGatedDrop(
      raribleDrop.address,
      allowedNftToken.address,
      newDropStage
    );

    // Create an array of tokenIds with length exceeding maxTotalMintableByWallet.
    const tokenIds = [...Array(110).keys()];

    // Declare the mint params specifying the allowed NFT token addresses and
    // corresponding tokenIds.
    const mintParams = {
      allowedNftToken: allowedNftToken.address,
      allowedNftTokenIds: tokenIds,
    };

    // Mint the tokenIds in the mintParams to the minter.
    for (const id of tokenIds) {
      await allowedNftToken.mint(minter.address, id);
    }

    // Calculate the value to send with the mint transaction.
    const mintValue = ethers.BigNumber.from(dropStage.mintPrice).mul(
      tokenIds.length
    );

    // Expect the transaction to revert since the mint quantity exceeds the
    // max supply.
    await expect(
      raribleDrop
        .connect(minter)
        .mintAllowedTokenHolder(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams,
          { value: mintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxSupply(${tokenIds.length}, 100)`
    );
  });

  it("Should not be able to set an allowedNftToken to the drop token itself or zero address", async () => {
    await expect(
      token
        .connect(admin)
        .updateTokenGatedDrop(raribleDrop.address, token.address, dropStage)
    ).to.be.revertedWith("TokenGatedDropAllowedNftTokenCannotBeDropToken()");

    await expect(
      token
        .connect(admin)
        .updateTokenGatedDrop(
          raribleDrop.address,
          ethers.constants.AddressZero,
          dropStage
        )
    ).to.be.revertedWith("TokenGatedDropAllowedNftTokenCannotBeZeroAddress()");
  });

  it("Should not be able to set an invalid fee bps", async () => {
    await expect(
      token
        .connect(admin)
        .updateTokenGatedDrop(raribleDrop.address, allowedNftToken.address, {
          ...dropStage,
          feeBps: 15_000,
        })
    ).to.be.revertedWith("InvalidFeeBps");
  });

  it("Should revert when stage not present or fee not set", async () => {
    // Create a non-mintable drop stage object.
    const zeroMintDropStage = {
      ...dropStage,
      maxTotalMintableByWallet: 0,
      maxTokenSupplyForStage: 5,
    };

    const token2 = `0x${"2".repeat(40)}`;

    await whileImpersonating(
      token.address,
      provider,
      async (impersonatedSigner) => {
        // Expect the call to update the drop stage to revert since
        // there is no existing drop stage.
        await expect(
          raribleDrop
            .connect(impersonatedSigner)
            .updateTokenGatedDrop(token2, zeroMintDropStage)
        ).to.be.revertedWith("TokenGatedDropStageNotPresent()");
      }
    );

    // Expect the call to update the drop stage to revert since
    // the admin must first initialize with fee.
    await expect(
      token
        .connect(owner)
        .updateTokenGatedDrop(raribleDrop.address, token2, zeroMintDropStage)
    ).to.be.revertedWith("AdministratorMustInitializeWithFee()");
  });

  it("Should clear from enumeration when deleted", async () => {
    await token
      .connect(owner)
      .updateTokenGatedDrop(raribleDrop.address, allowedNftToken.address, {
        ...dropStage,
        maxTotalMintableByWallet: 0,
      });
    expect(await raribleDrop.getTokenGatedAllowedTokens(token.address)).to.deep.eq(
      []
    );
    expect(
      await raribleDrop.getTokenGatedDrop(token.address, allowedNftToken.address)
    ).to.deep.eq([ethers.BigNumber.from(0), 0, 0, 0, 0, 0, 0, false]);
  });
});
