import { expect } from "chai";
import { randomInt } from "crypto";
import { keccak256 } from "ethers/lib/utils";
import { ethers, network } from "hardhat";
import { MerkleTree } from "merkletreejs";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { INonFungibleSeaDropToken, ISeaDrop } from "../typechain-types";
import type { MintParamsStruct } from "../typechain-types/src/SeaDrop";
import type { Wallet } from "ethers";

const createMerkleTree = (leaves: Buffer[]) =>
  new MerkleTree(leaves, keccak256, {
    hashLeaves: true,
    sortLeaves: true,
    sortPairs: true,
  });

const toPaddedBuffer = (data: any) =>
  Buffer.from(
    ethers.BigNumber.from(data).toHexString().slice(2).padStart(64, "0"),
    "hex"
  );

const allowListElementsBuffer = (
  leaves: Array<[minter: string, mintParams: MintParamsStruct]>
) =>
  leaves.map(([minter, mintParams]) =>
    Buffer.concat(
      [
        minter,
        mintParams.mintPrice,
        mintParams.maxTotalMintableByWallet,
        mintParams.startTime,
        mintParams.endTime,
        mintParams.dropStageIndex,
        mintParams.maxTokenSupplyForStage,
        mintParams.feeBps,
        mintParams.restrictFeeRecipients ? 1 : 0,
      ].map(toPaddedBuffer)
    )
  );

describe(`SeaDrop - Mint Allow List (v${VERSION})`, function () {
  const { provider } = ethers;
  let seadrop: ISeaDrop;
  let token: INonFungibleSeaDropToken;
  let creator: Wallet;
  let owner: Wallet;
  let minter: Wallet;
  let feeRecipient: Wallet;
  let feeBps: number;
  let mintParams: MintParamsStruct;

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
    for (const wallet of [owner, minter]) {
      await faucet(wallet.address, provider);
    }

    // Deploy Seadrop.
    const SeaDrop = await ethers.getContractFactory("SeaDrop");
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token.
    const SeaDropToken = await ethers.getContractFactory("ERC721SeaDrop");
    token = await SeaDropToken.deploy("", "", [seadrop.address]);

    // Set a random feeBps.
    feeBps = randomInt(1, 10000);

    // Update the fee recipient and creator payout address for the token.
    await token.setMaxSupply(1000);
    await token.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      true
    );

    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);

    // Set the allow list mint params.
    mintParams = {
      mintPrice: "10000000000000",
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      dropStageIndex: 1,
      maxTokenSupplyForStage: 11,
      feeBps,
      restrictFeeRecipients: true,
    };
  });

  it("Should mint to a minter on the allow list", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    // Encode the minter address and mintParams.
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = createMerkleTree(elementsBuffer);

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
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

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
          { value }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        mintQuantity,
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should mint a free mint allow list stage", async () => {
    // Create a mintParams with mintPrice of 0.
    const mintParamsFreeMint = { ...mintParams, mintPrice: 0 };

    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParamsFreeMint.maxTotalMintableByWallet as number)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParamsFreeMint],
    ]);

    const merkleTree = createMerkleTree(elementsBuffer);

    const root = merkleTree.getHexRoot();
    const leaf = merkleTree.getLeaf(0);
    const proof = merkleTree.getHexProof(leaf);

    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };
    await token.updateAllowList(seadrop.address, allowListData);

    expect(await seadrop.getAllowListMerkleRoot(token.address)).to.eq(root);

    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          mintParamsFreeMint,
          proof
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        mintQuantity,
        0, // free
        mintParamsFreeMint.feeBps,
        mintParamsFreeMint.dropStageIndex
      );
  });

  it("Should mint an allow list stage with a different payer than minter", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = createMerkleTree(elementsBuffer);

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
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

    // The payer needs to be allowed first.
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
          { value }
        )
    ).to.be.revertedWith("PayerNotAllowed");

    // Allow the payer.
    await token.updatePayer(seadrop.address, owner.address, true);

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
          { value }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        owner.address, // payer
        mintQuantity,
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  it("Should revert if the minter is not on the allow list", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = createMerkleTree(elementsBuffer);

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
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

    const nonMinter = new ethers.Wallet(randomHex(32), provider);
    await faucet(nonMinter.address, provider);

    await expect(
      seadrop
        .connect(nonMinter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          nonMinter.address,
          mintQuantity,
          mintParams,
          proof,
          { value }
        )
    ).to.be.revertedWith("InvalidProof()");

    await expect(
      seadrop
        .connect(nonMinter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          mintParams,
          proof,
          { value }
        )
    ).to.be.revertedWith("InvalidProof()");
  });

  it("Should not mint an allow list stage with an unknown fee recipient", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = createMerkleTree(elementsBuffer);

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
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

    const invalidFeeRecipient = new ethers.Wallet(randomHex(32), provider);

    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          invalidFeeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          proof,
          { value }
        )
    ).to.be.revertedWith("FeeRecipientNotAllowed()");
  });

  it("Should not mint an allow list stage with a different token contract", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = createMerkleTree(elementsBuffer);

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
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

    // Deploy a new ERC721SeaDrop.
    const SeaDropToken = await ethers.getContractFactory("ERC721SeaDrop");
    const differentToken = await SeaDropToken.deploy("", "", [seadrop.address]);

    // Update the fee recipient and creator payout address for the new token.
    await differentToken.setMaxSupply(1000);
    await differentToken.updateAllowedFeeRecipient(
      seadrop.address,
      feeRecipient.address,
      true
    );

    await differentToken.updateCreatorPayoutAddress(
      seadrop.address,
      creator.address
    );

    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          differentToken.address,
          feeRecipient.address,
          ethers.constants.AddressZero,
          mintQuantity,
          mintParams,
          proof,
          { value }
        )
    ).to.be.revertedWith("InvalidProof()");
  });

  it("Should not mint an allow list stage with different mint params", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    const merkleTree = createMerkleTree(elementsBuffer);

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
      ...mintParams,
      feeBps: (mintParams.feeBps as number) + 100,
    };

    // Calculate the value to send with the mint transaction.
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          differentMintParams,
          proof,
          { value }
        )
    ).to.be.revertedWith("InvalidProof()");
  });

  it("Should not mint an allow list stage after exceeding max mints per wallet", async () => {
    // Set a random mintQuantity between 1 and maxTotalMintableByWallet - 1.
    const mintQuantity = randomInt(
      1,
      (mintParams.maxTotalMintableByWallet as number) - 1
    );

    // Encode the minter address and mintParams.
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = createMerkleTree(elementsBuffer);

    // Store the merkle root.
    const root = merkleTree.getHexRoot();
    const leaf = merkleTree.getLeaf(0);
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
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

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
          { value }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        mintQuantity,
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

    const maxTotalMintableByWalletMintValue = ethers.BigNumber.from(
      mintParams.mintPrice
    ).mul(mintParams.maxTotalMintableByWallet as number);

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
          { value: maxTotalMintableByWalletMintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxMintedPerWallet(${
        (mintParams.maxTotalMintableByWallet as number) + mintQuantity
      }, ${mintParams.maxTotalMintableByWallet})`
    );
  });

  it("Should not mint an allow list stage after exceeding max token supply for stage", async () => {
    // Create the second minter that will call the transaction exceeding
    // the drop stage supply.
    const secondMinter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to the second minter's wallet.
    await faucet(secondMinter.address, provider);

    // Encode the minter address and mintParams.
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
      [secondMinter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = createMerkleTree(elementsBuffer);

    // Store the merkle root.
    const root = merkleTree.getHexRoot();

    // Get the leaves.
    const leafMinter = merkleTree.getLeaf(
      keccak256(elementsBuffer[0]) < keccak256(elementsBuffer[1]) ? 0 : 1
    );
    const leafSecondMinter = merkleTree.getLeaf(
      keccak256(elementsBuffer[0]) < keccak256(elementsBuffer[1]) ? 1 : 0
    );

    // Get the proof of the leaf to pass into the transaction.
    const proofMinter = merkleTree.getHexProof(leafMinter);
    const proofSecondMinter = merkleTree.getHexProof(leafSecondMinter);

    // Declare the allow list data.
    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };

    // Update the allow list of the token.
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the cost of minting the maxTotalMintableByWalletMintValue.
    const maxTotalMintableByWalletMintValue = ethers.BigNumber.from(
      mintParams.mintPrice
    ).mul(mintParams.maxTotalMintableByWallet as number);

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
          proofMinter,
          { value: maxTotalMintableByWalletMintValue }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address, // payer
        mintParams.maxTotalMintableByWallet,
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

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
          proofSecondMinter,
          { value: maxTotalMintableByWalletMintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxTokenSupplyForStage(${
        2 * (mintParams.maxTotalMintableByWallet as number)
      }, ${mintParams.maxTokenSupplyForStage})`
    );
  });

  it("Should not mint an allow list stage after exceeding max token supply", async () => {
    // Update the max supply.
    await token.setMaxSupply(11);

    // Create the second minter that will call the transaction exceeding
    // the drop stage supply.
    const secondMinter = new ethers.Wallet(randomHex(32), provider);

    // Add eth to the second minter's wallet.
    await faucet(secondMinter.address, provider);

    // Encode the minter address and mintParams.
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
      [secondMinter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = createMerkleTree(elementsBuffer);

    // Store the merkle root.
    const root = merkleTree.getHexRoot();

    // Get the leaves.
    const leafMinter = merkleTree.getLeaf(
      keccak256(elementsBuffer[0]) < keccak256(elementsBuffer[1]) ? 0 : 1
    );
    const leafSecondMinter = merkleTree.getLeaf(
      keccak256(elementsBuffer[0]) < keccak256(elementsBuffer[1]) ? 1 : 0
    );

    // Get the proof of the leaf to pass into the transaction.
    const proofMinter = merkleTree.getHexProof(leafMinter);
    const proofSecondMinter = merkleTree.getHexProof(leafSecondMinter);

    // Declare the allow list data.
    const allowListData = {
      merkleRoot: root,
      publicKeyURIs: [],
      allowListURI: "",
    };

    // Update the allow list of the token.
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the cost of minting the maxTotalMintableByWalletMintValue.
    const maxTotalMintableByWalletMintValue = ethers.BigNumber.from(
      mintParams.mintPrice
    ).mul(mintParams.maxTotalMintableByWallet as number);

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
          proofMinter,
          { value: maxTotalMintableByWalletMintValue }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        mintParams.maxTotalMintableByWallet,
        mintParams.mintPrice,
        mintParams.feeBps,
        mintParams.dropStageIndex
      );

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
          proofSecondMinter,
          { value: maxTotalMintableByWalletMintValue }
        )
    ).to.be.revertedWith(
      `MintQuantityExceedsMaxSupply(${
        2 * (mintParams.maxTotalMintableByWallet as number)
      }, 11`
    );
  });

  it("Should not mint with an uninitialized AllowList", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    // Encode the minter address and mintParams.
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParams],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = createMerkleTree(elementsBuffer);

    // Get the leaf at index 0.
    const leaf = merkleTree.getLeaf(0);

    // Get the proof of the leaf to pass into the transaction.
    const proof = merkleTree.getHexProof(leaf);

    // We are skipping updating the allow list, the root should be zero.
    expect(await seadrop.getAllowListMerkleRoot(token.address)).to.eq(
      `0x${"0".repeat(64)}`
    );

    // Calculate the value to send with the mint transaction.
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

    // Mint the allow list stage.
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
          { value }
        )
    ).to.be.revertedWith("InvalidProof()");

    // Try with proof of zero.
    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          mintParams,
          [`0x${"0".repeat(64)}`],
          { value }
        )
    ).to.be.revertedWith("InvalidProof()");
  });

  it("Should not mint with feeBps > 10_000", async () => {
    // Set a random mintQuantity under maxTotalMintableByWallet.
    const mintQuantity = Math.max(
      1,
      randomInt(mintParams.maxTotalMintableByWallet as number)
    );

    const mintParamsInvalidFeeBps = { ...mintParams, feeBps: 10_100 };

    // Encode the minter address and mintParams.
    const elementsBuffer = await allowListElementsBuffer([
      [minter.address, mintParamsInvalidFeeBps],
    ]);

    // Construct a merkle tree from the allow list elements.
    const merkleTree = createMerkleTree(elementsBuffer);

    // Get the leaf at index 0.
    const leaf = merkleTree.getLeaf(0);

    // Get the proof of the leaf to pass into the transaction.
    const proof = merkleTree.getHexProof(leaf);

    // Declare the allow list data.
    const allowListData = {
      merkleRoot: merkleTree.getRoot(),
      publicKeyURIs: [],
      allowListURI: "",
    };

    // Update the allow list of the token.
    await token.updateAllowList(seadrop.address, allowListData);

    // Calculate the value to send with the mint transaction.
    const value = ethers.BigNumber.from(mintParams.mintPrice).mul(mintQuantity);

    // Mint the allow list stage.
    await expect(
      seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          mintQuantity,
          mintParamsInvalidFeeBps,
          proof,
          { value }
        )
    ).to.be.revertedWith("InvalidFeeBps(10100)");
  });
});
