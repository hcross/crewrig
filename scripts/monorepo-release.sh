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

    # Architecture:
    #   monorepo-release.sh  → tag + CHANGELOG + git commit (this script)
    #   release-extension.yml → triggered by tag → package .tgz + GitHub Release
    #
    # semantic-release-gitmoji replaces BOTH commit-analyzer AND
    # release-notes-generator. They must NOT be listed alongside it.
    # semantic-release-monorepo is applied via "extends" and filters
    # commits to only those touching this extension's directory.
    # @semantic-release/github is NOT included here — the GitHub Release
    # is created by the release-extension.yml workflow triggered by the tag.
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
    "@semantic-release/changelog",
    ["@semantic-release/git", {
      "assets": ["package.json", "CHANGELOG.md"],
      "message": "🔖 ${EXT_NAME}-v\${nextRelease.version} [skip ci]\n\n\${nextRelease.notes}"
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
