import { expect } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import { ISeaDropUpgradeable } from "../../typechain-types";
import type { PublicDropStruct } from "../../typechain-types/src/ERC721SeaDrop";
import { ERC721SeaDropStructsErrorsAndEventsUpgradeable, WalterTheRabbit } from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { prodCreatorAddress, seadropAddress, testExternalAddress } from "../config/constants";
import { getAllowListData } from "../src/allowListUtils";
import { instantiateContract, instantiateSeadropContract } from "./__fixtures__/base";
import { SECONDS_IN_A_DAY } from "./basic.spec";
import MultiConfigureStructStruct = ERC721SeaDropStructsErrorsAndEventsUpgradeable.MultiConfigureStructStruct;



const emptyAllowListData =  {
  merkleRoot: ethers.constants.HashZero,
  publicKeyURIs: [],
  allowListURI: "",
};

/**
 * hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/Sepolia-allowlist.spec.ts --network truffle
 */
describe("Sepolia Allowlist", function() {
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

  it("allowlist presale drop", async () => {
    const privateAllowlistStartDate = new Date('2025-02-15');
    const privateAllowlistEndDate = new Date('2025-02-25');


    const ownerAddress = await owner.getAddress();
    const creatorAddress = prodCreatorAddress;
    const externalAddress = testExternalAddress;

    console.info(`owner: ${ownerAddress} creator: ${creatorAddress} externalAddress: ${externalAddress}`);

    const allowListData = await getAllowListData(ownerAddress, creatorAddress, externalAddress, privateAllowlistStartDate, privateAllowlistEndDate);

    const config :  MultiConfigureStructStruct = {
      maxSupply: 0,
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
      allowListData: allowListData,
      creatorPayoutAddress: ethers.constants.AddressZero,
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

    await expect(nft.connect(owner).multiConfigure(config))
      .to.emit(nft, "AllowListUpdated");
      //.withArgs(nft.address, "https://waltertherabbit.com/");
  });

  it("check allow list data", async () => {
    console.info(`check allow list data`);
    const seadrop = await instantiateSeadropContract(seadropAddress);
    console.info(`seadrop contract name: ${seadrop.address}`)
    const allowListRoot = await seadrop.getAllowListMerkleRoot(nft.address);
    console.info(`root: ${allowListRoot}`);
    expect(allowListRoot).to.eq(
      `0x${"0".repeat(64)}`
    );
  });
});


