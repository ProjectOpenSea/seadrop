module.exports = {
  skipFiles: [
    "./shim/Shim.sol",
    "./test/TestERC721.sol",
    "./test/MaliciousRecipient.sol",
  ],
  configureYulOptimizer: true,
  solcOptimizerDetails: {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  },
};
