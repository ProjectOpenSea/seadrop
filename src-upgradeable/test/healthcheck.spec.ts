import { loadFixture } from '@nomicfoundation/hardhat-network-helpers'
import { expect } from 'chai'
import { deployContract } from './__fixtures__'

/**
  * hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/healthcheck.spec.ts --network hardhat
 */
describe('Healthcheck', function () {
  it('deploys', async () => {
    const { seadrop, nft, owner, ownerAddress } = await loadFixture(deployContract)
    expect(nft.address).to.not.be.null
    await nft.updateCreatorPayoutAddress(seadrop.address, ownerAddress);
    console.info(`updating creatorPayout in seadrop: ${seadrop.address} to ${ownerAddress}`)
  })
})
