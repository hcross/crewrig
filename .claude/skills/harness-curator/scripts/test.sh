#!/bin/bash
# community-config/skills/harness-curator/scripts/test.sh
#   Smoke test for the bundled curate.sh.
#
# Feeds the fixture at ../assets/sample-frictions.json through
# `scripts/curate.sh --from-stdin --dry-run` (skill-relative paths) and
# asserts on the JSON output. Does not touch MemPalace or `gh` — pure
# offline test. Runs unchanged from any install location since all
# paths are resolved relative to this script's directory.
#
# Exit 0 on pass, non-zero with explanation on fail.

set -euo pipefail

# Paths are resolved relative to this script's location so the test runs
# from anywhere the skill is installed (project-level OR user-level).
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$SKILL_DIR/assets/sample-frictions.json"
SCRIPT="$SKILL_DIR/scripts/curate.sh"

[ -f "$FIXTURE" ] || { echo "FAIL: fixture missing: $FIXTURE" >&2; exit 1; }
[ -x "$SCRIPT" ] || chmod +x "$SCRIPT"

# `jq` is the assertion helper — it is the project's standard JSON tool
# (already required by build-components.sh per its prerequisites).
command -v jq >/dev/null 2>&1 || {
  echo "FAIL: jq is required for test assertions" >&2
  exit 1
}

# `python3` covers the --from-stdin path even without the mempalace pipx
# venv. The script auto-falls back to it.
command -v python3 >/dev/null 2>&1 || {
  echo "FAIL: python3 is required" >&2
  exit 1
}

echo "Running curator on fixture..."
# Disable set -e momentarily so we can inspect a non-zero exit before
# bailing — yields a clearer failure than a bare `set -e` abort.
set +e
OUT=$(bash "$SCRIPT" --from-stdin --dry-run < "$FIXTURE")
RC=$?
set -e
if [ "$RC" -ne 0 ] || [ -z "$OUT" ]; then
  echo "FAIL: harness-curate.sh exit=$RC, stdout-len=${#OUT}" >&2
  echo "--- captured stdout ---" >&2
  printf '%s\n' "$OUT" >&2
  exit 1
fi

# --- Assertions -----------------------------------------------------------

assert() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  PASS $label"
  else
    echo "  FAIL $label — expected '$expected', got '$actual'" >&2
    return 1
  fi
}

# 6 input drawers
assert "stats.total_drawers"       "6" "$(echo "$OUT" | jq -r '.stats.total_drawers')"

# 4 valid; 2 malformed: drw-005 (no FRICTION: prefix) and drw-006 (empty writer_agent)
assert "stats.valid_frictions"     "4" "$(echo "$OUT" | jq -r '.stats.valid_frictions')"
assert "stats.skipped_malformed"   "2" "$(echo "$OUT" | jq -r '.stats.skipped_malformed')"

# 3 cluster keys: yq-merge, gh-body-truncation, parked-singleton
assert "stats.clusters_formed"     "3" "$(echo "$OUT" | jq -r '.stats.clusters_formed')"

# Above threshold:
#  - yq-merge (size 2, ≥ threshold)
#  - gh-body-truncation (size 1 BUT severity:high → bypass)
# Parked: parked-singleton (size 1, severity low)
assert "stats.clusters_above_threshold" "2" \
  "$(echo "$OUT" | jq -r '.stats.clusters_above_threshold')"
assert "stats.clusters_parked"     "1" "$(echo "$OUT" | jq -r '.stats.clusters_parked')"

# No routing failures (every cluster has canonical: set in the fixture)
assert "stats.routing_failures"    "0" "$(echo "$OUT" | jq -r '.stats.routing_failures')"

# Exactly 2 clusters in output
assert "len(.clusters)"            "2" "$(echo "$OUT" | jq -r '.clusters | length')"

# yq-merge cluster — 2 frictions, target hcross/crewrig
YQ=$(echo "$OUT" | jq -c '.clusters[] | select(.cluster_key == "yq-merge")')
[ -n "$YQ" ] || { echo "FAIL: yq-merge cluster missing" >&2; exit 1; }
assert "yq-merge.cluster_size"     "2" "$(echo "$YQ" | jq -r '.cluster_size')"
assert "yq-merge.target_repo"      "https://github.com/hcross/crewrig" \
  "$(echo "$YQ" | jq -r '.target_repo')"

# Both yq-merge frictions came from room="prompt"; assert the room
# propagates correctly through cluster_frictions().
YQ_ROOMS=$(echo "$YQ" | jq -r '[.frictions[]._room] | unique | join(",")')
assert "yq-merge.frictions[*]._room" "prompt" "$YQ_ROOMS"

# Inline evidence (drw-002 used `evidence: <url>` form) must produce
# a single-entry list — not a parse miss.
DRW2_EVIDENCE=$(echo "$YQ" | jq -r '.frictions[] | select(.title | test("empty file")) | .evidence | length')
assert "drw-002.evidence count (inline form)" "1" "$DRW2_EVIDENCE"

# Body must contain at least one evidence pointer.
YQ_BODY=$(echo "$YQ" | jq -r '.body')
echo "$YQ_BODY" | grep -q "community-config/skills/architect/SKILL.md:42" || {
  echo "FAIL: yq-merge body missing evidence pointer from drw-001" >&2
  exit 1
}
echo "  PASS yq-merge.body contains evidence"

# Body must include the date range computed from filed_at metadata.
echo "$YQ_BODY" | grep -q "2026-05-08 → 2026-05-10" || {
  echo "FAIL: yq-merge body missing date range" >&2
  echo "$YQ_BODY" >&2
  exit 1
}
echo "  PASS yq-merge.body contains date range"

# Branch name follows the harness/<slug>-<date> shape.
YQ_BRANCH=$(echo "$YQ" | jq -r '.branch_name')
[[ "$YQ_BRANCH" =~ ^harness/yq-merge-[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || {
  echo "FAIL: yq-merge.branch_name unexpected: '$YQ_BRANCH'" >&2
  exit 1
}
echo "  PASS yq-merge.branch_name format"

# High-severity singleton bypass produced its own MR; room is "tool".
HIGH=$(echo "$OUT" | jq -c '.clusters[] | select(.cluster_key == "gh-body-truncation")')
[ -n "$HIGH" ] || { echo "FAIL: severity:high singleton not promoted" >&2; exit 1; }
HIGH_ROOM=$(echo "$HIGH" | jq -r '.frictions[0]._room')
assert "gh-body-truncation.frictions[0]._room" "tool" "$HIGH_ROOM"
echo "  PASS severity:high singleton promoted to cluster"

# Single-day cluster: gh-body-truncation has 1 friction with one date —
# body should render the "(single day)" form, not a bare date.
HIGH_BODY=$(echo "$HIGH" | jq -r '.body')
echo "$HIGH_BODY" | grep -q "2026-05-09 (single day)" || {
  echo "FAIL: gh-body-truncation body missing single-day marker" >&2
  echo "$HIGH_BODY" >&2
  exit 1
}
echo "  PASS gh-body-truncation.body uses '(single day)' format"

# Parked singleton is NOT in the clusters output.
PARKED=$(echo "$OUT" | jq -c '.clusters[] | select(.cluster_key == "parked-singleton")')
[ -z "$PARKED" ] || { echo "FAIL: parked-singleton should be parked, not in clusters" >&2; exit 1; }
echo "  PASS parked-singleton excluded from output"

echo ""
echo "OK: harness-curate smoke test passed."
