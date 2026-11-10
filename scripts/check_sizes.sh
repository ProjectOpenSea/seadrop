#!/usr/bin/env bash
# Builds the project without test/ and script/, and fails if any contract it
# compiles, src/ and the library contracts it uses, is over EIP-170's
# 24,576-byte runtime limit or EIP-3860's 49,152-byte init code limit.
# Prints the ten contracts closest to a limit, and adds them to the job
# summary in GitHub Actions.
set -euo pipefail

cd "$(dirname "$0")/.."

# forge exits nonzero when a contract is over a limit. Keep its output so
# the report still prints, and fail after it.
status=0
sizes=$(forge build --sizes --skip test --skip script --json) || status=$?
if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$sizes"; then
    echo "forge build failed (exit $status)" >&2
    exit "$((status == 0 ? 1 : status))"
fi

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
exit "$status"
