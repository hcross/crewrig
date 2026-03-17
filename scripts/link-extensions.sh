#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

for dir in "$REPO_DIR"/extensions/*/; do
  [ -d "$dir" ] && bash "$REPO_DIR/scripts/install-extension.sh" link "$(basename "$dir")"
done
