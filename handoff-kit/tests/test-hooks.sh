#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
CONTEXT_MONITOR="$MODULE_DIR/hooks/context-monitor.sh"
PRE_COMPACT="$MODULE_DIR/hooks/pre-compact-handoff.sh"
PASS=0
FAIL=0

# --- Helpers ---
setup() {
  TMPDIR=$(mktemp -d)
  ORIG_HOME="$HOME"
}

teardown() {
  HOME="$ORIG_HOME"
  rm -rf "$TMPDIR"
}

assert_exit() {
  local expected=$1 actual=$2 test_name=$3
  if [ "$actual" -eq "$expected" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_contains() {
  local expected=$1 output=$2 test_name=$3
  if echo "$output" | grep -q "$expected"; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (output missing: $expected)"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_empty() {
  local output=$1 test_name=$2
  if [ -z "$output" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (expected empty output, got: $output)"
    FAIL=$((FAIL + 1))
  fi
}

assert_pass() {
  local test_name=$1
  echo "  PASS: $test_name"
  PASS=$((PASS + 1))
}

assert_fail() {
  local test_name=$1 detail=${2:-""}
  if [ -n "$detail" ]; then
    echo "  FAIL: $test_name ($detail)"
  else
    echo "  FAIL: $test_name"
  fi
  FAIL=$((FAIL + 1))
}

# --- Tests: context-monitor.sh ---

test_context_monitor_syntax() {
  set +e
  bash -n "$CONTEXT_MONITOR" 2>/dev/null
  rc=$?
  set -e
  assert_exit 0 $rc "context-monitor.sh syntax valid"
}

test_pre_compact_syntax() {
  set +e
  bash -n "$PRE_COMPACT" 2>/dev/null
  rc=$?
  set -e
  assert_exit 0 $rc "pre-compact-handoff.sh syntax valid"
}

test_context_monitor_low_usage() {
  setup
  HOME="$TMPDIR"
  local session_id="test-session-low"
  mkdir -p "$TMPDIR/.claude/context-data"
  echo "30" > "$TMPDIR/.claude/context-data/${session_id}.txt"

  local input='{"session_id": "'"$session_id"'"}'
  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash "$CONTEXT_MONITOR" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "context-monitor exits 0 at 30%"
  assert_output_empty "$output" "no warning at 30% usage"
  teardown
}

test_context_monitor_high_usage() {
  setup
  HOME="$TMPDIR"
  local session_id="test-session-high"
  mkdir -p "$TMPDIR/.claude/context-data"
  echo "70" > "$TMPDIR/.claude/context-data/${session_id}.txt"

  local input='{"session_id": "'"$session_id"'"}'
  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash "$CONTEXT_MONITOR" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "context-monitor exits 0 at 70%"
  assert_output_contains "SYSTEM-HANDOFF-WARNING" "$output" "warning present at 70% usage"
  teardown
}

test_context_monitor_no_file() {
  setup
  HOME="$TMPDIR"
  local session_id="test-session-nofile"
  # Don't create the context-data file

  local input='{"session_id": "'"$session_id"'"}'
  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash "$CONTEXT_MONITOR" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "context-monitor exits 0 without context file"
  assert_output_empty "$output" "no warning without context file"
  teardown
}

test_context_monitor_threshold_exact() {
  setup
  HOME="$TMPDIR"
  local session_id="test-session-exact"
  mkdir -p "$TMPDIR/.claude/context-data"
  echo "65" > "$TMPDIR/.claude/context-data/${session_id}.txt"

  local input='{"session_id": "'"$session_id"'"}'
  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash "$CONTEXT_MONITOR" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "context-monitor exits 0 at exactly 65%"
  assert_output_contains "SYSTEM-HANDOFF-WARNING" "$output" "warning at exactly 65% (threshold)"
  teardown
}

# --- Tests: pre-compact-handoff.sh ---

test_pre_compact_rotation() {
  setup
  HOME="$TMPDIR"
  local backup_dir="$TMPDIR/.claude/handoff-system/sessions"
  mkdir -p "$backup_dir"

  # Create 40 fake backup files (both .json and .md)
  for i in $(seq 1 40); do
    local ts=$(printf "20260101-%06d" "$i")
    touch "$backup_dir/AUTOBACKUP-testproj-${ts}.json"
    touch "$backup_dir/AUTOBACKUP-testproj-${ts}.md"
  done

  # Verify we have 40 json + 40 md
  local json_before
  json_before=$(ls "$backup_dir"/AUTOBACKUP-*.json 2>/dev/null | wc -l | tr -d ' ')

  if [ "$json_before" -ne 40 ]; then
    assert_fail "pre-compact rotation setup" "expected 40 json files, got $json_before"
    teardown
    return
  fi

  # Run the rotation logic directly (extracted from pre-compact-handoff.sh)
  ls -t "$backup_dir"/AUTOBACKUP-*.json 2>/dev/null | tail -n +36 | xargs rm -f 2>/dev/null
  ls -t "$backup_dir"/AUTOBACKUP-*.md 2>/dev/null | tail -n +36 | xargs rm -f 2>/dev/null

  local json_after md_after
  json_after=$(ls "$backup_dir"/AUTOBACKUP-*.json 2>/dev/null | wc -l | tr -d ' ')
  md_after=$(ls "$backup_dir"/AUTOBACKUP-*.md 2>/dev/null | wc -l | tr -d ' ')

  if [ "$json_after" -eq 35 ] && [ "$md_after" -eq 35 ]; then
    assert_pass "rotation keeps 35 most recent backups (json=$json_after, md=$md_after)"
  else
    assert_fail "rotation keeps 35 most recent" "json=$json_after, md=$md_after (expected 35 each)"
  fi
  teardown
}

test_pre_compact_creates_backup() {
  setup
  HOME="$TMPDIR"
  local cwd="$TMPDIR/fake-project"
  mkdir -p "$cwd"
  mkdir -p "$TMPDIR/.claude/handoff-system/sessions"

  # Create a fake transcript
  local transcript="$TMPDIR/transcript.json"
  echo '{"messages": []}' > "$transcript"

  local input
  input=$(cat <<ENDJSON
{"session_id": "test-backup-123", "transcript_path": "$transcript", "trigger": "auto", "cwd": "$cwd"}
ENDJSON
)

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash "$PRE_COMPACT" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "pre-compact exits 0"

  # Check global backup was created
  local global_count
  global_count=$(ls "$TMPDIR/.claude/handoff-system/sessions"/AUTOBACKUP-*.json 2>/dev/null | wc -l | tr -d ' ')
  if [ "$global_count" -ge 1 ]; then
    assert_pass "pre-compact creates global JSON backup"
  else
    assert_fail "pre-compact creates global JSON backup" "no backup found"
  fi

  # Check local backup was created
  local local_count
  local_count=$(ls "$cwd/.claude-sessions"/AUTOBACKUP-*.json 2>/dev/null | wc -l | tr -d ' ')
  if [ "$local_count" -ge 1 ]; then
    assert_pass "pre-compact creates local JSON backup"
  else
    assert_fail "pre-compact creates local JSON backup" "no local backup found"
  fi

  # Check .md summary was created
  local md_count
  md_count=$(ls "$TMPDIR/.claude/handoff-system/sessions"/AUTOBACKUP-*.md 2>/dev/null | wc -l | tr -d ' ')
  if [ "$md_count" -ge 1 ]; then
    assert_pass "pre-compact creates .md summary"
  else
    assert_fail "pre-compact creates .md summary" "no .md file found"
  fi

  teardown
}

# --- Runner ---
echo "=== [handoff-kit] Tests ==="
test_context_monitor_syntax
test_pre_compact_syntax
test_context_monitor_low_usage
test_context_monitor_high_usage
test_context_monitor_no_file
test_context_monitor_threshold_exact
test_pre_compact_rotation
test_pre_compact_creates_backup
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
