#!/bin/bash
set -e

CLAUDE_HOME="${HOME}/.claude"
CLAUDE_RULES="${CLAUDE_HOME}/rules"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "===================================="
echo "  Claude Code Configuration Setup"
echo "===================================="
echo ""
mkdir -p "$CLAUDE_RULES"

# --- Prerequisites ---
command -v fzf >/dev/null 2>&1 || {
  echo "Error: fzf is required but not installed."
  echo "Install with: brew install fzf (macOS) or apt-get install fzf (Linux)"
  exit 1
}

# --- Clean existing symlinks if requested ---
LINKS=$(find "$CLAUDE_RULES" -maxdepth 1 -type l 2>/dev/null)
if [ -n "$LINKS" ]; then
  echo "Existing symbolic links found in $CLAUDE_RULES:"
  echo "$LINKS" | sed "s|^$CLAUDE_RULES/|   - |"
  echo ""
  DELETE_LINKS=$(echo -e "no\nyes" | fzf --height 10% --header "Remove existing links before starting?")
  if [ "$DELETE_LINKS" = "yes" ]; then
    find "$CLAUDE_RULES" -maxdepth 1 -type l -delete
    echo "Existing links removed."
    echo ""
  fi
fi

# --- Shared enterprise configuration ---
echo "Linking shared configuration..."

# Organization context
ln -sfn "$REPO_DIR/config/ORGANIZATION.md" "$CLAUDE_RULES/20-organization.md"
echo "  Linked: ORGANIZATION.md -> rules/20-organization.md"

# Tools guidelines
ln -sfn "$REPO_DIR/config/TOOLS.md" "$CLAUDE_RULES/60-tools.md"
echo "  Linked: TOOLS.md -> rules/60-tools.md"

# SOUL.md (only if generated)
if [ -f "$REPO_DIR/config/SOUL.md" ]; then
  ln -sfn "$REPO_DIR/config/SOUL.md" "$CLAUDE_RULES/00-soul.md"
  echo "  Linked: SOUL.md -> rules/00-soul.md"
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
echo "  Installed: mcp.json"
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
ln -sfn "$REPO_DIR/config/teams/${TEAM}.md" "$CLAUDE_RULES/50-team.md"
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
ln -sfn "$REPO_DIR/config/expertise/${EXPERTISE}.md" "$CLAUDE_RULES/40-expertise.md"
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
ln -sfn "$REPO_DIR/config/level/${LEVEL}.md" "$CLAUDE_RULES/10-level.md"
echo "$LEVEL" > "$CLAUDE_HOME/.selected_level"
echo "Level: $LEVEL"
echo ""

# --- Profile handling ---
CLAUDE_MD_TARGET="$CLAUDE_HOME/CLAUDE.md"
if [ ! -f "$REPO_DIR/config/PROFILE.md" ]; then
  echo "Personal profile not found: config/PROFILE.md"
  echo "Generate one with: claude /init-personal-profile"
  echo ""
elif [ ! -e "$CLAUDE_MD_TARGET" ]; then
  echo "Setting up personal profile as ~/.claude/CLAUDE.md..."
  METHOD=$(echo -e "symlink\ncopy" | fzf --height 10% --header "How to link your profile?")
  if [ "$METHOD" = "symlink" ]; then
    ln -sfn "$REPO_DIR/config/PROFILE.md" "$CLAUDE_MD_TARGET"
    echo "Linked: PROFILE.md -> CLAUDE.md"
  elif [ "$METHOD" = "copy" ]; then
    cp "$REPO_DIR/config/PROFILE.md" "$CLAUDE_MD_TARGET"
    echo "Copied: PROFILE.md -> CLAUDE.md"
  fi
elif [ -L "$CLAUDE_MD_TARGET" ] && [ "$(readlink "$CLAUDE_MD_TARGET")" = "$REPO_DIR/config/PROFILE.md" ]; then
  echo "Profile already linked."
elif [ -f "$CLAUDE_MD_TARGET" ]; then
  if [ -f "$REPO_DIR/config/PROFILE.md" ]; then
    if ! diff -q "$REPO_DIR/config/PROFILE.md" "$CLAUDE_MD_TARGET" >/dev/null 2>&1; then
      echo "Local CLAUDE.md differs from repository profile."
      METHOD=$(echo -e "symlink\ncopy\nkeep-local" | fzf --height 12% --header "How to resolve?")
      if [ "$METHOD" = "symlink" ]; then
        mv "$CLAUDE_MD_TARGET" "${CLAUDE_MD_TARGET}.ori"
        ln -sfn "$REPO_DIR/config/PROFILE.md" "$CLAUDE_MD_TARGET"
        echo "Linked (backup saved as .ori)"
      elif [ "$METHOD" = "copy" ]; then
        mv "$CLAUDE_MD_TARGET" "${CLAUDE_MD_TARGET}.ori"
        cp "$REPO_DIR/config/PROFILE.md" "$CLAUDE_MD_TARGET"
        echo "Copied (backup saved as .ori)"
      elif [ "$METHOD" = "keep-local" ]; then
        echo "Keeping local CLAUDE.md."
      fi
    else
      echo "Profile is up to date."
    fi
  fi
fi

echo ""
echo "===================================="
echo "  Setup complete"
echo "===================================="
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
