import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import {} from "../../typechain-types";
import type { PublicDropStruct } from "../../typechain-types/src/ERC721SeaDrop";
import {
  AllowListDataStruct,
  ERC721SeaDropStructsErrorsAndEventsUpgradeable,
  WalterTheRabbit
} from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { MAX_SUPPLY, seadropAddress } from "../config/constants";
import { getTokenUri, instantiateContract } from "./__fixtures__/base";
import MultiConfigureStructStruct = ERC721SeaDropStructsErrorsAndEventsUpgradeable.MultiConfigureStructStruct;

/**
 * This test suite should be run against the Sepolia Network (through --network truffle)
 * hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/WTR-multiconfigure.spec.ts --network truffle
 */
describe("Sepolia Multiconfigure Token", function() {
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

  /*
  This method FAILS against sepolia with cancelled or rejected trx
   */
  it("multiConfigure Should be able to use the multiConfigure method", async () => {
    const publicDrop: PublicDropStruct = {
      mintPrice: "100000000000000000", // 0.1 ether
      maxTotalMintableByWallet: 10,
      startTime: Math.round(Date.now() / 1000) - 100,
      endTime: Math.round(Date.now() / 1000) + 1000,
      feeBps: 1000,
      restrictFeeRecipients: true
    };

    const ownerAddress = await owner.getAddress();
    const allowListData = {
      merkleRoot: `0x${"3".repeat(64)}`,
      publicKeyURIs: [],
      allowListURI: ""
    };

    const config: MultiConfigureStructStruct  = {
      maxSupply: 100,
      baseURI: CollectionConfig.publicMetadataUri,
      contractURI: CollectionConfig.contractMetadataUri,
      seaDropImpl: seadropAddress,
      publicDrop,
      dropURI: CollectionConfig.dropUri,
      allowListData,
      creatorPayoutAddress: ownerAddress,
      provenanceHash: `0x${"3".repeat(64)}`,
      allowedFeeRecipients: [ownerAddress],
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
      .to.emit(nft, "DropURIUpdated")
      .withArgs(nft.address, "https://waltertherabbit.com");
  });
});
