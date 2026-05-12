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

# Labels: three-tuple ["harness-feedback", "room:<dominant>", "severity:<worst>"].
YQ_LABELS=$(echo "$YQ" | jq -c '.labels')
assert "yq-merge.labels" '["harness-feedback","room:prompt","severity:med"]' "$YQ_LABELS"

# No branch_name field anymore — V0 opens issues, not MRs.
YQ_HAS_BRANCH=$(echo "$YQ" | jq 'has("branch_name")')
assert "yq-merge.has(branch_name)" "false" "$YQ_HAS_BRANCH"

# High-severity singleton bypass produced its own cluster; room is "tool".
HIGH=$(echo "$OUT" | jq -c '.clusters[] | select(.cluster_key == "gh-body-truncation")')
[ -n "$HIGH" ] || { echo "FAIL: severity:high singleton not promoted" >&2; exit 1; }
HIGH_ROOM=$(echo "$HIGH" | jq -r '.frictions[0]._room')
assert "gh-body-truncation.frictions[0]._room" "tool" "$HIGH_ROOM"
echo "  PASS severity:high singleton promoted to cluster"

# severity:high label propagates on the high-severity cluster.
HIGH_LABELS=$(echo "$HIGH" | jq -c '.labels')
assert "gh-body-truncation.labels" '["harness-feedback","room:tool","severity:high"]' "$HIGH_LABELS"

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

# --- apply.py orchestration (--dry-run-apply) ----------------------------
# Pipe the curator JSON through apply.py --dry-run-apply. Each cluster
# round-trips as one JSON-array line representing the `gh issue create`
# argv that would have been invoked. The flag exists so we never need to
# stub `gh` to assert orchestration shape.
APPLY="$SKILL_DIR/scripts/apply.py"
[ -f "$APPLY" ] || { echo "FAIL: apply.py missing: $APPLY" >&2; exit 1; }

set +e
APPLY_OUT=$(printf '%s\n' "$OUT" | python3 "$APPLY" --dry-run-apply)
APPLY_RC=$?
set -e
assert "apply --dry-run-apply exit code" "0" "$APPLY_RC"

# Two qualified clusters → exactly two argv lines, no spurious output.
APPLY_LINES=$(printf '%s\n' "$APPLY_OUT" | grep -c '^\[')
assert "apply --dry-run-apply emits one argv line per cluster" "2" "$APPLY_LINES"

# Helper jq filter: collect all `--label <value>` pairs as a list, in order.
LABELS_FILTER='[. as $a | range(length) | select($a[.] == "--label") | $a[.+1]]'

# yq-merge argv shape: gh issue create against the stripped repo slug,
# carrying the cluster title and the full three-label tuple in order.
YQ_TITLE=$(echo "$YQ" | jq -r '.title')
YQ_ARGV=$(printf '%s\n' "$APPLY_OUT" | jq -c --arg t "$YQ_TITLE" \
  'select(type == "array" and (index($t) != null))')
[ -n "$YQ_ARGV" ] || { echo "FAIL: yq-merge argv line not found in apply output" >&2; exit 1; }
assert "yq-merge argv head" '["gh","issue","create"]' \
  "$(echo "$YQ_ARGV" | jq -c '.[0:3]')"
assert "yq-merge argv --repo (prefix stripped)" "hcross/crewrig" \
  "$(echo "$YQ_ARGV" | jq -r '.[(index("--repo"))+1]')"
assert "yq-merge argv labels" '["harness-feedback","room:prompt","severity:med"]' \
  "$(echo "$YQ_ARGV" | jq -c "$LABELS_FILTER")"

# gh-body-truncation argv: same structural checks, severity:high labels.
HIGH_TITLE=$(echo "$HIGH" | jq -r '.title')
HIGH_ARGV=$(printf '%s\n' "$APPLY_OUT" | jq -c --arg t "$HIGH_TITLE" \
  'select(type == "array" and (index($t) != null))')
[ -n "$HIGH_ARGV" ] || { echo "FAIL: gh-body-truncation argv line not found" >&2; exit 1; }
assert "gh-body-truncation argv head" '["gh","issue","create"]' \
  "$(echo "$HIGH_ARGV" | jq -c '.[0:3]')"
assert "gh-body-truncation argv --repo (prefix stripped)" "hcross/crewrig" \
  "$(echo "$HIGH_ARGV" | jq -r '.[(index("--repo"))+1]')"
assert "gh-body-truncation argv labels" '["harness-feedback","room:tool","severity:high"]' \
  "$(echo "$HIGH_ARGV" | jq -c "$LABELS_FILTER")"

# No-clusters branch: empty .clusters yields the friendly notice, exit 0.
EMPTY_JSON='{"stats":{"total_drawers":0,"valid_frictions":0,"skipped_malformed":0,"clusters_formed":0,"clusters_above_threshold":0,"clusters_parked":0,"routing_failures":0},"clusters":[]}'
set +e
EMPTY_OUT=$(printf '%s\n' "$EMPTY_JSON" | python3 "$APPLY" --dry-run-apply)
EMPTY_RC=$?
set -e
assert "apply --dry-run-apply empty clusters exit code" "0" "$EMPTY_RC"
echo "$EMPTY_OUT" | grep -q "No clusters above threshold; no issues to open." || {
  echo "FAIL: empty-clusters notice missing" >&2
  echo "$EMPTY_OUT" >&2
  exit 1
}
echo "  PASS apply --dry-run-apply emits no-clusters notice"

echo ""
echo "OK: harness-curate smoke test passed."
