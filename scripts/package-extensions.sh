#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for dir in "$REPO_DIR"/extensions/*/; do
  if [ -d "$dir" ]; then
    EXT="$(basename "$dir")" bash "$REPO_DIR/scripts/package-extension.sh"
  fi
done
