import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { instantiateContract } from './__fixtures__'

/**
  * yarn hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/healthcheck.spec.ts --network hardhat
 */
describe('Healthcheck', function () {
  it('deploys', async () => {
    const { seadrop, nft, owner, ownerAddress } = await loadFixture(instantiateContract)
    expect(nft.address).to.not.be.null
    const maxSupply = await nft.maxSupply();
    expect(maxSupply).to.equal(MAX_SUPPLY);
    console.info(`check max supply: ${maxSupply}`);
  })

  it("check max supply", async () => {
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

})
