import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers, network } from "hardhat";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";
import { whileImpersonating } from "./utils/impersonate";

import type { ERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type { SignedMintValidationParamsStruct } from "../typechain-types/src/ERC721SeaDrop";
import type { MintParamsStruct } from "../typechain-types/src/SeaDrop";
import type { Wallet } from "ethers";

describe(`SeaDrop - Mint Signed (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: ERC721SeaDrop;
  let owner: Wallet;
  let creator: Wallet;
  let payer: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let mintParams: MintParamsStruct;
  let signedMintValidationParams: SignedMintValidationParamsStruct;
  let emptySignedMintValidationParams: SignedMintValidationParamsStruct;
  let signer: Wallet;
  let eip712Domain: { [key: string]: string | number };
  let eip712Types: Record<string, Array<{ name: string; type: string }>>;
  let salt: BigNumber;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets
    owner = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    payer = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);
    signer = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets
    for (const wallet of [owner, payer, minter]) {
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
        { name: "salt", type: "uint256" },
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

    emptySignedMintValidationParams = {
      minMintPrice: 0,
      maxMaxTotalMintableByWallet: 0,
      minStartTime: 0,
      maxEndTime: 0,
      maxMaxTokenSupplyForStage: 0,
      minFeeBps: 0,
      maxFeeBps: 0,
    };

    signedMintValidationParams = {
      minMintPrice: 1,
      maxMaxTotalMintableByWallet: 11,
      minStartTime: 50,
      maxEndTime: "100000000000",
      maxMaxTokenSupplyForStage: 10000,
      minFeeBps: 1,
      maxFeeBps: 9000,
    };
  });

  beforeEach(async () => {
    // Deploy token
    const ERC721SeaDrop = await ethers.getContractFactory(
      "ERC721SeaDrop",
      owner
    );
    token = await ERC721SeaDrop.deploy("", "", [seadrop.address]);

    // Configure token
    await token.setMaxSupply(100);
    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);
    await token.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      true
    );

    mintParams = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 100,
      feeBps: 1000,
      restrictFeeRecipients: true,
    };

    // Add signer.
    await token.updateSignedMintValidationParams(
      seadrop.address,
      signer.address,
      signedMintValidationParams
    );

    // Set a random salt.
    salt = BigNumber.from(randomHex(32));
  });

  const signMint = async (
    nftContract: string,
    minter: Wallet,
    feeRecipient: Wallet,
    mintParams: MintParamsStruct,
    salt: BigNumber,
    signer: Wallet
  ) => {
    const signedMint = {
      nftContract,
      minter: minter.address,
      feeRecipient: feeRecipient.address,
      mintParams,
      salt,
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
    let signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
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
          salt,
          signature,
          {
            value,
          }
        )
    ).to.be.revertedWith("PayerNotAllowed");

    // Allow the payer.
    await token.updatePayer(seadrop.address, payer.address, true);

    await expect(
      seadrop
        .connect(payer)
        .mintSigned(
          token.address,
          feeRecipient.address,
          minter.address,
          3,
          mintParams,
          salt,
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

    // Ensure a signature can only be used once.
    // Mint again with the same params.
    await expect(
      seadrop
        .connect(payer)
        .mintSigned(
          token.address,
          feeRecipient.address,
          minter.address,
          3,
          mintParams,
          salt,
          signature,
          {
            value,
          }
        )
    ).to.be.revertedWith("SignatureAlreadyUsed()");

    // Mint signed with minter being payer.
    // Change the salt to use a new digest.
    const newSalt = salt.add(1);
    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      newSalt,
      signer
    );
    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          3,
          mintParams,
          newSalt,
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

  it("Should not mint a signed mint with different params", async () => {
    const signature = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      salt,
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
        salt,
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Test with different fee recipient
    await token.updateAllowedFeeRecipient(seadrop.address, payer.address, true);
    await token.updatePayer(seadrop.address, payer.address, true);
    await expect(
      seadrop.connect(payer).mintSigned(
        token.address,
        payer.address, // payer instead of feeRecipient
        minter.address,
        3,
        mintParams,
        salt,
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
    const token2 = await ERC721SeaDrop.deploy("", "", [seadrop.address]);
    await token2.setMaxSupply(100);
    await token2.updateCreatorPayoutAddress(seadrop.address, creator.address);
    await token2.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      true
    );

    // Test coverage for error SignerNotPresent()
    await whileImpersonating(
      token2.address,
      provider,
      async (impersonatedSigner) => {
        await expect(
          seadrop
            .connect(impersonatedSigner)
            .updateSignedMintValidationParams(
              `0x${"8".repeat(40)}`,
              emptySignedMintValidationParams
            )
        ).to.be.revertedWith("SignerNotPresent()");
      }
    );

    await token2.updateSignedMintValidationParams(
      seadrop.address,
      signer.address,
      signedMintValidationParams
    );
    await expect(
      seadrop.connect(payer).mintSigned(
        token2.address, // different token contract
        feeRecipient.address,
        ethers.constants.AddressZero,
        3,
        mintParams,
        salt,
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Test with signer that is not allowed
    const signer2 = new ethers.Wallet(randomHex(32), provider);
    await token.updateSignedMintValidationParams(
      seadrop.address,
      signer2.address,
      signedMintValidationParams
    );

    await token.updateSignedMintValidationParams(
      seadrop.address,
      signer2.address,
      emptySignedMintValidationParams
    );
    expect(
      await seadrop.getSignedMintValidationParams(
        token.address,
        signer2.address
      )
    ).to.deep.eq([BigNumber.from(0), 0, 0, 0, 0, 0, 0]);
    expect(await seadrop.getSigners(token.address)).to.deep.eq([
      signer.address,
    ]);
    const signature2 = await signMint(
      token.address,
      minter, // sign mint for minter
      feeRecipient,
      mintParams,
      salt,
      signer2
    );
    await expect(
      seadrop.connect(payer).mintSigned(
        token.address,
        feeRecipient.address,
        ethers.constants.AddressZero,
        3,
        mintParams,
        salt,
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
      seadrop.connect(minter).mintSigned(
        token.address, // different token contract
        feeRecipient.address,
        minter.address,
        3,
        differentMintParams,
        salt,
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Test with different salt
    await expect(
      seadrop.connect(minter).mintSigned(
        token.address, // different token contract
        feeRecipient.address,
        minter.address,
        3,
        mintParams,
        salt.sub(1),
        signature,
        {
          value,
        }
      )
    ).to.be.revertedWith("InvalidSignature");

    // Ensure that the zero address cannot be added as a signer.
    await expect(
      token.updateSignedMintValidationParams(
        seadrop.address,
        ethers.constants.AddressZero,
        signedMintValidationParams
      )
    ).to.be.revertedWith("SignerCannotBeZeroAddress()");

    // Remove the original signer for branch coverage.
    await token.updateSignedMintValidationParams(
      seadrop.address,
      signer.address,
      emptySignedMintValidationParams
    );
    expect(
      await seadrop.getSignedMintValidationParams(token.address, signer.address)
    ).to.deep.eq([BigNumber.from(0), 0, 0, 0, 0, 0, 0]);

    // Add two signers and remove the second for branch coverage.
    await token.updateSignedMintValidationParams(
      seadrop.address,
      signer.address,
      signedMintValidationParams
    );
    await token.updateSignedMintValidationParams(
      seadrop.address,
      signer2.address,
      signedMintValidationParams
    );
    await token.updateSignedMintValidationParams(
      seadrop.address,
      signer2.address,
      emptySignedMintValidationParams
    );
    expect(
      await seadrop.getSignedMintValidationParams(token.address, signer.address)
    ).to.deep.eq([BigNumber.from(1), 11, 50, 100000000000, 10000, 1, 9000]);
    expect(
      await seadrop.getSignedMintValidationParams(
        token.address,
        signer2.address
      )
    ).to.deep.eq([BigNumber.from(0), 0, 0, 0, 0, 0, 0]);
  });

  it("Should not mint a signed mint after exceeding max mints per wallet.", async () => {
    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParams,
      salt,
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
          salt,
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
          salt,
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
          salt,
          signature,
          { value: mintParams.mintPrice }
        )
    ).to.be.revertedWith("InvalidSignature");
  });

  it("Should mint a signed mint with fee amount that rounds down to zero", async () => {
    const mintParamsZeroFee = { ...mintParams, mintPrice: 1, feeBps: 1 };

    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParamsZeroFee,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          minter.address,
          3,
          mintParamsZeroFee,
          salt,
          signature,
          {
            value: 3,
          }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        3, // mint quantity
        mintParamsZeroFee.mintPrice,
        mintParamsZeroFee.feeBps,
        mintParams.dropStageIndex
      );

    const minterBalance = await token.balanceOf(minter.address);
    expect(minterBalance).to.eq(3);
    expect(await token.totalSupply()).to.eq(3);
  });

  it("Should not mint with invalid fee bps", async () => {
    const mintParamsInvalidFeeBps = { ...mintParams, feeBps: 11_000 };

    const signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      mintParamsInvalidFeeBps,
      salt,
      signer
    );

    const value = BigNumber.from(mintParams.mintPrice);
    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          1,
          mintParamsInvalidFeeBps,
          salt,
          signature,
          {
            value,
          }
        )
    ).to.be.revertedWith("InvalidSignedFeeBps");
  });

  it("Should not mint a signed mint that violates the validation params", async () => {
    let newMintParams: any = { ...mintParams, mintPrice: 0 };

    let signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          2,
          newMintParams,
          salt,
          signature,
          {
            value: 0, // testing free mint price
          }
        )
    ).to.be.revertedWith(
      `InvalidSignedMintPrice(${newMintParams.mintPrice}, ${signedMintValidationParams.minMintPrice})`
    );

    newMintParams = { ...mintParams, maxTotalMintableByWallet: 12 };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    const mintQuantity = 2;
    const value = BigNumber.from(newMintParams.mintPrice).mul(mintQuantity);

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          newMintParams,
          salt,
          signature,
          { value }
        )
    ).to.be.revertedWith(
      `InvalidSignedMaxTotalMintableByWallet(${newMintParams.maxTotalMintableByWallet}, ${signedMintValidationParams.maxMaxTotalMintableByWallet})`
    );

    newMintParams = { ...mintParams, startTime: 30 };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          newMintParams,
          salt,
          signature,
          { value }
        )
    ).to.be.revertedWith(
      `InvalidSignedStartTime(${newMintParams.startTime}, ${signedMintValidationParams.minStartTime})`
    );

    newMintParams = {
      ...mintParams,
      endTime: BigNumber.from(signedMintValidationParams.maxEndTime).add(1),
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          newMintParams,
          salt,
          signature,
          { value }
        )
    ).to.be.revertedWith(
      `InvalidSignedEndTime(${newMintParams.endTime}, ${signedMintValidationParams.maxEndTime})`
    );

    newMintParams = {
      ...mintParams,
      maxTokenSupplyForStage: 10001,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          newMintParams,
          salt,
          signature,
          { value }
        )
    ).to.be.revertedWith(
      `InvalidSignedMaxTokenSupplyForStage(${newMintParams.maxTokenSupplyForStage}, ${signedMintValidationParams.maxMaxTokenSupplyForStage})`
    );

    newMintParams = {
      ...mintParams,
      feeBps: 0,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          newMintParams,
          salt,
          signature,
          { value }
        )
    ).to.be.revertedWith(
      `InvalidSignedFeeBps(${newMintParams.feeBps}, ${signedMintValidationParams.minFeeBps})`
    );

    newMintParams = {
      ...mintParams,
      feeBps: 9010,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          newMintParams,
          salt,
          signature,
          { value }
        )
    ).to.be.revertedWith(
      `InvalidSignedFeeBps(${newMintParams.feeBps}, ${signedMintValidationParams.maxFeeBps})`
    );

    newMintParams = {
      ...mintParams,
      restrictFeeRecipients: false,
    };

    signature = await signMint(
      token.address,
      minter,
      feeRecipient,
      newMintParams,
      salt,
      signer
    );

    await expect(
      seadrop
        .connect(minter)
        .mintSigned(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          newMintParams,
          salt,
          signature,
          { value }
        )
    ).to.be.revertedWith(`SignedMintsMustRestrictFeeRecipients()`);

    expect(await token.totalSupply()).to.eq(0);
  });

  it("Should not update SignedMintValidationParams with invalid fee bps", async () => {
    await expect(
      token.updateSignedMintValidationParams(seadrop.address, signer.address, {
        ...signedMintValidationParams,
        minFeeBps: 11_000,
      })
    ).to.be.revertedWith(`InvalidFeeBps(11000)`);

    await expect(
      token.updateSignedMintValidationParams(seadrop.address, signer.address, {
        ...signedMintValidationParams,
        maxFeeBps: 12_000,
      })
    ).to.be.revertedWith(`InvalidFeeBps(12000)`);
  });
});
