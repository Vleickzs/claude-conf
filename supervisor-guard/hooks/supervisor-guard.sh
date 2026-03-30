#!/bin/bash
# ── supervisor-guard — PreToolUse hook ────────────────────────────
# Blocks Write/Edit operations on files outside the supervisor whitelist
# when supervisor mode is active (marker file exists).
#
# The supervisor creates a marker at startup:
#   .claude-sessions/supervisor-active/{session_id}
#
# Whitelisted paths (supervisor can write to):
#   - BACKLOG/**
#   - .claude-sessions/**
#   - **/INDEX.md
#
# Exit codes:
#   0 — allowed (pass-through)
#   2 — blocked (file outside supervisor whitelist)

# Skip if module is disabled
grep -q "^supervisor-guard$" "$HOME/.claude-conf-disabled" 2>/dev/null && exit 0

# Read stdin (hook JSON input)
INPUT=$(cat)

# Extract tool_name — only enforce on Write and Edit
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

case "$TOOL_NAME" in
    Write|Edit) ;;
    *) exit 0 ;;
esac

# Extract session_id — no session = pass-through
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

# Check supervisor marker — primary mechanism (set by supervisor-detect.sh hook)
MARKER=".claude-sessions/supervisor-active/${SESSION_ID}"
# Fallback: env var from launch script
if [ ! -f "$MARKER" ]; then
    [ "${CC_SUPERVISOR_SESSION:-}" = "1" ] || exit 0
fi

# Extract target file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Normalize: strip leading ./ if present
FILE_PATH="${FILE_PATH#./}"

# Check whitelist — supervisor can write to these paths
case "$FILE_PATH" in
    BACKLOG/*|*/BACKLOG/*) exit 0 ;;
    .claude-sessions/*) exit 0 ;;
    */INDEX.md|INDEX.md) exit 0 ;;
    *) ;; # blocked
esac

# File not in whitelist — block
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"block","permissionDecisionReason":"Supervisor mode active — you cannot write source code. Generate a worker prompt instead. Attempted: ${FILE_PATH}"}}
EOF

exit 2
