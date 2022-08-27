import { expect } from "chai";
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
  let deployer: Wallet;
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
    deployer = new ethers.Wallet(randomHex(32), provider);
    creator = new ethers.Wallet(randomHex(32), provider);
    minter = new ethers.Wallet(randomHex(32), provider);
    feeRecipient = new ethers.Wallet(randomHex(32), provider);

    // Add eth to wallets.
    await faucet(deployer.address, provider);
    await faucet(minter.address, provider);

    // Deploy Seadrop.
    const SeaDrop = await ethers.getContractFactory("SeaDrop");
    seadrop = await SeaDrop.deploy();
  });

  beforeEach(async () => {
    // Deploy token.
    const SeaDropToken = await ethers.getContractFactory("ERC721SeaDrop");
    token = await SeaDropToken.deploy("", "", deployer.address, [
      seadrop.address,
    ]);

    // Update the fee recipient and creator payout address for the token.
    await token.setMaxSupply(100);
    await token
      .connect(deployer)
      .updateAllowedFeeRecipient(seadrop.address, feeRecipient.address, true);

    await token.updateCreatorPayoutAddress(seadrop.address, creator.address);
  });

  // TODO: Test for MintQuantityExceedsMaxTokenSupplyForStage

  it("Should mint an allow list stage", async () => {
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

    expect(
      await seadrop
        .connect(minter)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          3,
          mintParams,
          proof,
          { value: 30000000000000 }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        minter.address,
        3,
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
      feeBps: 100,
      restrictFeeRecipients: false,
    };

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
          3,
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
        3,
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

    const elementsBuffer = [
      Buffer.concat([
        Buffer.from(
          ethers.BigNumber.from(minter.address)
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
      ]),
    ];

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

    // Mint an allow list stage with a different payer than minter.
    expect(
      await seadrop
        .connect(deployer)
        .mintAllowList(
          token.address,
          feeRecipient.address,
          minter.address,
          3,
          mintParams,
          proof,
          { value: 30000000000000 }
        )
    )
      .to.emit(seadrop, "SeaDropMint")
      .withArgs(
        token.address,
        minter.address,
        feeRecipient.address,
        deployer.address,
        3,
        ethers.BigNumber.from(mintParams.mintPrice),
        mintParams.feeBps,
        mintParams.dropStageIndex
      );
  });

  // it("Should revert if the minter is not on the allow list", async () => {});
});
