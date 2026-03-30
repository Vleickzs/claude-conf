#!/bin/bash
# ── supervisor-guard — Installer ─────────────────────────────────
# Installs the supervisor-guard PreToolUse hook for Claude Code
#
# Usage:
#   bash install.sh

set -e

# ── Colors ───────────────────────────────────────────────────────

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Paths ────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
GUARD_HOOK="$HOOK_DIR/supervisor-guard.sh"
DETECT_HOOK="$HOOK_DIR/supervisor-detect.sh"

# ── Banner ───────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}  ┌─────────────────────────────────────────────┐${NC}"
echo -e "${BOLD}  │         ${BLUE}supervisor-guard${NC}${BOLD}                    │${NC}"
echo -e "${BOLD}  │   ${DIM}Supervisor write guard for Claude Code${NC}${BOLD}     │${NC}"
echo -e "${BOLD}  └─────────────────────────────────────────────┘${NC}"
echo ""

# ── Check dependencies ───────────────────────────────────────────

echo -e "  ${BOLD}Checking dependencies...${NC}"
echo ""

if ! command -v jq &> /dev/null; then
    echo -e "  ${RED}Error: jq is not installed.${NC}"
    echo -e "  ${DIM}Install it with: brew install jq${NC}"
    echo ""
    exit 1
fi

JQ_VERSION=$(jq --version 2>/dev/null)
echo -e "  ${GREEN}OK${NC} jq ${DIM}${JQ_VERSION}${NC}"
echo ""

# ── Install hook script ─────────────────────────────────────────

echo -e "  ${BOLD}Installing supervisor-guard...${NC}"
echo ""

mkdir -p "$HOOK_DIR"

cp "$SCRIPT_DIR/hooks/supervisor-guard.sh" "$GUARD_HOOK"
chmod +x "$GUARD_HOOK"
echo -e "  ${GREEN}OK${NC} Guard hook installed to ${DIM}${GUARD_HOOK}${NC}"

cp "$SCRIPT_DIR/hooks/supervisor-detect.sh" "$DETECT_HOOK"
chmod +x "$DETECT_HOOK"
echo -e "  ${GREEN}OK${NC} Detect hook installed to ${DIM}${DETECT_HOOK}${NC}"

# ── Create marker directory ──────────────────────────────────────

mkdir -p ".claude-sessions/supervisor-active"
echo -e "  ${GREEN}OK${NC} Marker directory ready ${DIM}(.claude-sessions/supervisor-active/)${NC}"

# ── Configure Claude Code hook ───────────────────────────────────

echo ""
echo -e "  ${BOLD}Configuring Claude Code hook...${NC}"
echo ""

mkdir -p "$(dirname "$SETTINGS_FILE")"

# Hook entries — PreToolUse matchers for Write and Edit
HOOK_ENTRY_WRITE=$(cat <<JSONEOF
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "$GUARD_HOOK"
    }
  ]
}
JSONEOF
)

HOOK_ENTRY_EDIT=$(cat <<JSONEOF
{
  "matcher": "Edit",
  "hooks": [
    {
      "type": "command",
      "command": "$GUARD_HOOK"
    }
  ]
}
JSONEOF
)

# Hook entry — UserPromptSubmit for supervisor detection
HOOK_ENTRY_DETECT=$(cat <<JSONEOF
{
  "matcher": "",
  "hooks": [
    {
      "type": "command",
      "command": "$DETECT_HOOK"
    }
  ]
}
JSONEOF
)

if [ -f "$SETTINGS_FILE" ]; then
    CURRENT=$(cat "$SETTINGS_FILE")
else
    CURRENT='{}'
fi

# ── Register PreToolUse hooks (Write + Edit) ────────────────────

HAS_PRE_TOOL_USE=$(echo "$CURRENT" | jq 'has("hooks") and (.hooks | has("PreToolUse"))' 2>/dev/null)

if [ "$HAS_PRE_TOOL_USE" = "true" ]; then
    GUARD_INSTALLED=$(echo "$CURRENT" | jq --arg cmd "$GUARD_HOOK" '
        [.hooks.PreToolUse[]? | select(.hooks[]?.command == $cmd)] | length > 0
    ' 2>/dev/null)

    if [ "$GUARD_INSTALLED" = "true" ]; then
        echo -e "  ${YELLOW}SKIP${NC} PreToolUse hooks already configured"
    else
        CURRENT=$(echo "$CURRENT" | jq \
            --argjson write "$HOOK_ENTRY_WRITE" \
            --argjson edit "$HOOK_ENTRY_EDIT" '
            .hooks.PreToolUse += [$write, $edit]
        ')
        echo -e "  ${GREEN}OK${NC} PreToolUse hooks added (Write + Edit matchers)"
    fi
else
    CURRENT=$(echo "$CURRENT" | jq \
        --argjson write "$HOOK_ENTRY_WRITE" \
        --argjson edit "$HOOK_ENTRY_EDIT" '
        .hooks = (.hooks // {}) |
        .hooks.PreToolUse = [$write, $edit]
    ')
    echo -e "  ${GREEN}OK${NC} PreToolUse hook section created"
fi

# ── Register UserPromptSubmit hook (supervisor-detect) ──────────

HAS_UPS=$(echo "$CURRENT" | jq 'has("hooks") and (.hooks | has("UserPromptSubmit"))' 2>/dev/null)

if [ "$HAS_UPS" = "true" ]; then
    DETECT_INSTALLED=$(echo "$CURRENT" | jq --arg cmd "$DETECT_HOOK" '
        [.hooks.UserPromptSubmit[]? | select(.hooks[]?.command == $cmd)] | length > 0
    ' 2>/dev/null)

    if [ "$DETECT_INSTALLED" = "true" ]; then
        echo -e "  ${YELLOW}SKIP${NC} UserPromptSubmit hook already configured"
    else
        CURRENT=$(echo "$CURRENT" | jq \
            --argjson detect "$HOOK_ENTRY_DETECT" '
            .hooks.UserPromptSubmit += [$detect]
        ')
        echo -e "  ${GREEN}OK${NC} UserPromptSubmit hook added (supervisor-detect)"
    fi
else
    CURRENT=$(echo "$CURRENT" | jq \
        --argjson detect "$HOOK_ENTRY_DETECT" '
        .hooks = (.hooks // {}) |
        .hooks.UserPromptSubmit = [$detect]
    ')
    echo -e "  ${GREEN}OK${NC} UserPromptSubmit hook section created"
fi

# Write final settings
echo "$CURRENT" > "$SETTINGS_FILE"

# ── Summary ──────────────────────────────────────────────────────

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Installation complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Guard hook:${NC}    ${DIM}${GUARD_HOOK}${NC}"
echo -e "  ${BOLD}Detect hook:${NC}   ${DIM}${DETECT_HOOK}${NC}"
echo -e "  ${BOLD}Settings:${NC}      ${DIM}${SETTINGS_FILE}${NC}"
echo -e "  ${BOLD}Marker dir:${NC}    ${DIM}.claude-sessions/supervisor-active/${NC}"
echo ""
echo -e "  ${BOLD}What happens now:${NC}"
echo -e "  ${DIM}When /supervisor is detected, the detect hook creates the marker.${NC}"
echo -e "  ${DIM}The guard hook blocks Write/Edit on files outside the whitelist.${NC}"
echo -e "  ${DIM}Without a marker (or CC_SUPERVISOR_SESSION=1), the guard is transparent.${NC}"
echo ""
echo -e "  ${BOLD}Whitelist:${NC}"
echo -e "  ${DIM}  BACKLOG/**${NC}"
echo -e "  ${DIM}  .claude-sessions/**${NC}"
echo -e "  ${DIM}  **/INDEX.md${NC}"
echo ""
echo -e "  ${BOLD}Disable:${NC}"
echo -e "  ${DIM}echo 'supervisor-guard' >> ~/.claude-conf-disabled${NC}"
echo ""
echo -e "  ${YELLOW}Restart Claude Code for changes to take effect.${NC}"
echo ""
