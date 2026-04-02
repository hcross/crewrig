#!/bin/bash
set -e

CLAUDE_HOME="${HOME}/.claude"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-install}"   # "install" (copy) or "link" (symlink)
TYPE="$2"
NAME="$3"

if [ -z "$TYPE" ]; then
  echo "Usage: $0 <install|link> <type> [name]"
  echo "Types: claude-skills, policies, mcp-servers"
  exit 1
fi

# Normalize singular/plural
case "$TYPE" in
  claude-skill)  TYPE="claude-skills" ;;
  policy)        TYPE="policies" ;;
  mcp-server)    TYPE="mcp-servers" ;;
esac

SRC_DIR="$REPO_DIR/community-config/$TYPE"

if [ ! -d "$SRC_DIR" ]; then
  echo "Error: directory community-config/$TYPE does not exist."
  exit 1
fi

# --- File/directory component (skills, policies) ---
place_component() {
  local src="$1"
  local dest_dir="$2"
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

# --- JSON merge component (mcp-servers) ---
merge_mcp_json() {
  local json_file="$1"
  local mcp_target="$CLAUDE_HOME/mcp.json"
  local entry_name
  entry_name=$(basename "$json_file" .json)

  if ! command -v jq >/dev/null 2>&1; then
    echo "  Error: jq is required for merging JSON components."
    exit 1
  fi

  [ ! -f "$mcp_target" ] && echo '{"mcpServers":{}}' > "$mcp_target"

  cp "$mcp_target" "${mcp_target}.bak"
  jq --arg name "$entry_name" \
     --slurpfile val "$json_file" \
     '.mcpServers = ((.mcpServers // {}) + {($name): $val[0]})' \
     "${mcp_target}.bak" > "$mcp_target"

  echo "  Merged: $entry_name into mcp.json"
}

# --- Dispatch ---
case "$TYPE" in
  claude-skills)
    DEST="$CLAUDE_HOME/skills"
    mkdir -p "$DEST"

    if [ -n "$NAME" ]; then
      FOUND=""
      for candidate in "$SRC_DIR/$NAME" "$SRC_DIR/$NAME.md"; do
        if [ -e "$candidate" ]; then
          place_component "$candidate" "$DEST"
          FOUND=1
          break
        fi
      done
      [ -z "$FOUND" ] && echo "Error: '$NAME' not found in community-config/$TYPE" && exit 1
    else
      for item in "$SRC_DIR"/*; do
        [ -e "$item" ] && place_component "$item" "$DEST"
      done
    fi
    ;;

  policies)
    DEST="$CLAUDE_HOME/rules"
    mkdir -p "$DEST"

    if [ -n "$NAME" ]; then
      FOUND=""
      for candidate in "$SRC_DIR/$NAME" "$SRC_DIR/$NAME.md"; do
        if [ -e "$candidate" ]; then
          place_component "$candidate" "$DEST"
          FOUND=1
          break
        fi
      done
      [ -z "$FOUND" ] && echo "Error: '$NAME' not found in community-config/$TYPE" && exit 1
    else
      for item in "$SRC_DIR"/*; do
        [ -e "$item" ] && place_component "$item" "$DEST"
      done
    fi
    ;;

  mcp-servers)
    if [ -n "$NAME" ]; then
      JSON="$SRC_DIR/$NAME.json"
      [ ! -f "$JSON" ] && echo "Error: '$NAME.json' not found in community-config/$TYPE" && exit 1
      merge_mcp_json "$JSON"
    else
      for item in "$SRC_DIR"/*.json; do
        [ -f "$item" ] && merge_mcp_json "$item"
      done
    fi
    ;;

  *)
    echo "Error: unknown component type '$TYPE'"
    echo "Supported types: claude-skills, policies, mcp-servers"
    exit 1
    ;;
esac
