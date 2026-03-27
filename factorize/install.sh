#!/bin/bash
# ── factorize — Install Script ────────────────────────────────────
# Installs the /factorize command for Claude Code
#
# Usage: bash install.sh

set -e

# ── Colors ────────────────────────────────────────────────────────

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Paths ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"

# ── Banner ────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${BOLD}  │        ${GREEN}factorize${NC}${BOLD} for Claude Code        │${NC}"
echo -e "${BOLD}  │   ${DIM}Scan for duplication & refactoring${NC}${BOLD}     │${NC}"
echo -e "${BOLD}  │   ${DIM}opportunities across the codebase${NC}${BOLD}      │${NC}"
echo -e "${BOLD}  └─────────────────────────────────────────┘${NC}"
echo ""

# ── 1/2. Check dependencies ──────────────────────────────────────

echo -e "${BLUE}[1/2]${NC} Checking dependencies..."

if ! command -v claude &>/dev/null; then
    echo -e "${RED}  ✗ Claude Code not found.${NC}"
    echo -e "    Install it first: ${DIM}npm install -g @anthropic-ai/claude-code${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓${NC} Claude Code available"

# ── 2/2. Install command ─────────────────────────────────────────

echo -e "${BLUE}[2/2]${NC} Installing command..."

mkdir -p "$COMMANDS_DIR"

src="$SCRIPT_DIR/commands/factorize.md"
dst="$COMMANDS_DIR/factorize.md"

if [ ! -f "$src" ]; then
    echo -e "${RED}  ✗ Source not found: commands/factorize.md${NC}"
    exit 1
fi

if [ -f "$dst" ]; then
    cp "$dst" "${dst}.bak"
    echo -e "${YELLOW}  ↑${NC} Backed up existing factorize.md"
fi

cp "$src" "$dst"
echo -e "${GREEN}  ✓${NC} /factorize command installed"

# ── Done ──────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  ── Installation complete ──${NC}"
echo ""
echo -e "  ${BOLD}Command installed:${NC}"
echo -e "    /factorize              — full codebase scan for duplication & patterns"
echo -e "    /factorize src/         — scoped to a directory"
echo -e "    /factorize --dry-run    — report only, no code changes"
echo ""
echo -e "  ${BOLD}Works best with:${NC}"
echo -e "    ${DIM}audit${NC}          — /audit detects duplication, /factorize treats it"
echo -e "    ${DIM}backlog${NC}        — auto-creates IMP tickets for large refactorings"
echo ""
echo -e "  ${DIM}Restart Claude Code for the changes to take effect.${NC}"
echo ""
