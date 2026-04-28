#!/bin/bash
set -e

CLAUDE_HOME="${HOME}/.claude"
CLAUDE_RULES="${CLAUDE_HOME}/rules"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_MODE="copy"  # Default: copy (secure). Override with --link.

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --link) INSTALL_MODE="link"; shift ;;
    *)      shift ;;
  esac
done

echo "===================================="
echo "  Claude Code Configuration Setup"
echo "===================================="
echo ""

# --- Security disclaimer for link mode ---
if [ "$INSTALL_MODE" = "link" ]; then
  echo "WARNING: You are using symlink mode for system context files."
  echo "Symlinked files will change when you switch branches in this repository."
  echo "A malicious branch could alter your agent's behavior, permissions, and"
  echo "tool access without your knowledge."
  echo ""
  echo "Only use this mode if you TRUST ALL branches in this repository."
  echo "For production use, prefer copy mode (the default)."
  echo ""
  read -p "Continue with symlink mode? [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Run without --link for secure copy mode."
    exit 1
  fi
  echo ""
fi

mkdir -p "$CLAUDE_RULES"

# --- Prerequisites ---
command -v fzf >/dev/null 2>&1 || {
  echo "Error: fzf is required but not installed."
  echo "Install with: brew install fzf (macOS) or apt-get install fzf (Linux)"
  exit 1
}
command -v jq >/dev/null 2>&1 || {
  echo "Error: jq is required but not installed."
  echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
  exit 1
}

# --- Helper: timestamped backup of a file ---
backup_file() {
  local target="$1"
  if [ -f "$target" ]; then
    local stamp
    stamp="$(date +%Y%m%d-%H%M%S)"
    cp "$target" "${target}.bak.${stamp}"
    echo "  Backed up: ${target##*/} -> ${target##*/}.bak.${stamp}"
  fi
}

# --- Helper: install a file (copy or link) ---
install_file() {
  local source="$1" target="$2" label="$3"
  if [ "$INSTALL_MODE" = "link" ]; then
    ln -sfn "$source" "$target"
    echo "  Linked: $label"
  else
    cp "$source" "$target"
    echo "  Copied: $label"
  fi
}

# --- Clean existing rules if requested ---
EXISTING=$(find "$CLAUDE_RULES" -maxdepth 1 \( -type f -o -type l \) -name "*.md" 2>/dev/null)
if [ -n "$EXISTING" ]; then
  echo "Existing rule files found in $CLAUDE_RULES:"
  echo "$EXISTING" | sed "s|^$CLAUDE_RULES/|   - |"
  echo ""
  DELETE_EXISTING=$(echo -e "no\nyes" | fzf --height 10% --header "Remove existing rules before starting?")
  if [ "$DELETE_EXISTING" = "yes" ]; then
    find "$CLAUDE_RULES" -maxdepth 1 \( -type f -o -type l \) -name "*.md" -delete
    echo "Existing rules removed."
    echo ""
  fi
fi

# --- Shared enterprise configuration ---
echo "Installing shared configuration..."

# Organization context
install_file "$REPO_DIR/config/ORGANIZATION.md" "$CLAUDE_RULES/20-organization.md" \
  "ORGANIZATION.md -> rules/20-organization.md"

# Tools guidelines
install_file "$REPO_DIR/config/TOOLS.md" "$CLAUDE_RULES/60-tools.md" \
  "TOOLS.md -> rules/60-tools.md"

# SOUL.md (only if generated)
if [ -f "$REPO_DIR/config/SOUL.md" ]; then
  install_file "$REPO_DIR/config/SOUL.md" "$CLAUDE_RULES/00-soul.md" \
    "SOUL.md -> rules/00-soul.md"
fi
echo ""

# --- MCP server configuration ---
echo "Configuring MCP servers..."
MCP_TARGET="$CLAUDE_HOME/mcp.json"
if [ -f "$MCP_TARGET" ] && [ ! -L "$MCP_TARGET" ]; then
  mv "$MCP_TARGET" "${MCP_TARGET}.ori"
  echo "  Backed up existing mcp.json to mcp.json.ori"
fi
cp "$REPO_DIR/config/claude/mcp.json.template" "$MCP_TARGET"
echo "  Installed: mcp.json (Sequential Thinking)"
echo ""

# --- MemPalace MCP server (opt-in, requires explicit confirmation) ---
echo "MemPalace is the persistent agent memory used by this framework."
echo "If you confirm, the following entry will be added to:"
echo "    $MCP_TARGET"
echo ""
echo '    "mempalace": { "command": "python3", "args": ["-m", "mempalace.mcp_server"] }'
echo ""
echo "Prerequisite: the 'mempalace' Python package must be importable in your environment."
echo ""
INSTALL_MEMPALACE=$(echo -e "no\nyes" | fzf --height 10% --header "Install MemPalace MCP server now?")
if [ "$INSTALL_MEMPALACE" = "yes" ]; then
  backup_file "$MCP_TARGET"
  jq '.mcpServers.mempalace = {"command":"python3","args":["-m","mempalace.mcp_server"]}' \
    "$MCP_TARGET" > "${MCP_TARGET}.tmp" && mv "${MCP_TARGET}.tmp" "$MCP_TARGET"
  echo "  Installed: MemPalace MCP server"
  MEMPALACE_INSTALLED=1
else
  echo "  MemPalace install skipped."
  echo "  To install later: jq '.mcpServers.mempalace = {\"command\":\"python3\",\"args\":[\"-m\",\"mempalace.mcp_server\"]}' \\"
  echo "                      \$HOME/.claude/mcp.json > /tmp/m.json && mv /tmp/m.json \$HOME/.claude/mcp.json"
  MEMPALACE_INSTALLED=0
fi
echo ""

# --- Settings (optional) ---
SETTINGS_TARGET="$CLAUDE_HOME/settings.json"
if [ ! -f "$SETTINGS_TARGET" ]; then
  INSTALL_SETTINGS=$(echo -e "yes\nno" | fzf --height 10% --header "Install default settings.json?")
  if [ "$INSTALL_SETTINGS" = "yes" ]; then
    cp "$REPO_DIR/config/claude/settings.json.template" "$SETTINGS_TARGET"
    echo "  Installed: settings.json"
  fi
elif [ -f "$SETTINGS_TARGET" ]; then
  echo "  settings.json already exists, skipping."
fi
echo ""

# --- Team selection ---
echo "Select your team:"
TEAM=$(for f in "$REPO_DIR"/config/teams/*.md; do basename "$f" .md; done \
  | fzf --height 40% --preview "head -20 $REPO_DIR/config/teams/{}.md")
if [ -z "$TEAM" ]; then
  echo "No team selected. Aborting."
  exit 1
fi
install_file "$REPO_DIR/config/teams/${TEAM}.md" "$CLAUDE_RULES/50-team.md" \
  "teams/${TEAM}.md -> rules/50-team.md"
echo "$TEAM" > "$CLAUDE_HOME/.selected_team"
echo "Team: $TEAM"
echo ""

# --- Expertise selection ---
echo "Select your expertise:"
EXPERTISE=$(for f in "$REPO_DIR"/config/expertise/*.md; do basename "$f" .md; done \
  | fzf --height 40% --preview "head -20 $REPO_DIR/config/expertise/{}.md")
if [ -z "$EXPERTISE" ]; then
  echo "No expertise selected. Aborting."
  exit 1
fi
install_file "$REPO_DIR/config/expertise/${EXPERTISE}.md" "$CLAUDE_RULES/40-expertise.md" \
  "expertise/${EXPERTISE}.md -> rules/40-expertise.md"
echo "$EXPERTISE" > "$CLAUDE_HOME/.selected_expertise"
echo "Expertise: $EXPERTISE"
echo ""

# --- Level selection ---
echo "Select your experience level:"
LEVEL=$(for f in "$REPO_DIR"/config/level/*.md; do basename "$f" .md; done \
  | fzf --height 40% --preview "head -20 $REPO_DIR/config/level/{}.md")
if [ -z "$LEVEL" ]; then
  echo "No level selected. Aborting."
  exit 1
fi
install_file "$REPO_DIR/config/level/${LEVEL}.md" "$CLAUDE_RULES/10-level.md" \
  "level/${LEVEL}.md -> rules/10-level.md"
echo "$LEVEL" > "$CLAUDE_HOME/.selected_level"
echo "Level: $LEVEL"
echo ""

# --- Profile handling ---
TARGET="$CLAUDE_RULES/30-profile.md"
if [ ! -f "$REPO_DIR/config/PROFILE.md" ]; then
  echo "Personal profile not found: config/PROFILE.md"
  echo "Generate one with: claude /init-personal-profile"
  echo ""
elif [ ! -e "$TARGET" ]; then
  echo "Setting up personal profile..."
  install_file "$REPO_DIR/config/PROFILE.md" "$TARGET" \
    "PROFILE.md -> rules/30-profile.md"
elif [ -f "$TARGET" ]; then
  if [ -f "$REPO_DIR/config/PROFILE.md" ]; then
    if ! diff -q "$REPO_DIR/config/PROFILE.md" "$TARGET" >/dev/null 2>&1; then
      echo "Local profile differs from repository version."
      METHOD=$(echo -e "overwrite\nkeep-local" | fzf --height 10% --header "How to resolve?")
      if [ "$METHOD" = "overwrite" ]; then
        mv "$TARGET" "${TARGET}.ori"
        install_file "$REPO_DIR/config/PROFILE.md" "$TARGET" \
          "PROFILE.md -> rules/30-profile.md (backup saved as .ori)"
      elif [ "$METHOD" = "keep-local" ]; then
        echo "Keeping local profile."
      fi
    else
      echo "Profile is up to date."
    fi
  fi
fi

# --- Transcript hooks (opt-in) ---
echo ""
ENABLE_TRANSCRIPTS=$(echo -e "no\nyes" | fzf --height 10% --header "Enable automatic session recording to MemPalace? (opt-in)")
if [ "$ENABLE_TRANSCRIPTS" = "yes" ]; then
  HOOKS_SRC="$REPO_DIR/hooks/claude-transcript-hooks.json"
  echo ""
  echo "Activating transcript hooks will:"
  echo "  1. Backup $SETTINGS_TARGET to ${SETTINGS_TARGET}.bak.<timestamp>"
  echo "  2. Merge hooks from $HOOKS_SRC into $SETTINGS_TARGET"
  echo "     (UserPromptSubmit, PostToolUse, Stop, SessionEnd will run mempalace-transcript.sh)"
  echo "  3. Set env.MEMPALACE_TRANSCRIPT_ENABLED=\"1\" in $SETTINGS_TARGET"
  echo ""
  CONFIRM_TRANSCRIPTS=$(echo -e "no\nyes" | fzf --height 10% --header "Apply these changes to settings.json?")
  if [ "$CONFIRM_TRANSCRIPTS" = "yes" ]; then
    [ -f "$SETTINGS_TARGET" ] || echo "{}" > "$SETTINGS_TARGET"
    backup_file "$SETTINGS_TARGET"
    jq -s '.[0] * .[1] | .env = ((.env // {}) + {"MEMPALACE_TRANSCRIPT_ENABLED": "1"})' \
      "$SETTINGS_TARGET" "$HOOKS_SRC" > "${SETTINGS_TARGET}.tmp" && \
      mv "${SETTINGS_TARGET}.tmp" "$SETTINGS_TARGET"
    echo "  Transcript hooks merged into settings.json"
    echo "  MEMPALACE_TRANSCRIPT_ENABLED=1 set in settings.json env"
  else
    echo "  Transcript activation cancelled by user."
  fi
else
  echo "  Session recording disabled (can enable later by re-running this script)."
fi

echo ""
echo "===================================="
echo "  Setup complete"
echo "===================================="
echo ""
echo "Install mode: $INSTALL_MODE"
echo ""
echo "Active rule files:"
ls -1 "$CLAUDE_RULES"/*.md 2>/dev/null || echo "  (none)"
echo ""
echo "MCP servers:"
if [ -f "$CLAUDE_HOME/mcp.json" ]; then
  grep -o '"[^"]*":' "$CLAUDE_HOME/mcp.json" | head -10 | sed 's/[":{}]//g; s/^/  - /' | grep -v mcpServers
else
  echo "  (none)"
fi
echo ""
echo "Next steps:"
echo "  - Run 'claude /init-soul' to customize your agent identity"
echo "  - Run 'claude /init-personal-profile' to create your profile"
if [ "${MEMPALACE_INSTALLED:-0}" -ne 1 ]; then
  echo "  - MemPalace MCP server is NOT installed (skipped during setup)."
fi
