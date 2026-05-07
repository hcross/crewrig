#!/bin/bash
# prune-transcripts.sh — Prune old session transcripts from MemPalace
#
# Usage:
#   bash scripts/prune-transcripts.sh [--days <days>] [--apply] [--project <name>]
#
# Options:
#   --days     Retention period in days (default: 30)
#   --apply    Actually delete drawers (dry-run mode by default)
#   --project  Prune only a specific project's transcripts (default: all)
#
# Environment:
#   MEMPALACE_PYTHON - Python binary with mempalace installed (default: python3)
#
# This script operates via the MemPalace MCP surface (tool_list_drawers,
# tool_delete_drawer), NOT the CLI binary. Per the MCP-only access rule in
# config/TOOLS.md, agents must use the MCP tools for all MemPalace operations.
#
# Transcript room format: <project>-<date>-<sid>
# This format allows date-based filtering. Rooms older than --days are deleted.

set -euo pipefail

# --- Configuration ---
DEFAULT_DAYS=30
DRY_RUN=true
PROJECT_FILTER=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      DAYS="$2"
      shift 2
      ;;
    --apply)
      DRY_RUN=false
      shift
      ;;
    --project)
      PROJECT_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--days <days>] [--apply] [--project <name>]"
      echo ""
      echo "Options:"
      echo "  --days     Retention period in days (default: 30)"
      echo "  --apply    Actually delete drawers (dry-run mode by default)"
      echo "  --project  Prune only a specific project's transcripts (default: all)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

DAYS="${DAYS:-$DEFAULT_DAYS}"

# --- Validate ---
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "Error: --days must be a positive integer" >&2
  exit 1
fi

if [ "$DAYS" -lt 1 ]; then
  echo "Error: --days must be at least 1" >&2
  exit 1
fi

# --- Dependencies ---
MEMPALACE_PYTHON="${MEMPALACE_PYTHON:-python3}"

command -v "$MEMPALACE_PYTHON" >/dev/null 2>&1 || {
  echo "Error: $MEMPALACE_PYTHON not found" >&2
  exit 1
}

# --- Execute prune via MemPalace MCP tools ---
TRANSCRIPTS_WING="transcripts"
CUTOFF_DATE=$(date -v-${DAYS}d +%Y-%m-%d 2>/dev/null || date -d "-${DAYS} days" +%Y-%m-%d)

echo "========================================="
echo "  Transcript Prune"
echo "========================================="
echo "Wing:        $TRANSCRIPTS_WING"
echo "Cutoff date: $CUTOFF_DATE (older than $DAYS days)"
echo "Dry run:     $DRY_RUN"
[ -n "$PROJECT_FILTER" ] && echo "Project:      $PROJECT_FILTER (filter only)"
echo ""

# List and potentially delete drawers via MCP
OUTPUT=$(
  TRANSCRIPTS_WING="$TRANSCRIPTS_WING" \
  PROJECT_FILTER="$PROJECT_FILTER" \
  CUTOFF_DATE="$CUTOFF_DATE" \
  DRY_RUN="$DRY_RUN" \
  "$MEMPALACE_PYTHON" - 2>&1 <<PYEOF
import os, sys
from datetime import datetime

try:
    from mempalace.mcp_server import tool_list_drawers, tool_delete_drawer
except ImportError as e:
    print(f"IMPORT_ERROR: {e}", file=sys.stderr)
    sys.exit(2)

wing = os.environ["TRANSCRIPTS_WING"]
project_filter = os.environ.get("PROJECT_FILTER", "")
cutoff_date = os.environ["CUTOFF_DATE"]
dry_run = os.environ["DRY_RUN"].lower() == "true"

# Parse cutoff date once
try:
    cutoff_dt = datetime.strptime(cutoff_date, "%Y-%m-%d")
except ValueError:
    print(f"ERROR: Invalid cutoff date format: {cutoff_date}", file=sys.stderr)
    sys.exit(2)

# List all drawers in transcripts wing
list_result = tool_list_drawers(wing=wing)

if not list_result.get("success"):
    print(f"LIST_FAILED: {list_result.get('error', 'unknown')}", file=sys.stderr)
    sys.exit(3)

drawers = list_result.get("drawers", [])
print(f"Found {len(drawers)} drawer(s) in wing '{wing}'")

to_delete = []
for drawer in drawers:
    drawer_id = drawer.get("drawer_id")
    room = drawer.get("room")
    
    # Extract date from room format: <project>-<date>-<sid>
    # Skip if room format doesn't match
    if not room:
        continue
    
    # Parse room name to extract project and date
    parts = room.split("-")
    if len(parts) < 2:
        continue
    
    # Last 8 chars are session ID prefix, rest is project-date
    # Format: <project>-<date>-<sid>
    # Reconstruct: join all but last, then split last from date
    date_part = parts[-2] if len(parts) >= 2 else parts[-1]
    project_name = "-".join(parts[:-2]) if len(parts) > 2 else parts[0]
    
    # Parse date part (expects YYYY-MM-DD)
    try:
        date_part_full = date_part
        if date_part_part := [date_part[i:i+2] for i in range(0, len(date_part), 2)]:
            pass
        drawer_dt = datetime.strptime(date_part, "%Y-%m-%d")
    except ValueError:
        # Skip rooms that don't match expected date format
        continue
    
    # Apply project filter if set
    if project_filter and project_name != project_filter:
        continue
    
    # Check if drawer is older than cutoff
    if drawer_dt < cutoff_dt:
        to_delete.append((drawer_id, room, drawer_dt))

if not to_delete:
    print("No drawers to delete.")
    sys.exit(0)

print(f"Candidate for deletion: {len(to_delete)} drawer(s) older than {cutoff_date}")

if dry_run:
    print("DRY RUN - would delete:")
    for drawer_id, room, drawer_dt in to_delete:
        print(f"  - {room} (id={drawer_id}, date={drawer_dt.strftime('%Y-%m-%d')})")
else:
    deleted_count = 0
    failed_count = 0
    for drawer_id, room, drawer_dt in to_delete:
        delete_result = tool_delete_drawer(drawer_id=drawer_id)
        if delete_result.get("success"):
            print(f"Deleted: {room} (id={drawer_id}, date={drawer_dt.strftime('%Y-%m-%d')})")
            deleted_count += 1
        else:
            print(f"FAILED to delete {room} (id={drawer_id}): {delete_result.get('error', 'unknown')}", file=sys.stderr)
            failed_count += 1
    
    print(f"Deleted: {deleted_count} drawer(s)")
    if failed_count > 0:
        print(f"FAILED: {failed_count} drawer(s)", file=sys.stderr)
        sys.exit(4)
PYEOF
)

EXIT_CODE=$?
echo "$OUTPUT"
exit $EXIT_CODE
