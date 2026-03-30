#!/bin/bash
# ── supervisor-detect — UserPromptSubmit hook ───────────────────
# Auto-detects supervisor mode from user prompt and creates the
# marker file mechanically, removing dependency on LLM behavior.
#
# Fires on every user message. Marker creation is idempotent.
#
# Exit codes:
#   0 — always (UserPromptSubmit hooks should not block)

set -e

# Skip if module is disabled
grep -q "^supervisor-guard$" "$HOME/.claude-conf-disabled" 2>/dev/null && exit 0

# Read stdin (hook JSON input)
INPUT=$(cat)

# Extract prompt and session_id
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

# No session = nothing to do
[ -z "$SESSION_ID" ] && exit 0

# Detect supervisor mode
SUPERVISOR_DETECTED=false

# Check 1: first line matches /supervisor (same pattern as tab-title.sh)
if echo "$PROMPT" | head -1 | grep -qiE '^[[:space:]]*/supervisor'; then
    SUPERVISOR_DETECTED=true
fi

# Check 2: expanded command tag (Claude Code expands slash commands before hook fires)
if [ "$SUPERVISOR_DETECTED" = "false" ]; then
    if echo "$PROMPT" | grep -qE '<command-name>/?supervisor</command-name>'; then
        SUPERVISOR_DETECTED=true
    fi
fi

# Create marker if supervisor detected
if [ "$SUPERVISOR_DETECTED" = "true" ]; then
    mkdir -p .claude-sessions/supervisor-active
    touch ".claude-sessions/supervisor-active/${SESSION_ID}"
fi

exit 0
