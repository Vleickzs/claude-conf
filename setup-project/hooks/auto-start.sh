#!/bin/bash
# Hook UserPromptSubmit — rappel /start au premier message (sessions normales)
# Ne se declenche PAS si supervisor ou worker detecte

# Skip if module disabled
grep -q "^setup-project$" "$HOME/.claude-conf-disabled" 2>/dev/null && exit 0

# Read input
INPUT=$(cat)
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

[ -z "$SESSION_ID" ] && exit 0

# Already shown for this session? → skip
MARKER_DIR=".claude-sessions/started"
MARKER="$MARKER_DIR/$SESSION_ID"
[ -f "$MARKER" ] && exit 0

# Create marker (first message of this session)
mkdir -p "$MARKER_DIR"
touch "$MARKER"

# Skip if supervisor or worker session
if printf '%s' "$PROMPT" | grep -qiE '(/supervisor|ABSOLUTE WORKER RULES|STRICT SCOPE)'; then
    exit 0
fi

# Normal session — instruct Claude to mention /start
echo "[SYSTEM] First message of a new session. Before answering, mention briefly: 'Tip: /start to load project context (git, backlog, handoff).' — one short line, then answer normally."

# Rotation: garder les 35 derniers marqueurs
ls -t "$MARKER_DIR"/* 2>/dev/null | tail -n +36 | xargs rm -f 2>/dev/null

exit 0
