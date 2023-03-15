module.exports = {
  skipFiles: [
    "./shim/Shim.sol",
    "./test/TestERC721.sol",
    "./test/MaliciousRecipient.sol",
    "./clones/ReentrancyGuardStorage.sol",
    "./clones/ReentrancyGuardUpgradeable.sol",
  ],
  configureYulOptimizer: true,
  solcOptimizerDetails: {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  },
};
