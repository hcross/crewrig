#!/bin/bash
set -e

SR_ARGS=""
if [ "$DRY_RUN" = "true" ]; then
  echo "DRY RUN mode enabled"
  SR_ARGS="--dry-run"
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Branch: $CURRENT_BRANCH"

ROOT_DIR=$(pwd)
export NODE_PATH="$ROOT_DIR/node_modules"

ERRORS=0

for dir in extensions/*/; do
  if [ -f "${dir}package.json" ]; then
    EXT_NAME=$(basename "$dir")
    echo ""
    echo "--- Analyzing: $EXT_NAME ---"

    cat <<EOF > "${dir}.releaserc.json"
{
  "extends": "semantic-release-monorepo",
  "branches": ["$CURRENT_BRANCH"],
  "tagFormat": "${EXT_NAME}-v\${version}",
  "plugins": [
    ["semantic-release-gitmoji", {
      "releaseRules": {
        "major": [":boom:"],
        "minor": [":sparkles:"],
        "patch": [":bug:", ":ambulance:", ":lock:", ":zap:"]
      }
    }],
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/changelog",
    ["@semantic-release/github", {}],
    ["@semantic-release/git", {
      "assets": ["package.json", "CHANGELOG.md"],
      "message": "🔖 \${nextRelease.version} [skip ci]\n\n\${nextRelease.notes}"
    }]
  ]
}
EOF

    cd "$dir"

    if ! npx semantic-release $SR_ARGS --branches "$CURRENT_BRANCH"; then
      echo "Error: semantic-release failed for $EXT_NAME"
      ERRORS=1
    fi

    rm -f .releaserc.json
    cd "$ROOT_DIR"
  fi
done

echo ""
if [ $ERRORS -ne 0 ]; then
  echo "Release analysis completed WITH ERRORS."
  exit 1
fi

echo "Release analysis completed successfully."
