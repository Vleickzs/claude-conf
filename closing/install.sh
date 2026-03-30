#!/bin/bash
# ── Claude Code Closing — Install Script ─────────────────────────
# Installs the /closing slash command for Claude Code
#
# Usage: bash install.sh

set -e

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
COMMANDS_DIR="$CLAUDE_DIR/commands"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo -e "${BOLD}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${BOLD}  │       ${BLUE}closing${NC}${BOLD} for Claude Code           │${NC}"
echo -e "${BOLD}  │   ${DIM}Freelance closing — scope, quote, ship${NC}${BOLD}  │${NC}"
echo -e "${BOLD}  └─────────────────────────────────────────┘${NC}"
echo ""

# ── 1. Check dependencies ────────────────────────────────────────

echo -e "${BLUE}[1/2]${NC} Checking dependencies..."

if ! command -v claude &>/dev/null; then
    echo -e "${RED}  ✗ Claude Code not found.${NC}"
    echo -e "    Install it first: ${DIM}npm install -g @anthropic-ai/claude-code${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓${NC} Claude Code available"

# ── 2. Install the command ────────────────────────────────────────

echo -e "${BLUE}[2/2]${NC} Installing /closing command..."

mkdir -p "$COMMANDS_DIR"

if [ ! -f "$SCRIPT_DIR/commands/closing.md" ]; then
    echo -e "${RED}  ✗ Source file not found: commands/closing.md${NC}"
    exit 1
fi

# Backup existing command if present
if [ -f "$COMMANDS_DIR/closing.md" ]; then
    cp "$COMMANDS_DIR/closing.md" "$COMMANDS_DIR/closing.md.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}  !${NC} Existing command backed up"
fi

cp "$SCRIPT_DIR/commands/closing.md" "$COMMANDS_DIR/closing.md"

echo -e "${GREEN}  ✓${NC} Command installed in $COMMANDS_DIR/closing.md"

# ── Done ──────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  ── Installation complete ──${NC}"
echo ""
echo -e "  ${BOLD}Usage:${NC}"
echo -e "    In any Claude Code session, type: ${BOLD}/closing${NC}"
echo ""
echo -e "  ${BOLD}What it does:${NC}"
echo -e "    Switches Claude into freelance closing mode. It will analyze missions,"
echo -e "    identify blind spots, estimate time, draft proposals, and protect"
echo -e "    your scope — but ${BOLD}never write code${NC}."
echo ""
echo -e "  ${BOLD}Works best with:${NC}"
echo -e "    ${DIM}tab-titles${NC}  — distinct tab titles (⚪ BIZ) for closing sessions"
echo ""
echo -e "  ${DIM}Restart Claude Code for the command to become available.${NC}"
echo ""
