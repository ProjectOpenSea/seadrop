import { expect } from "chai";
import { keccak256 } from "ethers/lib/utils";
import { ethers, network } from "hardhat";
import { MerkleTree } from "merkletreejs";

import { randomHex } from "./utils/encoding";
import { faucet } from "./utils/faucet";
import { VERSION } from "./utils/helpers";

import type { IERC721SeaDrop, ISeaDrop } from "../typechain-types";
import type {
  MintParamsStruct,
  AllowListDataStruct,
} from "../typechain-types/src/SeaDrop";
import type { Wallet, BigNumber } from "ethers";

const allowListElements = async (
  leaves: Array<[minter: string, mintParams: MintParamsStruct]>
) =>
  Promise.all(
    leaves.map(async ([minter, mintParams]) => [
      minter,
      await mintParams.mintPrice,
      await mintParams.maxTotalMintableByWallet,
      await mintParams.startTime,
      await mintParams.endTime,
      await mintParams.dropStageIndex,
      await mintParams.maxTokenSupplyForStage,
      await mintParams.feeBps,
      (await mintParams.restrictFeeRecipients) === true ? 1 : 0,
    ])
  );

describe(`Mint Allow List (v${VERSION})`, function () {
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

    // Deploy Seadrop.
    const SeaDrop = await ethers.getContractFactory("SeaDrop");
    seadrop = await SeaDrop.deploy();

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
    const minter = `0x${"1".repeat(40)}`;
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

    const elements = await allowListElements([[minter, mintParams]]);

    const merkleTree = new MerkleTree(elements, keccak256, {
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
      await seadrop.mintAllowList(
        token.address,
        feeRecipient.address,
        minter,
        3,
        mintParams,
        proof
      )
    ).to.be.true;
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

    // const elements = await allowListElements([[minter, mintParams]]);

    const elementsBuffer = [
      Buffer.concat([
        Buffer.from(minter.address.slice(2), "hex"),
        Buffer.from(
          ethers.BigNumber.from(mintParams.mintPrice).toHexString().slice(2),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.maxTotalMintableByWallet)
            .toHexString()
            .slice(2),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.startTime).toHexString().slice(2),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.endTime).toHexString().slice(2),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.dropStageIndex)
            .toHexString()
            .slice(2),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.maxTokenSupplyForStage)
            .toHexString()
            .slice(2),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(mintParams.feeBps).toHexString().slice(2),
          "hex"
        ),
        Buffer.from(
          ethers.BigNumber.from(
            mintParams.restrictFeeRecipients === true ? 1 : 0
          )
            .toHexString()
            .slice(2),
          "hex"
        ),
      ]),
    ];

    console.log(elementsBuffer);

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
      seadrop.mintAllowList(
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
        deployer.address,
        1,
        10000000000000,
        0,
        1
      );
  });

  // it("Should revert if the minter is not on the allow list", async () => {});
});
