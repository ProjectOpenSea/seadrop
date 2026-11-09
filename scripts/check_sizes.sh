#!/usr/bin/env bash
# Builds the contracts under src/ and fails if any is over EIP-170's
# 24,576-byte runtime limit or EIP-3860's 49,152-byte init code limit.
# Prints the ten contracts closest to a limit, and adds them to the job
# summary in GitHub Actions.
set -euo pipefail

cd "$(dirname "$0")/.."

sizes=$(forge build --sizes --skip test --skip script --json)

table=$(jq -r '
  to_entries
  | sort_by([.value.runtime_margin, .value.init_margin] | min)
  | .[:10][]
  | "| \(.key) | \(.value.runtime_size) | \(.value.runtime_margin) | \(.value.init_size) | \(.value.init_margin) |"
' <<<"$sizes")

report="### Contract sizes closest to a limit

| Contract | Runtime | Runtime left | Init code | Init code left |
| --- | ---: | ---: | ---: | ---: |
$table"

echo "$report"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "$report" >>"$GITHUB_STEP_SUMMARY"
fi

over=$(jq -r '
  to_entries[]
  | select(.value.runtime_margin < 0 or .value.init_margin < 0)
  | .key
' <<<"$sizes")
if [ -n "$over" ]; then
  echo "Over a size limit: $over" >&2
  exit 1
fi
