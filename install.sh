#!/usr/bin/env bash
set -euo pipefail

# neo-skill installer
# Detects AI coding assistants in your project and installs the appropriate instruction files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: $TARGET is not a directory"
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
INSTALLED=0

echo "Installing neo-skill instructions into: $TARGET"
echo ""

# Claude Code (project-level skill)
CLAUDE_SKILLS_DIR="$TARGET/.claude/skills/neo"
if [ -d "$TARGET/.claude" ] || [ -f "$TARGET/CLAUDE.md" ]; then
  mkdir -p "$CLAUDE_SKILLS_DIR"
  cp "$SCRIPT_DIR/skills/neo/SKILL.md" "$CLAUDE_SKILLS_DIR/SKILL.md"
  echo "  [+] Claude Code    → .claude/skills/neo/SKILL.md"
  INSTALLED=$((INSTALLED + 1))
fi

# GitHub Copilot
if [ -d "$TARGET/.github" ]; then
  cp "$SCRIPT_DIR/copilot-instructions.md" "$TARGET/.github/copilot-instructions.md"
  echo "  [+] GitHub Copilot → .github/copilot-instructions.md"
  INSTALLED=$((INSTALLED + 1))
fi

# Cursor
if [ -d "$TARGET/.cursor" ] || [ -f "$TARGET/.cursorrules" ]; then
  cp "$SCRIPT_DIR/.cursorrules" "$TARGET/.cursorrules"
  echo "  [+] Cursor         → .cursorrules"
  INSTALLED=$((INSTALLED + 1))
fi

# Windsurf
if [ -f "$TARGET/.windsurfrules" ]; then
  cp "$SCRIPT_DIR/.windsurfrules" "$TARGET/.windsurfrules"
  echo "  [+] Windsurf       → .windsurfrules"
  INSTALLED=$((INSTALLED + 1))
fi

# Cline / Roo Code
if [ -f "$TARGET/.clinerules" ]; then
  cp "$SCRIPT_DIR/.clinerules" "$TARGET/.clinerules"
  echo "  [+] Cline          → .clinerules"
  INSTALLED=$((INSTALLED + 1))
fi

# OpenAI Codex
if [ -f "$TARGET/AGENTS.md" ]; then
  cp "$SCRIPT_DIR/AGENTS.md" "$TARGET/AGENTS.md"
  echo "  [+] Codex          → AGENTS.md"
  INSTALLED=$((INSTALLED + 1))
fi

# If nothing was auto-detected, offer to install all
if [ $INSTALLED -eq 0 ]; then
  echo "  No AI tools detected. Installing all formats..."
  echo ""

  # Claude Code
  mkdir -p "$TARGET/.claude/skills/neo"
  cp "$SCRIPT_DIR/skills/neo/SKILL.md" "$TARGET/.claude/skills/neo/SKILL.md"
  echo "  [+] Claude Code    → .claude/skills/neo/SKILL.md"

  # GitHub Copilot
  mkdir -p "$TARGET/.github"
  cp "$SCRIPT_DIR/copilot-instructions.md" "$TARGET/.github/copilot-instructions.md"
  echo "  [+] GitHub Copilot → .github/copilot-instructions.md"

  # Cursor
  cp "$SCRIPT_DIR/.cursorrules" "$TARGET/.cursorrules"
  echo "  [+] Cursor         → .cursorrules"

  # Windsurf
  cp "$SCRIPT_DIR/.windsurfrules" "$TARGET/.windsurfrules"
  echo "  [+] Windsurf       → .windsurfrules"

  # Cline
  cp "$SCRIPT_DIR/.clinerules" "$TARGET/.clinerules"
  echo "  [+] Cline          → .clinerules"

  # Codex
  cp "$SCRIPT_DIR/AGENTS.md" "$TARGET/AGENTS.md"
  echo "  [+] Codex          → AGENTS.md"

  INSTALLED=6
fi

echo ""
echo "Done! Installed $INSTALLED instruction file(s)."
echo "Your AI assistant now knows how to use the neo CLI."
