module.exports = {
  skipFiles: [
    "./shim/Shim.sol",
    "./test/TestERC721.sol",
    "./test/MaliciousRecipient.sol",
    "./partners"
  ],
  configureYulOptimizer: true,
  solcOptimizerDetails: {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  },
};
