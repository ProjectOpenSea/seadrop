import { Contract, Signer } from "ethers";
import { ethers, upgrades } from "hardhat";
import { SeaDrop } from "../../../typechain-types/src";
import { ISeaDrop } from "../../../typechain-types/src/interfaces";
import CollectionConfig from "../../config/CollectionConfig";
import { seadropAddress, tokenName, tokenSymbol } from "../../config/constants";

export const deployContract = async () => {
  const [owner, externalAccount, nonHolder]: Signer[] =
    await ethers.getSigners();


  // Deploy Seadrop Upgradeable
  //const SeaDrop = await ethers.getContractFactory("ERC721SeaDropUpgradeable", owner);
  // const SeaDrop = await ethers.getContractFactory("Seadrop", owner);
  // const seadrop = await SeaDrop.deploy() as ISeaDropUpgradeable;
  // Deploy SeaDrop

  const SeaDrop = await ethers.getContractFactory("ERC721SeaDropUpgradeable", owner);
  const seadrop = await SeaDrop.deploy() as SeaDrop;
  console.info(`deployed ERC721SeaDropUpgradeable as seadrop address ${seadrop.address} with owner: ${await owner.getAddress()}`);
  await seadrop.deployed();


  const NFTFactory = await ethers.getContractFactory(tokenName);
  console.info(`NFTFactory for ${tokenName}  with name: ${tokenName} sym: ${tokenSymbol} seadrop: ${seadrop.address}`);
  const nft = await upgrades.deployProxy(
    NFTFactory,
    [
      tokenName,
      tokenSymbol,
      [seadrop.address]
    ],
    {
      initializer: "initialize"
    }
  );
  console.info(`deploying ${tokenName}`);
  await nft.deployed();
  console.warn(`deployed contract proxy to ${nft.address} symbol: ${await nft.symbol()} name: ${await nft.name()} seadrop: ${seadrop.address}`);
  const addresses = {
    proxy: nft.address,
    admin: await upgrades.erc1967.getAdminAddress(nft.address),
    implementation: await upgrades.erc1967.getImplementationAddress(
      nft.address
    )
  };

  let ownerAddress = await owner.getAddress();
  // console.info(`updateCreatorPayoutAddress to seadrop: ${seadropAddress} creator: ${ownerAddress}`);
  //
  // // This fails for some reason
  // // await nft.updateCreatorPayoutAddress(seadropAddress, owner.getAddress());
  // console.info("updated creator payout address");


  return {
    seadrop,
    nft,
    owner,
    ownerAddress: ownerAddress,
    externalAccount,
    externalAccountAddress: await externalAccount.getAddress(),
    nonHolder,
    nonHolderAddress: await nonHolder.getAddress(),
    addresses
  };
};

async function  initUpgradableContract(contractAddress: string) {
  if (contractAddress == null) {
    console.error("no contract address configured. maybe contract not deployed?")
  }
  console.info(`initializing contract for address: ${contractAddress} name: ${CollectionConfig.contractName}`)
  return await ethers.getContractAt(CollectionConfig.contractName, contractAddress!);
}


export const instantiateSeadropContract = async (seadropAddress: string) => {
  if (seadropAddress == null) {
    console.error("seadrop contract address configured. maybe contract not deployed?")
  }
  console.info(`initializing seadrop contract for address: ${seadropAddress}`)
  //return await ethers.getContractAt("SeaDrop", seadropAddress);
  const [owner]: Signer[] =
    await ethers.getSigners();
  return await ethers.getContractAt("SeaDrop", seadropAddress);
  //return await ethers.getContractAt("SeaDrop", seadropAddress, owner) as ISeaDrop;

}
export const instantiateContract = async () => {
  const [owner, externalAccount, nonHolder]: Signer[] =
    await ethers.getSigners();

  const nft = await initUpgradableContract(CollectionConfig.contractAddress!);
  console.info(`instantiated nft contract: ${await nft.name()}  ${await nft.symbol()}`);
  let ownerAddress = await owner.getAddress();
  //await nft.updateCreatorPayoutAddress(seadropAddress, owner.getAddress());
  return {
    nft,
    owner,
    ownerAddress: ownerAddress,
    externalAccount,
    nonHolder,
  };
};


export const getTokenUri = async (nft: Contract, owner: Signer, tokenId: number) => {
  const tokenUri = await nft
    .connect(owner)
    .tokenURI(tokenId);
  console.log(`tokenUri for ${tokenId} = ${tokenUri}`);
  return tokenUri;
}
