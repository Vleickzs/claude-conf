#!/bin/bash
# ── scope-enforcer — PreToolUse hook ─────────────────────────────
# Blocks Write/Edit operations on files outside the worker's scope.
# The scope is defined by the supervisor in a JSON file:
#   .claude-sessions/worker-scope/{session_id}.json
#
# Exit codes:
#   0 — allowed (pass-through)
#   2 — blocked (file outside scope)

# Skip if module is disabled
grep -q "^scope-enforcer$" "$HOME/.claude-conf-disabled" 2>/dev/null && exit 0

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

# Locate scope file — no file = pass-through (normal mode, no supervisor)
SCOPE_FILE=".claude-sessions/worker-scope/${SESSION_ID}.json"
[ -f "$SCOPE_FILE" ] || exit 0

# Extract target file path from tool_input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$FILE_PATH" ] && exit 0

# Normalize: strip leading ./ if present
FILE_PATH="${FILE_PATH#./}"

# Check if file_path is in allowed_files
ALLOWED=$(jq -r '.allowed_files[]' "$SCOPE_FILE" 2>/dev/null)

while IFS= read -r allowed_file; do
    # Normalize allowed file too
    allowed_file="${allowed_file#./}"
    [ "$FILE_PATH" = "$allowed_file" ] && exit 0
done <<< "$ALLOWED"

# File not in allowed list — block
ALLOWED_LIST=$(jq -r '.allowed_files | join(", ")' "$SCOPE_FILE" 2>/dev/null)
TICKET=$(jq -r '.worker_ticket // "unknown"' "$SCOPE_FILE" 2>/dev/null)

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"block","permissionDecisionReason":"File outside worker scope for ${TICKET}. Attempted: ${FILE_PATH}. Allowed: [${ALLOWED_LIST}]. Note this in your report."}}
EOF

exit 2
