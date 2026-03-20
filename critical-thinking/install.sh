#!/bin/bash
# ── Claude Code Critical Thinking — Install Script ──────────────
# Injects anti-complacency rules into CLAUDE.md and patches supervisor
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
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
SUPERVISOR_LOCAL="$CLAUDE_DIR/commands/supervisor.md"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SNIPPET_FILE="$SCRIPT_DIR/claude-md/critical-thinking.md"

sed_inplace() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

echo ""
echo -e "${BOLD}  ┌─────────────────────────────────────────┐${NC}"
echo -e "${BOLD}  │     ${RED}critical-thinking${NC}${BOLD} for Claude Code    │${NC}"
echo -e "${BOLD}  │   ${DIM}Anti-complacency — sparring partner mode${NC}${BOLD} │${NC}"
echo -e "${BOLD}  └─────────────────────────────────────────┘${NC}"
echo ""

# ── 1/3. Check dependencies ────────────────────────────────────

echo -e "${BLUE}[1/3]${NC} Checking dependencies..."

if ! command -v claude &>/dev/null; then
    echo -e "${RED}  ✗ Claude Code not found.${NC}"
    echo -e "    Install it first: ${DIM}npm install -g @anthropic-ai/claude-code${NC}"
    exit 1
fi

echo -e "${GREEN}  ✓${NC} Claude Code available"

if [ ! -f "$SNIPPET_FILE" ]; then
    echo -e "${RED}  ✗ Source file not found: claude-md/critical-thinking.md${NC}"
    exit 1
fi

# ── 2/3. Inject into CLAUDE.md ──────────────────────────────────

echo -e "${BLUE}[2/3]${NC} Injecting into CLAUDE.md..."

mkdir -p "$CLAUDE_DIR"

if [ ! -f "$CLAUDE_MD" ]; then
    cp "$SNIPPET_FILE" "$CLAUDE_MD"
    echo -e "${GREEN}  ✓${NC} Created $CLAUDE_MD with critical-thinking rules"
elif grep -q '<!-- critical-thinking:start -->' "$CLAUDE_MD"; then
    # Update: remove old content between markers, reinject fresh
    sed_inplace '/<!-- critical-thinking:start -->/,/<!-- critical-thinking:end -->/d' "$CLAUDE_MD"
    # Remove trailing empty lines left by deletion
    while [[ -s "$CLAUDE_MD" ]] && [[ "$(tail -c 1 "$CLAUDE_MD")" == "" ]] && [[ "$(tail -n 1 "$CLAUDE_MD")" == "" ]]; do
        sed_inplace '$ d' "$CLAUDE_MD"
    done
    echo "" >> "$CLAUDE_MD"
    cat "$SNIPPET_FILE" >> "$CLAUDE_MD"
    echo -e "${BLUE}  ↑ UPDATED${NC} critical-thinking rules in CLAUDE.md"
else
    echo "" >> "$CLAUDE_MD"
    cat "$SNIPPET_FILE" >> "$CLAUDE_MD"
    echo -e "${GREEN}  ✓${NC} Appended critical-thinking rules to CLAUDE.md"
fi

# ── 3/3. Patch supervisor (local copy) ─────────────────────────

echo -e "${BLUE}[3/3]${NC} Patching supervisor..."

if [ -f "$SUPERVISOR_LOCAL" ]; then
    REPO_SUPERVISOR="$SCRIPT_DIR/../supervisor/commands/supervisor.md"
    if [ ! -f "$REPO_SUPERVISOR" ]; then
        echo -e "${YELLOW}  ! WARNING${NC} — Repo supervisor source not found, skipping patch"
    else
        local_action="Injected"
        if grep -q '<!-- critical-thinking:start -->' "$SUPERVISOR_LOCAL"; then
            # Update: remove old content between markers
            sed_inplace '/<!-- critical-thinking:start -->/,/<!-- critical-thinking:end -->/d' "$SUPERVISOR_LOCAL"
            # Remove trailing empty lines
            while [[ -s "$SUPERVISOR_LOCAL" ]] && [[ "$(tail -c 1 "$SUPERVISOR_LOCAL")" == "" ]] && [[ "$(tail -n 1 "$SUPERVISOR_LOCAL")" == "" ]]; do
                sed_inplace '$ d' "$SUPERVISOR_LOCAL"
            done
            local_action="Updated"
        fi
        # Extract POSTURE block from repo source
        POSTURE_FILE=$(mktemp)
        sed -n '/<!-- critical-thinking:start -->/,/<!-- critical-thinking:end -->/p' "$REPO_SUPERVISOR" > "$POSTURE_FILE"
        # Insert posture block + separator before ## YOUR ROLE / ## TON ROLE
        TEMP_FILE=$(mktemp)
        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$line" = "## YOUR ROLE" ] || [ "$line" = "## TON ROLE" ]; then
                cat "$POSTURE_FILE"
                echo ""
                echo "---"
                echo ""
            fi
            printf '%s\n' "$line"
        done < "$SUPERVISOR_LOCAL" > "$TEMP_FILE"
        mv "$TEMP_FILE" "$SUPERVISOR_LOCAL"
        rm -f "$POSTURE_FILE"
        if [ "$local_action" = "Updated" ]; then
            echo -e "${BLUE}  ↑ UPDATED${NC} POSTURE block in local supervisor"
        else
            echo -e "${GREEN}  ✓${NC} Injected POSTURE block into local supervisor"
        fi
    fi
else
    echo -e "${DIM}  ─ Supervisor not installed — skipping${NC}"
fi

# ── Done ────────────────────────────────────────────────────────

echo ""
echo -e "${GREEN}  ── Installation complete ──${NC}"
echo ""
echo -e "  ${BOLD}What was installed:${NC}"
echo -e "    • Anti-complacency rules injected into ~/.claude/CLAUDE.md"
echo -e "    • Classification system (Solide/Discutable/Simplifie/Angle mort/Faux)"
echo -e "    • 5 anti-complacency reflexes"
echo -e "    • Stress-test questions by domain"
echo -e "    • CTO posture patch for supervisor (if installed)"
echo ""
echo -e "  ${BOLD}Works best with:${NC}"
echo -e "    ${DIM}supervisor${NC}  — CTO mode with POSTURE block"
echo ""
echo -e "  ${DIM}Restart Claude Code for the changes to take effect.${NC}"
echo ""
