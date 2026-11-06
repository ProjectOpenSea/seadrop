#!/usr/bin/env bash
# Seaport pins exact `pragma solidity 0.8.x` versions. Loosening them to `^`
# lets this repo's solc (foundry.toml) compile the Seaport sources it imports.
# This edits the lib/seaport submodule's working tree; never commit it.
set -euo pipefail

cd "$(dirname "$0")/.."

find ./lib/seaport/contracts \
  ./lib/seaport/lib/seaport-sol/src \
  ./lib/seaport/lib/seaport-types/src \
  ./lib/seaport/lib/seaport-core/src \
  -type f -name '*.sol' -print0 |
  xargs -0 perl -pi -e 's/pragma solidity 0/pragma solidity ^0/g'
