#!/bin/bash
# ── audit — Install Script ─────────────────────────────────────
# Installs the /audit command for Claude Code
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
echo -e "${BOLD}  │          ${GREEN}audit${NC}${BOLD} for Claude Code           │${NC}"
echo -e "${BOLD}  │   ${DIM}Deep code audit — security, tests,${NC}${BOLD}     │${NC}"
echo -e "${BOLD}  │   ${DIM}architecture, performance${NC}${BOLD}              │${NC}"
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

src="$SCRIPT_DIR/commands/audit.md"
dst="$COMMANDS_DIR/audit.md"

if [ ! -f "$src" ]; then
    echo -e "${RED}  ✗ Source not found: commands/audit.md${NC}"
    exit 1
fi

if [ -f "$dst" ]; then
    cp "$dst" "${dst}.bak"
    echo -e "${YELLOW}  ↑${NC} Backed up existing audit.md"
fi

cp "$src" "$dst"
echo -e "${GREEN}  ✓${NC} /audit command installed"

# ── Done ──────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  ── Installation complete ──${NC}"
echo ""
echo -e "  ${BOLD}Command installed:${NC}"
echo -e "    /audit              — full code audit (all relevant axes)"
echo -e "    /audit security     — focused security audit"
echo -e "    /audit tests        — focused test coverage audit"
echo -e "    /audit architecture — focused architecture audit"
echo -e "    /audit performance  — focused performance audit"
echo ""
echo -e "  ${BOLD}Works best with:${NC}"
echo -e "    ${DIM}backlog${NC}        — auto-creates BUG/IMP tickets from findings"
echo -e "    ${DIM}setup-project${NC}  — /audit-conf for config audit"
echo ""
echo -e "  ${DIM}Restart Claude Code for the changes to take effect.${NC}"
echo ""
