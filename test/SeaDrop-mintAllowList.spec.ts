import { expect } from "chai";
import { randomInt } from "crypto";
import { keccak256 } from "ethers/lib/utils";
import { ethers, network } from "hardhat";
import { MerkleTree } from "merkletreejs";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { IERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type { MintParamsStruct } from "../typechain-types/src/SeaDrop";
import type { Wallet } from "ethers";

const allowListElementsBuffer = async (
  leaves: Array<[minter: string, mintParams: MintParamsStruct]>
) =>
  Promise.all(
    leaves.map(async ([minter, mintParams]) =>
      Buffer.concat([
        Buffer.from(
          ethers.BigNumber.from(minter)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.mintPrice)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.maxTotalMintableByWallet)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.startTime)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.endTime)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.dropStageIndex)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.maxTokenSupplyForStage)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.feeBps)
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(
            mintParams.restrictFeeRecipients === true ? 1 : 0
          )
            .toHexString()
            .slice(2)
            .padStart(64, "0"),
          "hex"
        ),
      ])
    )
  );

describe(`SeaDrop - Mint Allow List (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: IERC721SeaDrop;
  let creator: Wallet;
  let owner: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let feeBps: number;

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
    });
  });

  before(async () => {
    // Set the wallets.
    owner = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets.
    await faucet(owner.address, provider);
    await faucet(minter.address, provider);

    // Deploy Seadrop.
    const SeaDrop = await ethers.getContractFactory("SeaDrop");
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token.
    const SeaDropToken = await ethers.getContractFactory("ERC721SeaDrop");
    token = await SeaDropToken.deploy("", "", owner.address, [seadrop.address]);

    // Set a random feeBps.
    feeBps = randomInt(1, 10000);

    // Update the fee recipient and creator payout address for the token.
    await token.setMaxSupply(1000);
    await token
      .connect(owner)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true);

    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);
  });

  it("Should mint to a minter on the allow list", async () => {
    // Declare the mint params for the merkle proof and call to
    // mintAllowList
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: feeBps,
      restrictFeeRecipients: false,
    };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet)
    );

    // Encode the minter address and mintParams to a buffer to pass
    // to MerkleTree
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    // Store the merkle root.
    const root = merkleTree.getHexRoot();

    // Get the leaf at index 0.
    const leaf = merkleTree.getLeaf(0);

    // Get the proof of the leaf to pass into the transaction.
    const proof = merkleTree.getHexProof(leaf);

    // Declare the allow list data.
    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };

    // Update the allow list of the token.
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the value to send with the mint transaction.
    const mintValue = parseInt(mintParams.mintPrice) * mintQuantity;

    // Mint the allow list stage to the minter and verify
    // the expected event was emitted.
    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          proof,
          { value: mintValue }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        mintQuantity,
        ethers.BigNumber.from(mintParams.mintPrice),
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should mint a free mint allow list stage", async () => {
    const mintParams = {
      mintPrice: "0",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: feeBps,
      restrictFeeRecipients: false,
    };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    const root = merkleTree.getHexRoot();

    const leaf = merkleTree.getLeaf(0);

    const proof = merkleTree.getHexProof(leaf);

    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          proof
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        mintQuantity,
        ethers.BigNumber.from(mintParams.mintPrice),
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should mint an allow list stage with a different payer than minter", async () => {
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: 100,
      restrictFeeRecipients: false,
    };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    const root = merkleTree.getHexRoot();

    const leaf = merkleTree.getLeaf(0);

    const proof = merkleTree.getHexProof(leaf);

    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the value to send with the mint transaction.
    const mintValue = parseInt(mintParams.mintPrice) * mintQuantity;

    // Mint an allow list stage with a different payer than minter.
    await expect(
      seadrop
        .connect(owner)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          proof,
          { value: mintValue }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        owner.address,
        mintQuantity,
        ethers.BigNumber.from(mintParams.mintPrice),
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should revert if the minter is not on the allow list", async () => {
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: feeBps,
      restrictFeeRecipients: false,
    };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    const root = merkleTree.getHexRoot();

    const leaf = merkleTree.getLeaf(0);

    const proof = merkleTree.getHexProof(leaf);

    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the value to send with the mint transaction.
    const mintValue = parseInt(mintParams.mintPrice) * mintQuantity;

    const nonMinter = new ethers.Wallet(randomHex(32), provider);

    await expect(
      seadrop
        .connect(owner)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          nonMinter.address,
          mintQuantity,
          mintParams,
          proof,
          { value: mintValue }
        )
    ).to.be.revertedWith("InvalidProof()");
  });

  it("Should not mint an allow list stage with a different fee recipient", async () => {
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: feeBps,
      restrictFeeRecipients: true,
    };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    const root = merkleTree.getHexRoot();

    const leaf = merkleTree.getLeaf(0);

    const proof = merkleTree.getHexProof(leaf);

    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the value to send with the mint transaction.
    const mintValue = parseInt(mintParams.mintPrice) * mintQuantity;

    const invalidFeeRecipient = new ethers.Wallet(randomHex(32), provider);

    await expect(
      seadrop
        .connect(owner)
        .mintAllowList(
          token.address,
          invalidFeeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          proof,
          { value: mintValue }
        )
    ).to.be.revertedWith("FeeRecipientNotAllowed()");
  });

  it("Should not mint an allow list stage with a different token contract", async () => {
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: feeBps,
      restrictFeeRecipients: true,
    };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    const root = merkleTree.getHexRoot();

    const leaf = merkleTree.getLeaf(0);

    const proof = merkleTree.getHexProof(leaf);

    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the value to send with the mint transaction.
    const mintValue = parseInt(mintParams.mintPrice) * mintQuantity;

    // Deploy a new ERC721SeaDrop.
    const SeaDropToken = await ethers.getContractFactory("ERC721SeaDrop");
    const differentToken = await SeaDropToken.deploy("", "", owner.address, [
      seadrop.address,
    ]);

    // Update the fee recipient and creator payout address for the new token.
    await differentToken.setMaxSupply(1000);
    await differentToken
      .connect(owner)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true);

    await differentToken.updateCreatorPayoutAddress(
      seadrop.address,
      creator.address
    );

    await expect(
      seadrop
        .connect(owner)
        .mintAllowList(
          differentToken.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          proof,
          { value: mintValue }
        )
    ).to.be.revertedWith("InvalidProof()");
  });

  it("Should not mint an allow list stage with different mint params", async () => {
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: feeBps,
      restrictFeeRecipients: true,
    };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    const root = merkleTree.getHexRoot();

    const leaf = merkleTree.getLeaf(0);

    const proof = merkleTree.getHexProof(leaf);

    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    // Create different mint params to include in the mint.
    const differentMintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 50,
      startTime: 1660154484,
      endTime: 1960154490,
      dropStageIndex: 5,
      maxTokenSupplyForStage: 200,
      feeBps: feeBps - 100,
      restrictFeeRecipients: true,
    };

    // Calculate the value to send with the mint transaction.
    const mintValue = parseInt(mintParams.mintPrice) * mintQuantity;

    await expect(
      seadrop
        .connect(owner)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          differentMintParams,
          proof,
          { value: mintValue }
        )
    ).to.be.revertedWith("InvalidProof()");
  });

  it("Should not mint an allow list stage after exceeding max mints per wallet", async () => {
    // Declare the mint params for the merkle proof and call to
    // mintAllowList
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 500,
      feeBps: feeBps,
      restrictFeeRecipients: false,
    };

    // Set a random mintQuantity between 1 and maxTotalMintableByWallet - 1.
    const mintQuantity = randomInt(1, mintParams.maxTotalMintableByWallet - 1);

    // Encode the minter address and mintParams to a buffer to pass
    // to MerkleTree
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    // Store the merkle root.
    const root = merkleTree.getHexRoot();

    // Get the leaf at index 0.
    const leaf = merkleTree.getLeaf(0);

    // Get the proof of the leaf to pass into the transaction.
    const proof = merkleTree.getHexProof(leaf);

    // Declare the allow list data.
    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };

    // Update the allow list of the token.
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the value to send with the mint transaction.
    const mintValue = parseInt(mintParams.mintPrice) * mintQuantity;

    // Mint the allow list stage to the minter and verify
    // the expected event was emitted.
    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          proof,
          { value: mintValue }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        mintQuantity,
        ethers.BigNumber.from(mintParams.mintPrice),
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    const maxTotalalMintableByWalletMintValue =
      parseInt(mintParams.mintPrice) * mintParams.maxTotalMintableByWallet;

    // Attempt to mint the maxTotalMintableByWallet to the minter.
    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams.maxTotalMintableByWallet,
          mintParams,
          proof,
          { value: maxTotalalMintableByWalletMintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxMintedPerWallet(${
        mintParams.maxTotalMintableByWallet + mintQuantity
      }, ${mintParams.maxTotalMintableByWallet})`
    );
  });

  it("Should not mint an allow list stage after exceeding max token supply for stage", async () => {
    // Declare the mint params for the merkle proof and call to
    // mintAllowList
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 50,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 90,
      feeBps: feeBps,
      restrictFeeRecipients: false,
    };

    // Encode the minter address and mintParams to a buffer to pass
    // to MerkleTree
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    // Store the merkle root.
    const root = merkleTree.getHexRoot();

    // Get the leaf at index 0.
    const leaf = merkleTree.getLeaf(0);

    // Get the proof of the leaf to pass into the transaction.
    const proof = merkleTree.getHexProof(leaf);

    // Declare the allow list data.
    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };

    // Update the allow list of the token.
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the cost of minting the maxTotalalMintableByWalletMintValue.
    const maxTotalalMintableByWalletMintValue =
      parseInt(mintParams.mintPrice) * mintParams.maxTotalMintableByWallet;

    // Mint the maxTotalMintableByWallet to the minter and verify
    // the expected event was emitted.
    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams.maxTotalMintableByWallet,
          mintParams,
          proof,
          { value: maxTotalalMintableByWalletMintValue }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        mintParams.maxTotalMintableByWallet,
        ethers.BigNumber.from(mintParams.mintPrice),
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    // Create the second minter that will call the transaction exceeding
    // the drop stage supply.
    const secondMinter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to the second minter's wallet.
    await faucet(secondMinter.address, provider);

    // Attempt to mint the maxTotalMintableByWallet to the minter, exceeding
    // the drop stage supply.
    await expect(
      seadrop
        .connect(secondMinter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          secondMinter.address,
          mintParams.maxTotalMintableByWallet,
          mintParams,
          proof,
          { value: maxTotalalMintableByWalletMintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxTokenSupplyForStage(${
        2 * mintParams.maxTotalMintableByWallet
      }, ${mintParams.maxTokenSupplyForStage})`
    );
  });

  it("Should not mint an allow list stage after exceeding max token supply", async () => {
    // Declare the mint params for the merkle proof and call to
    // mintAllowList
    const mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 50,
      startTime: 1660154484,
      endTime: 1760154484,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 90,
      feeBps: feeBps,
      restrictFeeRecipients: false,
    };

    // Encode the minter address and mintParams to a buffer to pass
    // to MerkleTree
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = new MerkleTree(elementsBuffer, keccak256, {
      hashLeaves: true,
      sortPairs: true,
    });

    // Store the merkle root.
    const root = merkleTree.getHexRoot();

    // Get the leaf at index 0.
    const leaf = merkleTree.getLeaf(0);

    // Get the proof of the leaf to pass into the transaction.
    const proof = merkleTree.getHexProof(leaf);

    // Declare the allow list data.
    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };

    // Update the allow list of the token.
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the cost of minting the maxTotalalMintableByWalletMintValue.
    const maxTotalalMintableByWalletMintValue =
      parseInt(mintParams.mintPrice) * mintParams.maxTotalMintableByWallet;

    // Mint the maxTotalMintableByWallet to the minter and verify
    // the expected event was emitted.
    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintParams.maxTotalMintableByWallet,
          mintParams,
          proof,
          { value: maxTotalalMintableByWalletMintValue }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        mintParams.maxTotalMintableByWallet,
        ethers.BigNumber.from(mintParams.mintPrice),
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    // Create the second minter that will call the transaction exceeding
    // the drop stage supply.
    const secondMinter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to the second minter's wallet.
    await faucet(secondMinter.address, provider);

    // Attempt to mint the maxTotalMintableByWallet to the minter, exceeding
    // the drop stage supply.
    await expect(
      seadrop
        .connect(secondMinter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          secondMinter.address,
          mintParams.maxTotalMintableByWallet,
          mintParams,
          proof,
          { value: maxTotalalMintableByWalletMintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxTokenSupplyForStage(${
        2 * mintParams.maxTotalMintableByWallet
      }, ${mintParams.maxTokenSupplyForStage})`
    );
  });
});
