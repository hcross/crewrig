#!/bin/bash
set -e

CLAUDE_HOME="${HOME}/.claude"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-install}"
EXT="$2"

mkdir -p "$CLAUDE_HOME/skills"

# --- jq is required for MCP server merging ---
require_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq is required for merging MCP server configuration."
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
  }
}

# --- Merge MCP servers from extension manifest into ~/.claude/mcp.json ---
merge_mcp_servers() {
  local manifest="$1"
  local mcp_target="$CLAUDE_HOME/mcp.json"
  local ext_dir
  ext_dir=$(dirname "$manifest")

  # Check if manifest has mcpServers
  if ! jq -e '.mcpServers' "$manifest" >/dev/null 2>&1; then
    return
  fi

  [ ! -f "$mcp_target" ] && echo '{"mcpServers":{}}' > "$mcp_target"

  # Transform MCP server entries: resolve relative paths to absolute
  local servers
  servers=$(jq --arg dir "$ext_dir" '
    .mcpServers | to_entries | map({
      key: .key,
      value: (
        .value + {
          "type": "stdio",
          "command": .value.command,
          "args": [($dir + "/" + .value.args[0])] + .value.args[1:]
        }
      )
    }) | from_entries
  ' "$manifest")

  cp "$mcp_target" "${mcp_target}.bak"
  jq --argjson servers "$servers" '
    .mcpServers = ((.mcpServers // {}) + $servers)
  ' "${mcp_target}.bak" > "$mcp_target"

  echo "  Merged MCP servers into mcp.json"
}

# --- Install skills from extension ---
install_skills() {
  local ext_dir="$1"
  local ext_name="$2"

  if [ ! -d "$ext_dir/skills" ]; then
    return
  fi

  for skill_dir in "$ext_dir"/skills/*/; do
    [ ! -d "$skill_dir" ] && continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    local target="$CLAUDE_HOME/skills/${ext_name}-${skill_name}"

    [ -e "$target" ] || [ -L "$target" ] && rm -rf "$target"

    if [ "$MODE" = "link" ]; then
      ln -s "$skill_dir" "$target"
      echo "  Linked skill: ${ext_name}-${skill_name}"
    else
      cp -rf "$skill_dir" "$target"
      echo "  Copied skill: ${ext_name}-${skill_name}"
    fi
  done
}

# --- Process a single extension ---
do_install() {
  local name="$1"
  local ext_dir="$REPO_DIR/extensions/$name"
  local manifest="$ext_dir/gemini-extension.json"

  echo "Installing extension: $name"

  # MCP servers
  if [ -f "$manifest" ]; then
    require_jq
    merge_mcp_servers "$manifest"
  fi

  # Skills
  install_skills "$ext_dir" "$name"

  echo "  Done: $name"
}

# --- Main ---
if [ -n "$EXT" ]; then
  [ ! -d "$REPO_DIR/extensions/$EXT" ] && echo "Error: extension '$EXT' not found." && exit 1
  do_install "$EXT"
else
  for dir in "$REPO_DIR"/extensions/*/; do
    [ -d "$dir" ] && do_install "$(basename "$dir")"
  done
fi
