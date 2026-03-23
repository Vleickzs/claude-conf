#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
HOOK="$MODULE_DIR/hooks/scope-check.sh"
INSTALL="$MODULE_DIR/install.sh"
PASS=0
FAIL=0

# --- Helpers ---
setup() {
  TMPDIR=$(mktemp -d)
  ORIG_HOME="$HOME"
  # Ensure module is NOT disabled
  HOME="$TMPDIR"
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

# --- Tests ---

test_hook_syntax() {
  set +e
  bash -n "$HOOK" 2>/dev/null
  rc=$?
  set -e
  assert_exit 0 $rc "scope-check.sh syntax valid"
}

test_install_syntax() {
  set +e
  bash -n "$INSTALL" 2>/dev/null
  rc=$?
  set -e
  assert_exit 0 $rc "install.sh syntax valid"
}

test_block_out_of_scope() {
  setup
  local session_id="test-worker-1"
  local scope_dir="$TMPDIR/.claude-sessions/worker-scope"
  mkdir -p "$scope_dir"

  # Create scope file allowing only specific files
  cat > "$scope_dir/${session_id}.json" << 'ENDJSON'
{
  "worker_ticket": "IMP-099",
  "allowed_files": ["src/allowed.ts", "src/also-allowed.ts"]
}
ENDJSON

  local input='{"tool_name": "Write", "session_id": "'"$session_id"'", "tool_input": {"file_path": "src/forbidden.ts"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 2 $rc "blocked file exits 2"
  assert_output_contains "block" "$output" "block output contains permission block"
  assert_output_contains "forbidden.ts" "$output" "block mentions attempted file"
  teardown
}

test_pass_allowed_file() {
  setup
  local session_id="test-worker-2"
  local scope_dir="$TMPDIR/.claude-sessions/worker-scope"
  mkdir -p "$scope_dir"

  cat > "$scope_dir/${session_id}.json" << 'ENDJSON'
{
  "worker_ticket": "IMP-099",
  "allowed_files": ["src/allowed.ts", "src/also-allowed.ts"]
}
ENDJSON

  local input='{"tool_name": "Write", "session_id": "'"$session_id"'", "tool_input": {"file_path": "src/allowed.ts"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "allowed file exits 0"
  assert_output_empty "$output" "allowed file produces no output"
  teardown
}

test_pass_no_scope_file() {
  setup
  # No scope file exists — pass-through (normal mode, no supervisor)
  local input='{"tool_name": "Write", "session_id": "no-scope-session", "tool_input": {"file_path": "anything.ts"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "no scope file exits 0 (pass-through)"
  assert_output_empty "$output" "no scope file produces no output"
  teardown
}

test_pass_non_write_tool() {
  setup
  local session_id="test-worker-3"
  local scope_dir="$TMPDIR/.claude-sessions/worker-scope"
  mkdir -p "$scope_dir"

  cat > "$scope_dir/${session_id}.json" << 'ENDJSON'
{
  "worker_ticket": "IMP-099",
  "allowed_files": ["src/allowed.ts"]
}
ENDJSON

  # Bash tool should pass through regardless of scope
  local input='{"tool_name": "Bash", "session_id": "'"$session_id"'", "tool_input": {"command": "ls"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "Bash tool exits 0 (pass-through)"
  assert_output_empty "$output" "non-Write/Edit tool produces no output"
  teardown
}

test_edit_tool_also_enforced() {
  setup
  local session_id="test-worker-4"
  local scope_dir="$TMPDIR/.claude-sessions/worker-scope"
  mkdir -p "$scope_dir"

  cat > "$scope_dir/${session_id}.json" << 'ENDJSON'
{
  "worker_ticket": "IMP-099",
  "allowed_files": ["src/allowed.ts"]
}
ENDJSON

  # Edit on a file NOT in scope
  local input='{"tool_name": "Edit", "session_id": "'"$session_id"'", "tool_input": {"file_path": "src/nope.ts"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 2 $rc "Edit on out-of-scope file exits 2"
  assert_output_contains "block" "$output" "Edit block output present"
  teardown
}

test_pass_no_session_id() {
  setup
  # No session_id — pass-through
  local input='{"tool_name": "Write", "tool_input": {"file_path": "anything.ts"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "no session_id exits 0 (pass-through)"
  assert_output_empty "$output" "no session_id produces no output"
  teardown
}

# --- Runner ---
echo "=== [scope-enforcer] Tests ==="
test_hook_syntax
test_install_syntax
test_block_out_of_scope
test_pass_allowed_file
test_pass_no_scope_file
test_pass_non_write_tool
test_edit_tool_also_enforced
test_pass_no_session_id
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
