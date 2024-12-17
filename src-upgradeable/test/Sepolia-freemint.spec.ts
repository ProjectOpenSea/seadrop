import { expect } from "chai";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import {} from "../../typechain-types";
import type { PublicDropStruct } from "../../typechain-types/src/ERC721SeaDrop";
import { AllowListDataStruct, WalterTheRabbit } from "../../typechain-types/WalterTheRabbit";
import CollectionConfig from "../config/CollectionConfig";
import { MAX_SUPPLY, seadropAddress } from "../config/constants";
import { getTokenUri, instantiateContract } from "./__fixtures__/base";

describe("Sepolia Free Mint", function() {
  let nft: WalterTheRabbit;
  let owner: Signer;
  let ownerAddress: string;
  let externalAccount: Signer;
  let externalAccountAddress: string;

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

  it("sepolia mints one freeToken for owner", async () => {

    const balanceBefore = await nft.balanceOf(ownerAddress);
    console.info(`mint free token to owner: ${ownerAddress} with seadrop address: ${seadropAddress}`);
    const zeroBM = BigNumber.from(0);
    const transaction = await nft
      .connect(owner)
      .mintAllowList(seadropAddress, 1, ownerAddress, { value: zeroBM.toString() });

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
