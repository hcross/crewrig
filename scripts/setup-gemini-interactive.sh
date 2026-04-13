#!/bin/bash
set -e

GEMINI_HOME="${HOME}/.gemini"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "===================================="
echo "  Gemini CLI Configuration Setup"
echo "===================================="
echo ""
mkdir -p "$GEMINI_HOME"

# --- Prerequisites ---
command -v fzf >/dev/null 2>&1 || {
  echo "Error: fzf is required but not installed."
  echo "Install with: brew install fzf (macOS) or apt-get install fzf (Linux)"
  exit 1
}

# --- Clean existing symlinks if requested ---
LINKS=$(find "$GEMINI_HOME" -maxdepth 1 -type l 2>/dev/null)
if [ -n "$LINKS" ]; then
  echo "Existing symbolic links found in $GEMINI_HOME:"
  echo "$LINKS" | sed "s|^$GEMINI_HOME/|   - |"
  echo ""
  DELETE_LINKS=$(echo -e "no\nyes" | fzf --height 10% --header "Remove existing links before starting?")
  if [ "$DELETE_LINKS" = "yes" ]; then
    find "$GEMINI_HOME" -maxdepth 1 -type l -delete
    echo "Existing links removed."
    echo ""
  fi
fi

# --- Shared enterprise configuration ---
echo "Linking shared configuration..."

# settings.json (backup if a real file exists)
if [ -f "$GEMINI_HOME/settings.json" ] && [ ! -L "$GEMINI_HOME/settings.json" ]; then
  mv "$GEMINI_HOME/settings.json" "$GEMINI_HOME/settings.json.ori"
  echo "  Backed up existing settings.json to settings.json.ori"
fi
ln -sfn "$REPO_DIR/config/gemini/settings.json" "$GEMINI_HOME/settings.json"
echo "  Linked: settings.json"

# Organization context
ln -sfn "$REPO_DIR/config/ORGANIZATION.md" "$GEMINI_HOME/20_ORGANIZATION.md"
echo "  Linked: ORGANIZATION.md -> 20_ORGANIZATION.md"

# Tools guidelines
ln -sfn "$REPO_DIR/config/TOOLS.md" "$GEMINI_HOME/60_TOOLS.md"
echo "  Linked: TOOLS.md -> 60_TOOLS.md"

# SOUL.md (only if generated)
if [ -f "$REPO_DIR/config/SOUL.md" ]; then
  ln -sfn "$REPO_DIR/config/SOUL.md" "$GEMINI_HOME/00_SOUL.md"
  echo "  Linked: SOUL.md -> 00_SOUL.md"
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
ln -sfn "$REPO_DIR/config/teams/${TEAM}.md" "$GEMINI_HOME/50_USER_TEAM.md"
echo "$TEAM" > "$GEMINI_HOME/.selected_team"
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
ln -sfn "$REPO_DIR/config/expertise/${EXPERTISE}.md" "$GEMINI_HOME/40_USER_EXPERTISE.md"
echo "$EXPERTISE" > "$GEMINI_HOME/.selected_expertise"
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
ln -sfn "$REPO_DIR/config/level/${LEVEL}.md" "$GEMINI_HOME/10_USER_LEVEL.md"
echo "$LEVEL" > "$GEMINI_HOME/.selected_level"
echo "Level: $LEVEL"
echo ""

# --- Profile handling ---
TARGET="$GEMINI_HOME/30_USER_PROFILE.md"
if [ ! -f "$REPO_DIR/config/PROFILE.md" ]; then
  echo "Personal profile not found: config/PROFILE.md"
  echo "Generate one with: gemini /init-personal-profile"
  echo ""
elif [ ! -e "$TARGET" ]; then
  echo "Setting up personal profile..."
  METHOD=$(echo -e "symlink\ncopy" | fzf --height 10% --header "How to link your profile?")
  if [ "$METHOD" = "symlink" ]; then
    ln -sfn "$REPO_DIR/config/PROFILE.md" "$TARGET"
    echo "Linked: PROFILE.md -> 30_USER_PROFILE.md"
  elif [ "$METHOD" = "copy" ]; then
    cp "$REPO_DIR/config/PROFILE.md" "$TARGET"
    echo "Copied: PROFILE.md -> 30_USER_PROFILE.md"
  fi
elif [ -L "$TARGET" ] && [ "$(readlink "$TARGET")" = "$REPO_DIR/config/PROFILE.md" ]; then
  echo "Profile already linked."
elif [ -f "$TARGET" ]; then
  if ! diff -q "$REPO_DIR/config/PROFILE.md" "$TARGET" >/dev/null 2>&1; then
    echo "Local profile differs from repository version."
    METHOD=$(echo -e "symlink\ncopy\nkeep-local" | fzf --height 12% --header "How to resolve?")
    if [ "$METHOD" = "symlink" ]; then
      mv "$TARGET" "${TARGET}.ori"
      ln -sfn "$REPO_DIR/config/PROFILE.md" "$TARGET"
      echo "Linked (backup saved as .ori)"
    elif [ "$METHOD" = "copy" ]; then
      mv "$TARGET" "${TARGET}.ori"
      cp "$REPO_DIR/config/PROFILE.md" "$TARGET"
      echo "Copied (backup saved as .ori)"
    elif [ "$METHOD" = "keep-local" ]; then
      echo "Keeping local profile."
    fi
  else
    echo "Profile is up to date."
  fi
fi

echo ""
echo "===================================="
echo "  Setup complete"
echo "===================================="
echo ""
echo "Active context files:"
ls -1 "$GEMINI_HOME"/??_*.md 2>/dev/null || echo "  (none)"
