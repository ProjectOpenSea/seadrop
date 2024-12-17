import { expect } from 'chai'

/**
 * hardhat test --config ./src-upgradeable/hardhat.config.ts src-upgradeable/test/basic.spec.ts --network truffle
 */
describe('Basic Tests', function () {
  it('public drop start time', async () => {

    //In Seconds
    const startTime = Math.round(Date.now() / 1000) - 100;

    const specificDate = new Date('2024-12-26');
    const specificMilliseconds = specificDate.getTime();
    const startTime2 = Math.round(specificMilliseconds / 1000);

    expect(startTime2).to.not.be.null
    console.info(`start time in seadrop: ${startTime} to ${startTime2}`)
  })
})
