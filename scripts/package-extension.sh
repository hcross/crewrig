#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -z "$EXT" ]; then
  echo "Error: EXT variable is required (e.g., EXT=hello-world)."
  exit 1
fi

[ ! -d "$REPO_DIR/extensions/$EXT" ] && echo "Error: extension '$EXT' not found." && exit 1

mkdir -p "$REPO_DIR/dist"
cd "$REPO_DIR/extensions/$EXT" && npm pack --pack-destination "$REPO_DIR/dist"
echo "Packaged: $EXT"
