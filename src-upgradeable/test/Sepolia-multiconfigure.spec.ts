import { expect } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import type { PublicDropStruct } from "../../typechain-types/src/ERC721SeaDrop";
import { ERC721SeaDropStructsErrorsAndEventsUpgradeable, WalterTheRabbit } from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { prodCreatorAddress, seadropAddress, testCreatorAddress } from "../config/constants";
import { getAllowListData } from "../src/allowListUtils";
import { instantiateContract } from "./__fixtures__/base";
import { SECONDS_IN_A_DAY } from "./basic.spec";
import MultiConfigureStructStruct = ERC721SeaDropStructsErrorsAndEventsUpgradeable.MultiConfigureStructStruct;



const emptyAllowListData =  {
  merkleRoot: ethers.constants.HashZero,
  publicKeyURIs: [],
  allowListURI: "",
};

const emptyConfig :  MultiConfigureStructStruct = {
  maxSupply: 26,
  baseURI: "",
  contractURI: "",
  seaDropImpl: seadropAddress,
  publicDrop: {
    mintPrice: 0,
    maxTotalMintableByWallet: 0,
    startTime: 0,
    endTime: 0,
    feeBps: 0,
    restrictFeeRecipients: true,
  },
  dropURI: "",
  allowListData: emptyAllowListData,
  creatorPayoutAddress: prodCreatorAddress,
  provenanceHash: ethers.constants.HashZero,
  allowedFeeRecipients: [],
  disallowedFeeRecipients: [],
  allowedPayers: [],
  disallowedPayers: [],
  tokenGatedAllowedNftTokens: [],
  tokenGatedDropStages: [],
  disallowedTokenGatedAllowedNftTokens: [],
  signers: [],
  signedMintValidationParams: [],
  disallowedSigners: []
};

/**
 * This test suite should be run against the Sepolia Network (through --network truffle)
 * hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/WTR-multiconfigure.spec.ts --network truffle
 */
describe("Sepolia Multiconfigure NFT", function() {
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

  it("multiConfigure public drop", async () => {
    const privateAllowlistStartDate = new Date('2024-12-26');
    const privateAllowlistEndDate = new Date('2025-01-06');
    //const privateAllowlistStartDateInSeconds = Math.round(privateAllowlistStartDate.getTime() / 1000);
    const privateAllowlistEndDateInSeconds = Math.round(privateAllowlistEndDate.getTime() / 1000);

    const publicDrop: PublicDropStruct = {
      mintPrice: "50000000000000000", // 0.05 ether
      maxTotalMintableByWallet: 3,
      startTime: privateAllowlistEndDateInSeconds,
      endTime: privateAllowlistEndDateInSeconds + SECONDS_IN_A_DAY * 365 * 5, // 5 years
      // endTime: privateAllowlistEndDateInSeconds + SECONDS_IN_A_DAY * 5, // 5 days
      feeBps: 500,//1000 = 10%
      restrictFeeRecipients: true
    };

    const ownerAddress = await owner.getAddress();
    const creatorAddress = testCreatorAddress
    console.info(`owner ${ownerAddress} creator: ${creatorAddress}`);

    const allowListData = await getAllowListData(ownerAddress, creatorAddress, privateAllowlistStartDate, privateAllowlistEndDate);

    const config :  MultiConfigureStructStruct = {
      maxSupply: CollectionConfig.maxSupply,
      // maxSupply: 26,
      baseURI: CollectionConfig.publicMetadataUri,
      contractURI: CollectionConfig.contractMetadataUri,
      seaDropImpl: seadropAddress,
      publicDrop: publicDrop,
      dropURI: CollectionConfig.dropUri,
      allowListData: allowListData,
      creatorPayoutAddress: creatorAddress,
      provenanceHash: ethers.constants.HashZero,
      allowedFeeRecipients: [],//this having creatorAddress or ownerAddress causes issue of execution reverted or
      disallowedFeeRecipients: [],
      allowedPayers: [],
      disallowedPayers: [],
      tokenGatedAllowedNftTokens: [],
      tokenGatedDropStages: [],
      disallowedTokenGatedAllowedNftTokens: [],
      signers: [],
      signedMintValidationParams: [],
      disallowedSigners: []
    };


    const currentSupply = await nft.maxSupply();
    console.info(`currentSupply:   ${currentSupply}`);

    // const estimatedGasMSupply = await nft.estimateGas.maxSupply();
    // console.info(`estimating gas fees for method maxSupply: ${estimatedGasMSupply} wei`);
    // expect(estimatedGasMSupply).to.be.gte(30000);

    // console.info(`calling setMaxSupply with params: ${24}`);
    // const estimatedGasSupply = await nft.estimateGas.setMaxSupply(24);
    // console.info(`estimating gas fees for method setMaxSupply: ${estimatedGasSupply} wei`);

    console.info(`calling multiConfigure with params: ${JSON.stringify(config)}`);


    const estimatedGas = await nft.estimateGas.multiConfigure(config);
    console.info(`estimating gas fees for multiconfigure : ${estimatedGas} wei`);
    expect(estimatedGas).to.be.lte(200000);
    //
    // await expect(nft.connect(owner).setMaxSupply(23))
    //   .to.emit(nft, "MaxSupplyUpdated")
    //   .withArgs(23);



    await expect(nft.connect(owner).multiConfigure(config))
      .to.emit(nft, "DropURIUpdated")
      .withArgs(nft.address, "https://waltertherabbit.com/");
  });

  it("multiConfigure empty config", async () => {

    const estimatedGas = await nft.estimateGas.multiConfigure(emptyConfig);
    console.info(`estimating gas fees for multiconfigure : ${estimatedGas} wei`);
    expect(estimatedGas).to.be.gt(0);

    console.info(`calling multiConfigure with params: ${JSON.stringify(emptyConfig)}`);
    await expect(nft.connect(owner).multiConfigure(emptyConfig))
      .to.emit(nft, "DropURIUpdated")
      .withArgs(nft.address, "https://waltertherabbit.com");
  });
});


