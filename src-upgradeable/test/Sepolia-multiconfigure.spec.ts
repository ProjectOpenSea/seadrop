import { expect } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import type { PublicDropStruct } from "../../typechain-types/src/ERC721SeaDrop";
import { ERC721SeaDropStructsErrorsAndEventsUpgradeable, WalterTheRabbit } from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { creatorAddress, seadropAddress } from "../config/constants";
import { getAllowListData } from "../src/allowListUtils";
import { instantiateContract } from "./__fixtures__/base";
import MultiConfigureStructStruct = ERC721SeaDropStructsErrorsAndEventsUpgradeable.MultiConfigureStructStruct;

const SECONDS_IN_A_DAY = 86400;
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

  it("multiConfigure Should be able to set the Urls after deploy using the multiConfigure method", async () => {
    const privateAllowlistStartDate = new Date('2024-12-26');
    const dateInMillis = privateAllowlistStartDate.getTime();
    const privateAllowlistStartDateInSeconds = Math.round(dateInMillis / 1000);
    const privateAllowlistEndDate = privateAllowlistStartDateInSeconds + (SECONDS_IN_A_DAY * 10); // 10 days


    const publicDrop: PublicDropStruct = {
      mintPrice: "50000000000000000", // 0.05 ether
      maxTotalMintableByWallet: 4,
      startTime: privateAllowlistEndDate,
      endTime: privateAllowlistEndDate + SECONDS_IN_A_DAY * 365 * 5, // 5 years
      // endTime: privateAllowlistEndDate + SECONDS_IN_A_DAY * 5, // 5 days
      feeBps: 1000,
      restrictFeeRecipients: true
    };

    const ownerAddress = await owner.getAddress();
    console.info(`owner ${ownerAddress} creator: ${creatorAddress}`);

    const allowListData = await getAllowListData(ownerAddress);
    // const allowListData =  {
    //     merkleRoot: ethers.constants.HashZero,
    //     publicKeyURIs: [],
    //     allowListURI: "",
    //   };

    const config :  MultiConfigureStructStruct = {
      maxSupply: CollectionConfig.maxSupply,
      baseURI: CollectionConfig.publicMetadataUri,
      contractURI: CollectionConfig.contractMetadataUri,
      seaDropImpl: seadropAddress,
      publicDrop: publicDrop,
      dropURI: CollectionConfig.dropUri,
      allowListData: allowListData,
      creatorPayoutAddress: creatorAddress,
      provenanceHash: ethers.constants.HashZero,
      allowedFeeRecipients: [creatorAddress, ownerAddress],
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
    console.info(`calling multiConfigure with params: ${JSON.stringify(config)}`);
    await expect(nft.connect(owner).multiConfigure(config))
      .to.emit(nft, "DropURIUpdated")
      .withArgs(nft.address, "https://waltertherabbit.com");
  });
});
