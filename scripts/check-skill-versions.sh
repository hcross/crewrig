#!/bin/bash
# check-skill-versions.sh — Enforce the version-bump rule on skill sources.
#
# Per community-config/FORMAT.md → Version semantics, every PR that touches
# a `community-config/skills/<name>/SKILL.md` or
# `community-config/agents/<name>/AGENT.md` source MUST bump
# `provenance.version` in the same diff. This script enforces the rule.
#
# Usage:
#   bash scripts/check-skill-versions.sh [<base-ref>]
#
# Default base ref: origin/release/crew-v0 (CI passes BASE_REF env var
# pointing at the PR base, typically `origin/<base-branch>`).
#
# Exits 0 if all changed sources include a version bump, non-zero (with a
# per-file failure list) otherwise.

set -euo pipefail

BASE_REF="${1:-${BASE_REF:-origin/release/crew-v0}}"

# Make sure the base is fetched. CI runners do shallow clones by default.
if ! git rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  # Try fetching (covers fresh CI clones).
  remote="${BASE_REF%%/*}"
  ref="${BASE_REF#*/}"
  git fetch --depth=50 "$remote" "$ref" >/dev/null 2>&1 || {
    echo "Error: cannot resolve base ref '$BASE_REF' and `git fetch` failed." >&2
    echo "       Pass a resolvable ref as the first argument or via BASE_REF." >&2
    exit 2
  }
fi

# Collect changed skill/agent sources.
mapfile -t changed < <(git diff --name-only "$BASE_REF" -- \
  'community-config/skills/*/SKILL.md' \
  'community-config/agents/*/AGENT.md' 2>/dev/null || true)

if [ "${#changed[@]}" -eq 0 ]; then
  echo "OK: no skill/agent sources changed vs $BASE_REF."
  exit 0
fi

echo "Checking version bumps on ${#changed[@]} changed skill/agent source(s)..."

failures=()
for f in "${changed[@]}"; do
  [ -z "$f" ] && continue
  [ ! -f "$f" ] && continue  # deleted file: skip (deletions don't need a bump)

  # Look at the diff for a `version:` line addition. The provenance.version
  # field is indented under `provenance:` so the line typically reads
  # `  version: "X.Y.Z"`. We match any added line whose trimmed text starts
  # with `version:` — covers both the indented form and a hypothetical
  # top-level placement.
  if git diff "$BASE_REF" -- "$f" | grep -qE '^\+[[:space:]]+version:[[:space:]]*"'; then
    echo "  OK   $f"
  else
    echo "  FAIL $f — provenance.version not bumped"
    failures+=("$f")
  fi
done

if [ "${#failures[@]}" -gt 0 ]; then
  echo ""
  echo "FAILED: ${#failures[@]} source(s) changed without a version bump:"
  for f in "${failures[@]}"; do
    echo "  - $f"
  done
  echo ""
  echo "Per community-config/FORMAT.md → Version semantics, bump"
  echo "provenance.version in the same diff. SemVer:"
  echo "  PATCH (1.0.0 → 1.0.1) — friction fix / wording change"
  echo "  MINOR (1.0.0 → 1.1.0) — additive (new section, new field)"
  echo "  MAJOR (1.0.0 → 2.0.0) — breaking contract change"
  exit 1
fi

echo ""
echo "OK: all changed skill/agent sources include a version bump."
