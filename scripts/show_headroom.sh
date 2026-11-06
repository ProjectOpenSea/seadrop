#!/usr/bin/env bash
# Prints how many bytes ERC721SeaDrop has left under the 24,576-byte
# EIP-170 limit. Run after `forge build`.
set -euo pipefail

cd "$(dirname "$0")/.."

jq -r '.deployedBytecode.object' out/ERC721SeaDrop.sol/ERC721SeaDrop.json |
  tr -d '\n' | wc -m | awk '{print 24577 - ($1 - 2) / 2}'
