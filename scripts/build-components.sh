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
TARGET="all"
CHECK_MODE=false

# --- Parse arguments ---
# Note: do not seed TARGET from $1. The previous form `TARGET="${1:-all}"`
# silently set TARGET to `--check` when invoked as `bash ... --check`,
# which made every later `[ "$TARGET" = "all" ]` test fail and turned the
# whole --check mode into a silent no-op.
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

# --- Crewrig fork configuration ---
# Reads crewrig.config.toml at the repo root. Each `key = "value"` line becomes
# a CFG_<UPPERCASED_KEY> shell variable, and the placeholder ${UPPERCASED_KEY}
# in component sources resolves to its value at build time. Forks edit this
# file to redirect provenance/feedback URLs without touching the components.
CFG_KEYS=""
load_crewrig_config() {
  local config="$REPO_DIR/crewrig.config.toml"
  if [ ! -f "$config" ]; then
    echo "Warning: $config not found — placeholders will be left literal." >&2
    return 0
  fi
  while IFS='=' read -r raw_key raw_value; do
    local key
    key=$(printf '%s' "$raw_key" | tr -d '[:space:]')
    [ -z "$key" ] && continue
    case "$key" in \#*) continue ;; esac
    local value
    value=$(printf '%s' "$raw_value" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')
    local upper
    upper=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')
    printf -v "CFG_${upper}" '%s' "$value"
    CFG_KEYS="$CFG_KEYS $upper"
  done < "$config"
}

# Substitute ${KEY} placeholders in `content` with values loaded above.
# Sed-special characters in the value (`&`, `\`, `|`) are escaped first.
# Escaping the literal `\` is what protects against backreferences too:
# a value of `\1` becomes `\\1` after the escape, which sed reads as a
# literal backslash followed by `1` — not a backref. Bash 5.2+ builtin
# substitution `${var//pat/repl}` would have its own `&`-as-match trap
# that does not exist on bash 3.2 (macOS default), so sed is portable.
resolve_placeholders() {
  local content="$1"
  local key
  for key in $CFG_KEYS; do
    local var_name="CFG_${key}"
    local value="${!var_name}"
    local escaped
    escaped=$(printf '%s' "$value" | sed -e 's/[&\\|]/\\&/g')
    content=$(printf '%s' "$content" | sed "s|\${${key}}|${escaped}|g")
  done
  printf '%s' "$content"
}

load_crewrig_config

# --- Provenance propagation ---
# Components may declare a `provenance:` block in their source frontmatter.
# This block must travel to every output that supports YAML frontmatter, so
# installers and the harness curator can read where the component came from.
# The build only natively copies name+description, so we inject provenance
# explicitly at the bottom of the output frontmatter.

# Returns the provenance YAML block ready to splice into a frontmatter, or
# empty if `frontmatter` (already extracted) has no `provenance:` key.
# Takes the frontmatter as input so callers can reuse a single extraction.
provenance_block() {
  local frontmatter="$1"
  local has_prov
  has_prov=$(printf '%s\n' "$frontmatter" | yq -r 'has("provenance")' 2>/dev/null || echo "false")
  if [ "$has_prov" != "true" ]; then
    return 0
  fi
  printf 'provenance:\n'
  printf '%s\n' "$frontmatter" \
    | yq -r '.provenance | to_entries | .[] | "  " + .key + ": \"" + .value + "\""' 2>/dev/null
}

# Splice a provenance block before the closing `---` of the first frontmatter
# of `content`. No-op if the source has no provenance.
# Uses a tempfile to feed multi-line provenance into awk — BSD awk does not
# accept newlines in `-v var=...`, so we read the block via getline instead.
inject_provenance() {
  local content="$1"
  local source="$2"
  local frontmatter
  frontmatter=$(extract_frontmatter "$source")
  local prov
  prov=$(provenance_block "$frontmatter")
  if [ -z "$prov" ]; then
    printf '%s' "$content"
    return 0
  fi
  local prov_file
  prov_file=$(mktemp -t crewrig-prov.XXXXXX)
  printf '%s\n' "$prov" > "$prov_file"
  printf '%s' "$content" | awk -v provfile="$prov_file" '
    BEGIN {
      while ((getline line < provfile) > 0) {
        prov = (prov == "" ? line : prov "\n" line)
      }
      close(provfile)
      c = 0; injected = 0
    }
    /^---$/ {
      c++
      if (c == 2 && !injected) {
        print prov
        injected = 1
      }
    }
    { print }
  '
  rm -f "$prov_file"
}

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

# Compare file with expected content, report drift.
# When a source path is passed as $3, splices any `provenance:` block from
# that source into the output frontmatter before resolving placeholders.
check_or_write() {
  local target_file="$1"
  local content="$2"
  local source="${3:-}"

  if [ -n "$source" ]; then
    content=$(inject_provenance "$content" "$source")
  fi
  content=$(resolve_placeholders "$content")

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
      check_or_write "$REPO_DIR/.gemini/skills/$name/SKILL.md" "$gemini_content" "$source"
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
      check_or_write "$REPO_DIR/.claude/skills/$name/SKILL.md" "$claude_content" "$source"
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
      check_or_write "$REPO_DIR/.gemini/commands/$name.toml" "$toml_content" "$source"
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
      check_or_write "$REPO_DIR/.claude/skills/$name/SKILL.md" "$claude_content" "$source"
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

    # --- Gemini CLI output: <name>.md (flat file with YAML frontmatter) ---
    # Per https://geminicli.com/docs/core/subagents/#creating-custom-subagents
    # Gemini CLI requires a flat `.gemini/agents/<name>.md` file whose
    # frontmatter declares `name` and `description` (required) and optional
    # `tools`, `model`, etc. The body becomes the system prompt. A directory
    # layout or a frontmatter-less body is not discovered.
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
      check_or_write "$REPO_DIR/.gemini/agents/$name.md" "$gemini_content" "$source"
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
      check_or_write "$REPO_DIR/.claude/agents/$name/AGENT.md" "$claude_content" "$source"
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
