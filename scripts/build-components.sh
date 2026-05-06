#!/bin/bash
# build-components.sh — Build community components for Gemini CLI and/or Claude Code
#
# Usage:
#   bash scripts/build-components.sh [--target gemini|claude|all] [--check]
#
# Options:
#   --target   Which tool to generate for (default: all)
#   --check    Verify generated files match source (drift detection, for CI)
#
# Prerequisites: yq, jq

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMMUNITY_DIR="$REPO_DIR/community-config"
TARGET="${1:-all}"
CHECK_MODE=false

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --check)  CHECK_MODE=true; shift ;;
    *)        shift ;;
  esac
done

# --- Prerequisites ---
command -v yq >/dev/null 2>&1 || { echo "Error: yq is required. Install with: brew install yq"; exit 1; }

DRIFT_FOUND=false

# --- Helpers ---

# Extract YAML frontmatter from a Markdown file (between first two ---)
extract_frontmatter() {
  sed -n '/^---$/,/^---$/p' "$1" | sed '1d;$d'
}

# Extract body from a Markdown file (everything after second ---)
extract_body() {
  sed '1,/^---$/!d' "$1" | wc -l > /dev/null  # skip first ---
  awk 'BEGIN{c=0} /^---$/{c++; if(c==2){found=1; next}} found{print}' "$1"
}

# Read a YAML field from frontmatter
yaml_field() {
  local file="$1" field="$2"
  extract_frontmatter "$file" | yq -r ".$field" 2>/dev/null || echo ""
}

# Read a nested YAML field
yaml_nested() {
  local file="$1" field="$2"
  local result
  result=$(extract_frontmatter "$file" | yq -r "$field" 2>/dev/null)
  if [ "$result" = "null" ] || [ -z "$result" ]; then
    echo ""
  else
    echo "$result"
  fi
}

# Compare file with expected content, report drift
check_or_write() {
  local target_file="$1"
  local content="$2"

  if [ "$CHECK_MODE" = true ]; then
    if [ ! -f "$target_file" ]; then
      echo "DRIFT: $target_file does not exist (expected from source)"
      DRIFT_FOUND=true
      return
    fi
    if ! echo "$content" | diff -q - "$target_file" >/dev/null 2>&1; then
      echo "DRIFT: $target_file differs from source"
      DRIFT_FOUND=true
      return
    fi
  else
    mkdir -p "$(dirname "$target_file")"
    echo "$content" > "$target_file"
    echo "  Generated: $target_file"
  fi
}

# --- Build Skills ---
build_skills() {
  local skills_dir="$COMMUNITY_DIR/skills"
  [ ! -d "$skills_dir" ] && return

  for skill_dir in "$skills_dir"/*/; do
    [ ! -d "$skill_dir" ] && continue
    local source="$skill_dir/SKILL.md"
    [ ! -f "$source" ] && continue

    local name
    name=$(yaml_field "$source" "name")
    local description
    description=$(yaml_field "$source" "description")
    local body
    body=$(extract_body "$source")

    [ -z "$name" ] && { echo "Warning: $source missing 'name' field, skipping"; continue; }

    echo "Building skill: $name"

    # --- Gemini CLI output ---
    if [ "$TARGET" = "gemini" ] || [ "$TARGET" = "all" ]; then
      local gemini_content
      gemini_content=$(cat <<GEMINI_EOF
---
name: $name
description: "$description"
---

$body
GEMINI_EOF
      )
      check_or_write "$REPO_DIR/.gemini/skills/$name/SKILL.md" "$gemini_content"
    fi

    # --- Claude Code output ---
    if [ "$TARGET" = "claude" ] || [ "$TARGET" = "all" ]; then
      local claude_frontmatter="name: $name
description: \"$description\""

      # Add Claude-specific fields if present
      local allowed_tools
      allowed_tools=$(extract_frontmatter "$source" | yq -r '.claude.allowed-tools // [] | .[]' 2>/dev/null)
      if [ -n "$allowed_tools" ]; then
        claude_frontmatter="$claude_frontmatter
allowed-tools:"
        while IFS= read -r tool; do
          claude_frontmatter="$claude_frontmatter
  - $tool"
        done <<< "$allowed_tools"
      fi

      local user_invocable
      user_invocable=$(yaml_nested "$source" '.claude.user-invocable')
      if [ -n "$user_invocable" ]; then
        claude_frontmatter="$claude_frontmatter
user-invocable: $user_invocable"
      fi

      local disable_model
      disable_model=$(yaml_nested "$source" '.claude.disable-model-invocation')
      if [ -n "$disable_model" ]; then
        claude_frontmatter="$claude_frontmatter
disable-model-invocation: $disable_model"
      fi

      local context
      context=$(yaml_nested "$source" '.claude.context')
      if [ -n "$context" ]; then
        claude_frontmatter="$claude_frontmatter
context: $context"
      fi

      local agent
      agent=$(yaml_nested "$source" '.claude.agent')
      if [ -n "$agent" ]; then
        claude_frontmatter="$claude_frontmatter
agent: $agent"
      fi

      local claude_content
      claude_content=$(cat <<CLAUDE_EOF
---
$claude_frontmatter
---

$body
CLAUDE_EOF
      )
      check_or_write "$REPO_DIR/.claude/skills/$name/SKILL.md" "$claude_content"
    fi
  done
}

# --- Build Commands ---
build_commands() {
  local commands_dir="$COMMUNITY_DIR/commands"
  [ ! -d "$commands_dir" ] && return

  for source in "$commands_dir"/*.md; do
    [ ! -f "$source" ] && continue

    local name
    name=$(yaml_field "$source" "name")
    local description
    description=$(yaml_field "$source" "description")
    local body
    body=$(extract_body "$source")

    [ -z "$name" ] && { echo "Warning: $source missing 'name' field, skipping"; continue; }

    echo "Building command: $name"

    # --- Gemini CLI output: TOML ---
    if [ "$TARGET" = "gemini" ] || [ "$TARGET" = "all" ]; then
      local toml_content
      toml_content="description = \"$description\"

prompt = \"\"\"
$body
\"\"\""
      check_or_write "$REPO_DIR/.gemini/commands/$name.toml" "$toml_content"
    fi

    # --- Claude Code output: SKILL.md ---
    if [ "$TARGET" = "claude" ] || [ "$TARGET" = "all" ]; then
      local claude_frontmatter="name: $name
description: \"$description\"
user-invocable: true"

      local allowed_tools
      allowed_tools=$(extract_frontmatter "$source" | yq -r '.claude.allowed-tools // [] | .[]' 2>/dev/null)
      if [ -n "$allowed_tools" ]; then
        claude_frontmatter="$claude_frontmatter
allowed-tools:"
        while IFS= read -r tool; do
          claude_frontmatter="$claude_frontmatter
  - $tool"
        done <<< "$allowed_tools"
      fi

      local claude_content
      claude_content=$(cat <<CLAUDE_EOF
---
$claude_frontmatter
---

$body
CLAUDE_EOF
      )
      check_or_write "$REPO_DIR/.claude/skills/$name/SKILL.md" "$claude_content"
    fi
  done
}

# --- Build Agents ---
build_agents() {
  local agents_dir="$COMMUNITY_DIR/agents"
  [ ! -d "$agents_dir" ] && return

  for agent_dir in "$agents_dir"/*/; do
    [ ! -d "$agent_dir" ] && continue
    local source="$agent_dir/AGENT.md"
    [ ! -f "$source" ] && continue

    local name
    name=$(yaml_field "$source" "name")
    local description
    description=$(yaml_field "$source" "description")
    local body
    body=$(extract_body "$source")

    [ -z "$name" ] && { echo "Warning: $source missing 'name' field, skipping"; continue; }

    echo "Building agent: $name"

    # --- Gemini CLI output: PROMPT.md (body only) ---
    if [ "$TARGET" = "gemini" ] || [ "$TARGET" = "all" ]; then
      check_or_write "$REPO_DIR/agents/$name/PROMPT.md" "$body"
    fi

    # --- Claude Code output: AGENT.md (with frontmatter) ---
    if [ "$TARGET" = "claude" ] || [ "$TARGET" = "all" ]; then
      local claude_content
      claude_content=$(cat <<CLAUDE_EOF
---
name: $name
description: "$description"
---

$body
CLAUDE_EOF
      )
      check_or_write "$REPO_DIR/.claude/agents/$name/AGENT.md" "$claude_content"
    fi
  done
}

# --- Main ---
echo "========================================="
echo "  Community Component Builder"
echo "  Target: $TARGET"
if [ "$CHECK_MODE" = true ]; then
  echo "  Mode: CHECK (drift detection)"
else
  echo "  Mode: BUILD (generate files)"
fi
echo "========================================="
echo ""

build_skills
build_commands
build_agents

echo ""
if [ "$CHECK_MODE" = true ]; then
  if [ "$DRIFT_FOUND" = true ]; then
    echo "FAILED: Drift detected. Run 'bash scripts/build-components.sh' to regenerate."
    exit 1
  else
    echo "OK: All generated files match source."
    exit 0
  fi
else
  echo "Done."
fi
