module.exports = {
  skipFiles: [],
  configureYulOptimizer: true,
  solcOptimizerDetails: {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  },
};
