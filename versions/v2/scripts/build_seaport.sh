#!/usr/bin/env bash
# Builds the Seaport reference and optimized artifacts that the Foundry tests
# load from ./reference-out and ./optimized-out (symlinks into lib/seaport).
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/patch_seaport_pragmas.sh

cd lib/seaport
FOUNDRY_PROFILE=reference forge build
FOUNDRY_PROFILE=optimized forge build
