#!/bin/bash
set -e

GEMINI_HOME="${HOME}/.gemini"
TYPE="$1"
NAME="$2"

if [ -z "$TYPE" ] || [ -z "$NAME" ]; then
  echo "Usage: $0 <type> <name>"
  echo "Types: commands, skills, hooks, agents, policies, mcp-servers, themes"
  exit 1
fi

# Normalize singular/plural
case "$TYPE" in
  command)    TYPE="commands" ;;
  skill)      TYPE="skills" ;;
  hook)       TYPE="hooks" ;;
  agent)      TYPE="agents" ;;
  policy)     TYPE="policies" ;;
  mcp-server) TYPE="mcp-servers" ;;
  theme)      TYPE="themes" ;;
esac

TARGET="$GEMINI_HOME/$TYPE/$NAME"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  rm -rf "$TARGET"
  echo "Removed: $TYPE/$NAME"
else
  echo "Not found: $TYPE/$NAME"
fi
