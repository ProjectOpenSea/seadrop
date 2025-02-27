import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import type { PublicDropStruct } from "../../typechain-types/src/ERC721SeaDrop";
import { ERC721SeaDropStructsErrorsAndEventsUpgradeable, WalterTheRabbit } from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { seadropAddress } from "../config/constants";
import { deployContract } from "./__fixtures__";
import MultiConfigureStructStruct = ERC721SeaDropStructsErrorsAndEventsUpgradeable.MultiConfigureStructStruct;

/**
 * This test suite should be run against the localnod Network (through --network hardhat)
 * hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/WTR-multiconfigure.spec.ts --network truffle
 */
describe("local Multiconfigure", function() {
  let nft: WalterTheRabbit;
  let owner: Signer;
  let ownerAddress: string;
  let externalAccount: Signer;
  let externalAccountAddress: string;
  const mintPrice = ethers.utils.parseEther("0.01");

  before(async () => {
    const { seadrop: Seadrop, _nft, _owner, _ownerAddress } = await loadFixture(deployContract)
    nft = _nft as WalterTheRabbit;
    owner = _owner;
    ownerAddress = _ownerAddress;

    expect(nft.address).to.not.be.null
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
