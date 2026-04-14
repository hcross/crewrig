#!/bin/bash
# manage-claude-component.sh — Install or link Claude Code community components
#
# Usage:
#   bash scripts/manage-claude-component.sh <install|link> <type> [name]
#
# Types: claude-skills, policies, mcp-servers
# Default mode: install (copy). Link mode shows security disclaimer.

set -e

CLAUDE_HOME="${HOME}/.claude"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-install}"
TYPE="$2"
NAME="$3"

if [ -z "$TYPE" ]; then
  echo "Usage: $0 <install|link> <type> [name]"
  echo "Types: claude-skills, policies, mcp-servers"
  exit 1
fi

# --- Security disclaimer for link mode ---
if [ "$MODE" = "link" ]; then
  echo "WARNING: Symlink mode — files change with branch switches."
  echo "Only use if you trust all branches in this repository."
  read -p "Continue? [y/N] " -n 1 -r
  echo ""
  [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

# --- Normalize type ---
case "$TYPE" in
  claude-skill)  TYPE="claude-skills" ;;
  policy)        TYPE="policies" ;;
  mcp-server)    TYPE="mcp-servers" ;;
esac

SRC_DIR="$REPO_DIR/community-config/$TYPE"
if [ ! -d "$SRC_DIR" ]; then
  # For claude-skills, source may be generated output in .claude/skills/
  SRC_DIR="$REPO_DIR/.claude/skills"
  if [ ! -d "$SRC_DIR" ]; then
    echo "Error: source directory not found for type '$TYPE'"
    exit 1
  fi
fi

# --- Place a file or directory ---
place_component() {
  local src="$1" dest_dir="$2"
  local item_name
  item_name=$(basename "$src")
  [ "$item_name" = ".gitkeep" ] && return

  [ -e "$dest_dir/$item_name" ] || [ -L "$dest_dir/$item_name" ] && rm -rf "$dest_dir/$item_name"

  if [ "$MODE" = "link" ]; then
    ln -s "$src" "$dest_dir/$item_name"
    echo "  Linked: $item_name"
  else
    cp -rf "$src" "$dest_dir/"
    echo "  Copied: $item_name"
  fi
}

# --- Merge JSON into mcp.json ---
merge_mcp_json() {
  local json_file="$1"
  local mcp_target="$CLAUDE_HOME/mcp.json"

  command -v jq >/dev/null 2>&1 || { echo "Error: jq required for JSON merging."; exit 1; }

  [ ! -f "$mcp_target" ] && echo '{"mcpServers":{}}' > "$mcp_target"

  local entry_name
  entry_name=$(basename "$json_file" .json)

  cp "$mcp_target" "${mcp_target}.bak"
  jq --arg name "$entry_name" \
     --slurpfile val "$json_file" \
     '.mcpServers = ((.mcpServers // {}) + {($name): $val[0]})' \
     "${mcp_target}.bak" > "$mcp_target"

  echo "  Merged: $entry_name into mcp.json"
}

# --- Dispatch by type ---
case "$TYPE" in
  claude-skills)
    DEST="$CLAUDE_HOME/skills"
    mkdir -p "$DEST"

    if [ -n "$NAME" ]; then
      [ -d "$SRC_DIR/$NAME" ] || { echo "Error: '$NAME' not found"; exit 1; }
      place_component "$SRC_DIR/$NAME" "$DEST"
    else
      for item in "$SRC_DIR"/*/; do
        [ -d "$item" ] && place_component "$item" "$DEST"
      done
    fi
    ;;

  policies)
    DEST="$CLAUDE_HOME/rules"
    mkdir -p "$DEST"

    if [ -n "$NAME" ]; then
      for candidate in "$SRC_DIR/$NAME" "$SRC_DIR/$NAME.md"; do
        if [ -e "$candidate" ]; then
          place_component "$candidate" "$DEST"
          break
        fi
      done
    else
      for item in "$SRC_DIR"/*; do
        [ -e "$item" ] && place_component "$item" "$DEST"
      done
    fi
    ;;

  mcp-servers)
    if [ -n "$NAME" ]; then
      JSON="$SRC_DIR/$NAME.json"
      [ ! -f "$JSON" ] && { echo "Error: '$NAME.json' not found"; exit 1; }
      merge_mcp_json "$JSON"
    else
      for item in "$SRC_DIR"/*.json; do
        [ -f "$item" ] && merge_mcp_json "$item"
      done
    fi
    ;;

  *)
    echo "Error: unknown type '$TYPE'"
    echo "Types: claude-skills, policies, mcp-servers"
    exit 1
    ;;
esac
