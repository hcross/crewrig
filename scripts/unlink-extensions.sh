#!/bin/bash
set -e

GEMINI_HOME="${HOME}/.gemini"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for dir in "$REPO_DIR"/extensions/*/; do
  name="$(basename "$dir")"
  target="$GEMINI_HOME/extensions/$name"
  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf "$target"
    echo "  Removed: $name"
  fi
done
