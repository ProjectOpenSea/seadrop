import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import {} from "../../typechain-types";
import type { PublicDropStruct } from "../../typechain-types/src/ERC721SeaDrop";
import { AllowListDataStruct, WalterTheRabbit } from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { MAX_SUPPLY, seadropAddress } from "../config/constants";
import { getTokenUri, instantiateContract } from "./__fixtures__/base";

describe("Sepolia Token (Mint)", function() {
  let nft: WalterTheRabbit;
  let owner: Signer;
  let ownerAddress: string;
  let externalAccount: Signer;
  let externalAccountAddress: string;
  const mintPrice = ethers.utils.parseEther("0.01");

  before(async () => {
    const {
      nft: _nft,
      owner: _owner,
      ownerAddress: _ownerAddress,
      externalAccount: _externalAccount
    } = await instantiateContract();

    nft = _nft as WalterTheRabbit;
    owner = _owner;
    ownerAddress = _ownerAddress;
    externalAccount = _externalAccount;
  });

  it("sepolia set contract supply", async () => {
    console.info(`set contract supply ${MAX_SUPPLY}`);
    await nft
      .connect(owner)
      .setMaxSupply(MAX_SUPPLY);
    expect(await nft.maxSupply()).to.equal(MAX_SUPPLY);
  });


  it("sepolia set base uri", async () => {
    console.info(`set base uri ${CollectionConfig.publicMetadataUri}`);
    if (await nft.baseURI() == CollectionConfig.publicMetadataUri) {
      console.info(`already set`);
      return;
    }
    await nft
      .connect(owner)
      .setBaseURI(CollectionConfig.publicMetadataUri);
    expect(await nft.baseURI()).to.equal(CollectionConfig.publicMetadataUri);

    await nft
      .connect(owner)
      .setContractURI(CollectionConfig.contractMetadataUri);
    expect(await nft.contractURI()).to.equal(CollectionConfig.contractMetadataUri);

  });

  it("sepolia set public drop data", async () => {
    const publicDrop = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 100,
      feeBps: 1000,
      restrictFeeRecipients: true
    };
    console.info(`set public drop data ${JSON.stringify(publicDrop)}`);
    await nft.connect(owner).updatePublicDrop(seadropAddress, publicDrop);
  });

  it("sepolia check public drop data", async () => {
    // const publicDrop = await nft.connect(owner).getPublicDrop(seadropAddress, publicDrop);
    // console.info(`check public drop data ${JSON.stringify(publicDrop)}`);
  });

  it("sepolia update allowlist", async () => {
    const allowListData: AllowListDataStruct = {
      allowListURI: "3",
      merkleRoot: "blabla",
      publicKeyURIs: ["f"]
    };
    //await nft.connect(owner).updateAllowList(seadropAddress, allowListData)
  });

  it("sepolia check max supply", async () => {
    console.info(`check max supply`);
    expect(await nft.maxSupply()).to.equal(MAX_SUPPLY);

    expect(await nft.baseURI()).to.equal(CollectionConfig.publicMetadataUri);
  });

  it("sepolia mints token with invalid amount", async () => {
    console.info(`mint with invalid amount ${ownerAddress}`);
    await expect(
      nft
        .connect(owner)
        .mint(seadropAddress, 1, ownerAddress, { value: mintPrice.div(2).toString() })
    ).to.be.revertedWith("Invalid ETH Amount");
  });

  it("sepolia mints one token", async () => {

    const balanceBefore = await nft.balanceOf(ownerAddress);
    console.info(`mint with valid amount to owner: ${ownerAddress} with seadrop address: ${seadropAddress}`);
    const transaction = await nft
      .connect(owner)
      .mint(seadropAddress, 1, ownerAddress, { value: mintPrice.toString() });

    console.log(`mint transaction details ${transaction.value} hash: ${transaction.hash}. Waiting for confirmations...`);
    await transaction.wait(2);

    const tokenUri = await getTokenUri(nft, owner, 1);
    console.log(`tokenUri ${tokenUri}`);

    // check the balance (this can fail in test/mainnet as it takes some time for confirmation)
    const value: BigNumber = balanceBefore.add(BigNumber.from(1));
    expect(await nft.balanceOf(ownerAddress)).to.equal(value);
  });

  it("sepolia mints one freeToken for owner", async () => {

    const balanceBefore = await nft.balanceOf(ownerAddress);
    console.info(`mint free token to owner: ${ownerAddress} with seadrop address: ${seadropAddress}`);
    const zeroBM = BigNumber.from(0);
    const transaction = await nft
      .connect(owner)
      .mint(seadropAddress, 1, ownerAddress, { value: zeroBM.toString() });

    console.log(`free mint transaction details ${transaction.value} hash: ${transaction.hash}. Waiting for confirmations...`);
    await transaction.wait(2);

    const maxSupply = await nft.maxSupply();
    const totalSupply = await nft.totalSupply();
    const tokenUri = await getTokenUri(nft, owner, totalSupply + 1); //FIXME will fail when sold out
    console.log(`tokenUri ${tokenUri}`);

    // check the balance (this can fail in test/mainnet as it takes some time for confirmation)
    const value: BigNumber = balanceBefore.add(BigNumber.from(1));
    expect(await nft.balanceOf(ownerAddress)).to.equal(value);
  });
});
