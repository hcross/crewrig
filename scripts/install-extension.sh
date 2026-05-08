#!/bin/bash
set -e

GEMINI_HOME="${HOME}/.gemini"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-install}"
EXT="$2"

mkdir -p "$GEMINI_HOME/extensions"

do_install() {
  local name="$1"
  local target="$GEMINI_HOME/extensions/$name"

  [ -e "$target" ] || [ -L "$target" ] && rm -rf "$target"

  if [ "$MODE" = "link" ]; then
    ln -s "$REPO_DIR/extensions/$name" "$target"
    echo "  Linked: $name"
  else
    cp -rf "$REPO_DIR/extensions/$name" "$target"
    echo "  Copied: $name"
  fi
}

if [ -n "$EXT" ]; then
  if [ ! -d "$REPO_DIR/extensions/$EXT" ]; then
    echo "Error: extension '$EXT' not found." >&2
    exit 1
  fi
  do_install "$EXT"
else
  for dir in "$REPO_DIR"/extensions/*/; do
    [ -d "$dir" ] && do_install "$(basename "$dir")"
  done
fi
