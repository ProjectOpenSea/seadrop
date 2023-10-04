#!/bin/bash

# Define these env variables for this script:
#   - $ADDRESS - the address to check

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

chains=("${mainnet_chains[@]}" "${testnet_chains[@]}")

# Iterate over chains and run command for each chain
echo "====== Checking deployments for $ADDRESS ======"
for chain in "${!chains[@]}"; do
  export CHAIN=${chains[chain]}
  codesize=$(cast codesize $ADDRESS --rpc-url $CHAIN )
  deployed="\033[31mFALSE\033[0m"
  if [ $codesize -gt 0 ]; then
    deployed="\033[32mTRUE\033[0m"
  fi
  echo -e "$CHAIN: $deployed"
done
echo "==========================================================="
echo ""
echo "Finished!"
echo ""