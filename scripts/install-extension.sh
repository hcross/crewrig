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
  [ ! -d "$REPO_DIR/extensions/$EXT" ] && echo "Error: extension '$EXT' not found." && exit 1
  do_install "$EXT"
else
  for dir in "$REPO_DIR"/extensions/*/; do
    [ -d "$dir" ] && do_install "$(basename "$dir")"
  done
fi
