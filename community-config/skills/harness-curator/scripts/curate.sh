#!/bin/bash
# curate.sh — Harness Curator entry point
#
# Reads friction reports from MemPalace `wing="harness-friction"` (or from
# stdin in test mode), clusters them by subcategory/room, composes issue
# bodies, and either prints the result as JSON (`--dry-run`, default) or
# opens one GitHub issue per cluster via `gh` (`--apply`).
#
# V0 is descriptive-only: the artefact opened is an *issue*, not an MR.
# The actual fix (diff) lands later, either human-authored or via the
# auto-fix mode tracked in #42, and closes the issue.
#
# Usage:
#   bash scripts/curate.sh [--dry-run | --apply]
#                          [--from-stdin]
#                          [--target-repo <url>]
#                          [--threshold <n>]
#
# Options:
#   --dry-run        Output JSON of clusters that would become issues (default).
#   --apply          Open issues via `gh issue create`. Requires gh authenticated.
#   --from-stdin     Read frictions JSON list from stdin instead of MemPalace.
#                    For unit tests and dry-runs without a live wing.
#   --target-repo    Force a single issue target repo (overrides per-friction
#                    provenance routing). For tests / single-fork curation.
#   --threshold      Minimum cluster size to propose an issue (default: 2).
#                    Severity-`high` frictions bypass this and always cluster.
#
# Environment:
#   MEMPALACE_PYTHON Python binary with `mempalace` installed (auto-detected
#                    from pipx if unset).
#
# This script uses the bundled-skill carve-out documented in `config/TOOLS.md`:
# it walks MemPalace via `from mempalace.mcp_server import tool_list_drawers`
# rather than per-call MCP because batch-reading the friction wing through
# MCP would be a multi-thousand-call traversal. Read-only path; any future
# write goes through MCP.

set -euo pipefail

DRY_RUN=true
FROM_STDIN=false
TARGET_REPO=""
THRESHOLD=2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)        DRY_RUN=true; shift ;;
    --apply)          DRY_RUN=false; shift ;;
    --from-stdin)     FROM_STDIN=true; shift ;;
    --target-repo)    TARGET_REPO="$2"; shift 2 ;;
    --threshold)      THRESHOLD="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run '$0 --help' for usage." >&2
      exit 1
      ;;
  esac
done

if ! [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 1 ]; then
  echo "Error: --threshold must be a positive integer" >&2
  exit 1
fi

# --- Dependencies ---
# Always returns 0 — the function's job is to *resolve* a Python path; the
# caller does not branch on the exit code. A non-zero return here would
# trigger `set -e` on the calling assignment when the pipx path is absent.
auto_detect_mempalace_python() {
  if command -v pipx >/dev/null 2>&1; then
    local pipx_venv
    pipx_venv=$(pipx environment --value PIPX_HOME 2>/dev/null)/venvs/mempalace
    if [ -d "$pipx_venv" ]; then
      echo "$pipx_venv/bin/python3"
      return 0
    fi
  fi
  echo "python3"
}

MEMPALACE_PYTHON="${MEMPALACE_PYTHON:-$(auto_detect_mempalace_python)}"

# --from-stdin mode does not need mempalace, but the script must still find a
# usable Python. Fall back to system python3 if mempalace path is unusable.
if [ "$FROM_STDIN" = true ] && ! command -v "$MEMPALACE_PYTHON" >/dev/null 2>&1; then
  MEMPALACE_PYTHON="python3"
fi

command -v "$MEMPALACE_PYTHON" >/dev/null 2>&1 || {
  echo "Error: $MEMPALACE_PYTHON not found" >&2
  echo "Install MemPalace via pipx: pipx install 'mempalace>=3.3.3,<3.4'" >&2
  exit 2
}

# --- Run the curator ---
TODAY=$(date +%Y-%m-%d)

# Read stdin into a tempfile if applicable so the python heredoc can re-open
# it; passing stdin straight to the heredoc works on bash but fails when the
# script is sourced or run under unusual launchers.
STDIN_FILE=""
if [ "$FROM_STDIN" = true ]; then
  STDIN_FILE=$(mktemp -t crewrig-curate.XXXXXX)
  trap 'rm -f "$STDIN_FILE"' EXIT
  cat > "$STDIN_FILE"
fi

CURATE_OUT=$(env \
  FRICTION_WING="harness-friction" \
  TODAY="$TODAY" \
  THRESHOLD="$THRESHOLD" \
  TARGET_REPO_OVERRIDE="$TARGET_REPO" \
  FROM_STDIN_FILE="$STDIN_FILE" \
  "$MEMPALACE_PYTHON" "$(dirname "$0")/curate.py")

# --- Output / apply ---
if [ "$DRY_RUN" = true ]; then
  printf '%s\n' "$CURATE_OUT"
  exit 0
fi

# --apply: open one issue per cluster via gh. Requires gh authenticated.
# V0 is descriptive-only — issues, not MRs. The MR with the actual diff
# lands later (human-authored or via the auto-fix mode tracked in #42).
command -v gh >/dev/null 2>&1 || {
  echo "Error: --apply requires the 'gh' CLI to be installed and authenticated." >&2
  exit 3
}

# Parse JSON and open one issue per cluster.
echo "$CURATE_OUT" | "$MEMPALACE_PYTHON" -c '
import json, os, subprocess, sys

data = json.load(sys.stdin)
clusters = data.get("clusters", [])
if not clusters:
    print("No clusters above threshold; no issues to open.")
    sys.exit(0)

opened = []
failures = []
for c in clusters:
    target = c["target_repo"]
    title = c["title"]
    body = c["body"]
    labels = c.get("labels", ["harness-feedback"])
    print(f"--- Opening issue on {target}: {title}")
    cmd = ["gh", "issue", "create",
           "--repo", target.replace("https://github.com/", ""),
           "--title", title,
           "--body", body]
    for lbl in labels:
        cmd.extend(["--label", lbl])
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        opened.append({"cluster": c["cluster_key"], "url": result.stdout.strip()})
    except subprocess.CalledProcessError as e:
        failures.append({"cluster": c["cluster_key"], "error": e.stderr.strip()})

print()
print(f"Opened: {len(opened)} issue(s)")
for o in opened:
    print(f"  - {o[\"cluster\"]}: {o[\"url\"]}")
if failures:
    print(f"Failures: {len(failures)}", file=sys.stderr)
    for f in failures:
        print(f"  - {f[\"cluster\"]}: {f[\"error\"]}", file=sys.stderr)
    sys.exit(4)
'
