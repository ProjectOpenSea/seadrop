import { expect } from "chai";
import { Signer } from "ethers";
import { ethers } from "hardhat";
import { WalterTheRabbit } from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { MAX_SUPPLY } from "../config/constants";
import { instantiateContract } from "./__fixtures__/base";

describe("Sepolia Verify NFT contract", function() {
  let nft: WalterTheRabbit;
  let owner: Signer;
  let ownerAddress: string;
  let externalAccount: Signer;

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

  it("sepolia check max supply", async () => {
    const maxSupply = await nft.maxSupply();
    expect(maxSupply).to.equal(MAX_SUPPLY);
    console.info(`check max supply: ${maxSupply}`);


    const totalSupply = await nft.totalSupply();
    console.info(`check totalSupply: ${totalSupply}`);

    const baseUri = await nft.baseURI();
    expect(baseUri).to.equal(CollectionConfig.publicMetadataUri);
    console.info(`check baseURI: ${baseUri}`);


    const contractURI = await nft.contractURI();
    expect(contractURI).to.equal(CollectionConfig.contractMetadataUri);
    console.info(`check contractURI: ${contractURI}`);



  });

  // it("sepolia check free mint for owner", async () => {
  //
  //
  //   await expect(
  //     nft
  //       .connect(ownerAddress)
  //       .mintAllowList(
  //         token.address,
  //         ownerAddress,
  //         ownerAddress,
  //         5,
  //         mintParamsFreeMint,
  //         proof
  //       )
  //   )
  //     .to.emit(seadrop, "SeaDropMint")
  //     .withArgs(
  //       token.address,
  //       minter.address,
  //       feeRecipient.address,
  //       minter.address, // payer
  //       mintQuantity,
  //       0, // free
  //       mintParamsFreeMint.feeBps,
  //       mintParamsFreeMint.dropStageIndex
  //     );
  // });

});
