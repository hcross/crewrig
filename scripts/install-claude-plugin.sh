#!/bin/bash
# install-claude-plugin.sh — Install a Claude Code plugin from an extension
#
# Usage:
#   bash scripts/install-claude-plugin.sh <extension-name> [--link]
#
# Builds the Claude Code plugin from extension.json, then copies (default)
# or symlinks (--link, dev only) it to ~/.claude/plugins/<name>/.
#
# Prerequisites: jq

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_PLUGINS="${HOME}/.claude/plugins"
EXT_NAME="${1:?Usage: install-claude-plugin.sh <extension-name> [--link]}"
LINK_MODE=false

if [ "${2:-}" = "--link" ]; then
  LINK_MODE=true
fi

EXT_DIR="$REPO_DIR/extensions/$EXT_NAME"
if [ ! -d "$EXT_DIR" ]; then
  echo "Error: Extension '$EXT_NAME' not found in extensions/"
  exit 1
fi

# --- Build the plugin ---
BUILD_DIR="$EXT_DIR/dist-claude-plugin/$EXT_NAME"
bash "$REPO_DIR/scripts/build-claude-plugin.sh" "$EXT_DIR" "$BUILD_DIR"

# --- Install ---
mkdir -p "$CLAUDE_PLUGINS"
TARGET="$CLAUDE_PLUGINS/$EXT_NAME"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  rm -rf "$TARGET"
fi

if [ "$LINK_MODE" = true ]; then
  # --- Security disclaimer for link mode ---
  echo ""
  echo "WARNING: You are using symlink mode for a Claude Code plugin."
  echo "Plugin files will change when you switch branches in this repository."
  echo "A malicious branch could alter the plugin's behavior."
  echo ""
  echo "Only use this mode if you TRUST ALL branches in this repository."
  echo "For production use, prefer copy mode (the default)."
  echo ""
  read -p "Continue with symlink mode? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Use copy mode instead (omit --link)."
    exit 1
  fi

  ln -s "$BUILD_DIR" "$TARGET"
  echo "Linked: $BUILD_DIR -> $TARGET"
else
  cp -r "$BUILD_DIR" "$TARGET"
  echo "Copied: $BUILD_DIR -> $TARGET"
fi

echo ""
echo "Plugin installed: $TARGET"
echo "Restart Claude Code or run /reload-plugins to pick up changes."
