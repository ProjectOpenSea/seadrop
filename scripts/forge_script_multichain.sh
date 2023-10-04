#!/bin/bash

# Define these env variables for this script:
#   - $SCRIPT - the script contract name to run
#   - $TEST - set to true to run on testnets, false (default) runs on mainnets

declare -a mainnet_chains=(
  "mainnet"
  "polygon"
  "optimism"
  "arbitrum"
  "arbitrum-nova"
  "avalanche"
  "klaytn"
  "base"
  "zora"
  #"bsc"
  #"gnosis"
)

declare -a testnet_chains=(
  "goerli"
  "sepolia"
  "polygon-mumbai"
  "optimism-goerli"
  "arbitrum-goerli"
  "avalanche-fuji"
  "baobab"
  "base-goerli"
  "zora-test"
  #"bsc-testnet"
  #"chiado"
)

if [[ -n "$TEST" ]]; then
    chains=("${testnet_chains[@]}")
else
    chains=("${mainnet_chains[@]}")
fi

# Iterate over chains and run command for each chain
for chain in "${!chains[@]}"; do
  export CHAIN=${chains[chain]}
  echo "========== Running forge script with CHAIN set to $CHAIN =========="
  forge script $SCRIPT \
    --rpc-url $CHAIN \
    --private-key $PK \
    --broadcast \
    --verify \
    --no-storage-caching \
    --skip-simulation
done
echo "====================================================================="
echo ""
echo "Finished!"
echo ""