#!/usr/bin/env bash
# lint-json.sh — JSON linter for PR review.
# Checks: valid JSON via jq, no trailing commas.
# Usage: lint-json.sh <file1.json> [file2.json ...]
#
# Exit 0 = no findings, 1 = findings. Missing jq degrades gracefully
# (exit 0 with a one-line note on stdout).

set -uo pipefail

if [ "$#" -eq 0 ]; then
  echo "lint-json.sh: no files supplied — nothing to check."
  exit 0
fi

findings=0

HAS_JQ=0
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
else
  echo "lint-json.sh: jq not found — skipping JSON parse validation."
fi

for file in "$@"; do
  [ -f "$file" ] || { echo "$file: not a regular file"; findings=1; continue; }

  if [ "$HAS_JQ" -eq 1 ]; then
    if ! err=$(jq empty "$file" 2>&1); then
      echo "$file: invalid JSON — $err"
      findings=1
    fi
  fi

  # Trailing-comma heuristic (line-based, ignores strings on best-effort).
  if hits=$(grep -nE ',\s*[}\]]' "$file"); then
    while IFS= read -r line; do
      echo "$file:${line%%:*}: trailing comma before } or ]"
    done <<<"$hits"
    findings=1
  fi
done

exit "$findings"
