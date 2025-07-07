import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { instantiateContract, instantiateSeadropContract } from "./__fixtures__/base";

/**
  * yarn hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/healthcheck.spec.ts --network hardhat
 */
describe('Healthcheck', function () {
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


  it('deploys', async () => {
    expect(nft.address).to.not.be.null
    console.info(`nft add: ${nft.address}`);

    const maxSupply = await nft.maxSupply();
    expect(maxSupply).to.equal(30);
    console.info(`check max supply: ${maxSupply}`);
  })

//   it("check max supply", async () => {
//     const { seadrop, nft, owner, ownerAddress } = await loadFixture(instantiateContract)
//     const maxSupply = await nft.maxSupply();
//     expect(maxSupply).to.equal(MAX_SUPPLY);
//     console.info(`check max supply: ${maxSupply}`);
//
//
//     const totalSupply = await nft.totalSupply();
//     console.info(`check totalSupply: ${totalSupply}`);
//
//     const baseUri = await nft.baseURI();
//     expect(baseUri).to.equal(CollectionConfig.publicMetadataUri);
//     console.info(`check baseURI: ${baseUri}`);
//
//     const contractURI = await nft.contractURI();
//     expect(contractURI).to.equal(CollectionConfig.contractMetadataUri);
//     console.info(`check contractURI: ${contractURI}`);
//   });

})
