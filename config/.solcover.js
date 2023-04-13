module.exports = {
  skipFiles: ["./shim", "./seaport-contracts", "./test"],
  modifierWhitelist: ["onlyAllowedOperatorApproval", "onlyAllowedOperator"],
  configureYulOptimizer: true,
  solcOptimizerDetails: {
    yul: true,
    yulDetails: {
      stackAllocation: true,
    },
  },
};
