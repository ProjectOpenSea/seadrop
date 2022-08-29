import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { ERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type { MintParamsStruct } from "../typechain-types/src/SeaDrop";
import type { Wallet } from "ethers";

describe(`SeaDrop - Mint Signed (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let owner: Wallet;
  let admin: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let mintParams: MintParamsStruct;
  let signer: Wallet;
  let eip712Domain: { [key: string]: string | number };
  let eip712Types: Record<string, Array<{ name: string; type: string }>>;

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
    feeRecipient = new ethers.Wallet(randomHex(32), provider);
    signer = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, admin, payer, minter]) {
      await faucet(wallet.address, provider);
    }

    // Deploy SeaDrop
    const SeaDrop = await ethers.getContractFactory("SeaDrop", owner);
    seadrop = await SeaDrop.deploy();

    // Configure EIP-712 params
    eip712Domain = {
      name: "SeaDrop",
      version: "1.0",
      chainId: (await provider.getNetwork()).chainId,
      verifyingContract: seadrop.address,
    };
    eip712Types = {
      SignedMint: [
        { name: "nftContract", type: "address" },
        { name: "minter", type: "address" },
        { name: "feeRecipient", type: "address" },
        { name: "mintParams", type: "MintParams" },
      ],
      MintParams: [
        { name: "mintPrice", type: "uint256" },
        { name: "maxTotalMintableByWallet", type: "uint256" },
        { name: "startTime", type: "uint256" },
        { name: "endTime", type: "uint256" },
        { name: "dropStageIndex", type: "uint256" },
        { name: "maxTokenSupplyForStage", type: "uint256" },
        { name: "feeBps", type: "uint256" },
        { name: "restrictFeeRecipients", type: "bool" },
      ],
    };
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy("", "", admin.address, [
      seadrop.address,
    ]);

    // Configure token
    await token.setMaxSupply(100);
    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);

    mintParams = {
      mintPrice: 100, // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 1000,
      restrictFeeRecipients: false,
    };

    // Add signer
    await token.updateSigner(seadrop.address, signer.address, true);
  });

  const signMint = async (
    nftContract: string,
    minter: Wallet,
    feeRecipient: Wallet,
    mintParams: MintParamsStruct,
    signer: Wallet
  ) => {
    const signedMint = {
      nftContract,
      minter: minter.address,
      feeRecipient: feeRecipient.address,
      mintParams,
    };
    const signature = await signer._signTypedData(
      eip712Domain,
      eip712Types,
      signedMint
    );
    // Verify recovered address matchers signer address
    const verifiedAddress = ethers.utils.verifyTypedData(
      eip712Domain,
      eip712Types,
      signedMint,
      signature
    );
    expect(verifiedAddress).to.eq(signer.address);
    return signature;
  };

  it("Should mint a signed mint", async () => {
    // Mint signed with payer for minter.
    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      signer
    );

    const value = BigNumber.from(mintParams.mintPrice).mul(3);
    await expect(
      seadrop
        .connect(payer)
        .mintSigned(
          token.address,
          feeRecipient.address,
          minter.address,
          3,
          mintParams,
          signature,
          {
            value,
          }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        payer.address,
        3, // mint quantity
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    let minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);

    // Mint signed with minter being payer.
    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          3,
          mintParams,
          signature,
          { value }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        3, // mint quantity
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(6);
    expect(await token.totalSupply()).to.eq(6);
  });

  it("Should not mint a signed mint with a different params", async () => {
    const signature = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      signer
    );

    // Test with different minter address
    const value = BigNumber.from(mintParams.mintPrice).mul(3);
    await expect(
      seadrop.connect(payer).mintSigned(
        token.address,
        feeRecipient.address,
        payer.address, // payer different than minter
        3,
        mintParams,
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Test with different fee recipient
    await expect(
      seadrop.connect(payer).mintSigned(
        token.address,
        payer.address, // payer instead of feeRecipient
        minter.address,
        3,
        mintParams,
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Test with different token contract
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    const token2 = await ERC721SeaDrop.deploy("", "", admin.address, [
      seadrop.address,
    ]);
    await token2.setMaxSupply(100);
    await token2.updateCreatorPayoutAddress(seadrop.address, creator.address);
    await token2.updateSigner(seadrop.address, signer.address, true);
    await expect(
      seadrop.connect(payer).mintSigned(
        token2.address, // different token contract
        feeRecipient.address,
        minter.address,
        3,
        mintParams,
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Test with signer that is not allowed
    const signer2 = new ethers.Wallet(randomHex(32), provider);
    token.updateSigner(seadrop.address, signer2.address, false);
    expect(
      await seadrop.getSignerIsAllowed(token.address, signer2.address)
    ).to.eq(false);
    expect(await seadrop.getSigners(token.address)).to.deep.eq([
      signer.address,
    ]);
    const signature2 = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      signer2
    );
    await expect(
      seadrop.connect(payer).mintSigned(
        token.address,
        feeRecipient.address,
        minter.address,
        3,
        mintParams,
        signature2, // different signature
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Test with different mint params
    const differentMintParams = {
      ...mintParams,
      maxTokenSupplyForStage: 10000,
    };
    await expect(
      seadrop.connect(payer).mintSigned(
        token.address, // different token contract
        feeRecipient.address,
        minter.address,
        3,
        differentMintParams,
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");
  });

  it("Should not mint a signed mint after exceeding max mints per wallet.", async () => {
    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      signer
    );

    // Max mints per wallet is 10. Mint 10
    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          10,
          mintParams,
          signature,
          {
            value: BigNumber.from(mintParams.mintPrice).mul(10),
          }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        10, // mint quantity
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    // Try to mint one more.
    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          1,
          mintParams,
          signature,
          { value: mintParams.mintPrice }
        )
    ).to.be.revertedWith("MintQuantityExceedsMaxMintedPerWallet");

    // Try to mint one more with manipulated mintParams.
    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          1,
          { ...mintParams, maxTotalMintableByWallet: 11 },
          signature,
          { value: mintParams.mintPrice }
        )
    ).to.be.revertedWith("InvalidSignature");
  });
});
