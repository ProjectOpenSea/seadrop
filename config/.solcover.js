module.exports = {
  skipFiles: [
    "./shim",
    "./seaport-contracts",
    "./test",
    "./interfaces/IDelegationRegistry.sol",
  ],
  modifierWhitelist: ["onlyAllowedOperatorApproval", "onlyAllowedOperator"],
  configureYulOptimizer: true,
  solcOptimizerDetails: {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  },
};
