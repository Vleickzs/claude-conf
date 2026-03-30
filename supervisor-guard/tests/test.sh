#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
GUARD_HOOK="$MODULE_DIR/hooks/supervisor-guard.sh"
DETECT_HOOK="$MODULE_DIR/hooks/supervisor-detect.sh"
INSTALL="$MODULE_DIR/install.sh"
PASS=0
FAIL=0

# --- Helpers ---
setup() {
  TMPDIR=$(mktemp -d)
  ORIG_HOME="$HOME"
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

assert_file_exists() {
  local file=$1 test_name=$2
  if [ -f "$file" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (file not found: $file)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local file=$1 test_name=$2
  if [ ! -f "$file" ]; then
    echo "  PASS: $test_name"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $test_name (file should not exist: $file)"
    FAIL=$((FAIL + 1))
  fi
}

# --- Syntax Tests ---

test_guard_syntax() {
  set +e
  bash -n "$GUARD_HOOK" 2>/dev/null
  rc=$?
  set -e
  assert_exit 0 $rc "supervisor-guard.sh syntax valid"
}

test_detect_syntax() {
  set +e
  bash -n "$DETECT_HOOK" 2>/dev/null
  rc=$?
  set -e
  assert_exit 0 $rc "supervisor-detect.sh syntax valid"
}

test_install_syntax() {
  set +e
  bash -n "$INSTALL" 2>/dev/null
  rc=$?
  set -e
  assert_exit 0 $rc "install.sh syntax valid"
}

# --- Guard Hook Tests ---

test_write_source_with_marker() {
  setup
  local session_id="test-sup-1"
  mkdir -p "$TMPDIR/.claude-sessions/supervisor-active"
  touch "$TMPDIR/.claude-sessions/supervisor-active/${session_id}"

  local input='{"tool_name":"Write","session_id":"'"$session_id"'","tool_input":{"file_path":"src/main.dart"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 2 $rc "Write on source WITH marker → blocked"
  assert_output_contains "block" "$output" "block output present"
  assert_output_contains "main.dart" "$output" "mentions attempted file"
  teardown
}

test_edit_source_with_marker() {
  setup
  local session_id="test-sup-2"
  mkdir -p "$TMPDIR/.claude-sessions/supervisor-active"
  touch "$TMPDIR/.claude-sessions/supervisor-active/${session_id}"

  local input='{"tool_name":"Edit","session_id":"'"$session_id"'","tool_input":{"file_path":"lib/widget.dart"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 2 $rc "Edit on source WITH marker → blocked"
  assert_output_contains "block" "$output" "Edit block output present"
  teardown
}

test_write_backlog_with_marker() {
  setup
  local session_id="test-sup-3"
  mkdir -p "$TMPDIR/.claude-sessions/supervisor-active"
  touch "$TMPDIR/.claude-sessions/supervisor-active/${session_id}"

  local input='{"tool_name":"Write","session_id":"'"$session_id"'","tool_input":{"file_path":"BACKLOG/BUGS/PENDING/BUG-011.md"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "Write on BACKLOG/ WITH marker → allowed"
  assert_output_empty "$output" "BACKLOG write produces no output"
  teardown
}

test_write_sessions_with_marker() {
  setup
  local session_id="test-sup-4"
  mkdir -p "$TMPDIR/.claude-sessions/supervisor-active"
  touch "$TMPDIR/.claude-sessions/supervisor-active/${session_id}"

  local input='{"tool_name":"Write","session_id":"'"$session_id"'","tool_input":{"file_path":".claude-sessions/manifests/test.txt"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "Write on .claude-sessions/ WITH marker → allowed"
  assert_output_empty "$output" ".claude-sessions write produces no output"
  teardown
}

test_write_index_with_marker() {
  setup
  local session_id="test-sup-5"
  mkdir -p "$TMPDIR/.claude-sessions/supervisor-active"
  touch "$TMPDIR/.claude-sessions/supervisor-active/${session_id}"

  local input='{"tool_name":"Write","session_id":"'"$session_id"'","tool_input":{"file_path":"BACKLOG/INDEX.md"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "Write on INDEX.md WITH marker → allowed"
  assert_output_empty "$output" "INDEX.md write produces no output"
  teardown
}

test_write_source_without_marker() {
  setup
  # No marker file, no env var
  local input='{"tool_name":"Write","session_id":"no-marker-session","tool_input":{"file_path":"src/main.dart"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "Write on source WITHOUT marker → allowed (guard inactive)"
  assert_output_empty "$output" "no marker produces no output"
  teardown
}

test_module_disabled() {
  setup
  echo "supervisor-guard" > "$TMPDIR/.claude-conf-disabled"

  local session_id="test-sup-disabled"
  mkdir -p "$TMPDIR/.claude-sessions/supervisor-active"
  touch "$TMPDIR/.claude-sessions/supervisor-active/${session_id}"

  local input='{"tool_name":"Write","session_id":"'"$session_id"'","tool_input":{"file_path":"src/main.dart"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "Module disabled → allowed"
  assert_output_empty "$output" "disabled module produces no output"
  teardown
}

test_non_write_edit_tool() {
  setup
  local session_id="test-sup-bash"
  mkdir -p "$TMPDIR/.claude-sessions/supervisor-active"
  touch "$TMPDIR/.claude-sessions/supervisor-active/${session_id}"

  local input='{"tool_name":"Bash","session_id":"'"$session_id"'","tool_input":{"command":"ls"}}'

  set +e
  output=$(echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 0 $rc "Bash tool → allowed (pass-through)"
  assert_output_empty "$output" "non-Write/Edit tool produces no output"
  teardown
}

test_env_var_fallback() {
  setup
  # No marker file, but env var set
  local input='{"tool_name":"Write","session_id":"env-var-session","tool_input":{"file_path":"src/main.dart"}}'

  set +e
  output=$(echo "$input" | CC_SUPERVISOR_SESSION=1 HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$GUARD_HOOK'" 2>&1)
  rc=$?
  set -e

  assert_exit 2 $rc "Env var fallback: Write on source → blocked"
  assert_output_contains "block" "$output" "env var fallback block output present"
  teardown
}

# --- Detect Hook Tests ---

test_detect_supervisor_slash() {
  setup
  local session_id="detect-slash-1"
  local input='{"prompt":"/supervisor","session_id":"'"$session_id"'"}'

  set +e
  echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$DETECT_HOOK'" 2>&1
  rc=$?
  set -e

  assert_exit 0 $rc "detect hook exits 0"
  assert_file_exists "$TMPDIR/.claude-sessions/supervisor-active/${session_id}" "/supervisor creates marker"
  teardown
}

test_detect_command_tag() {
  setup
  local session_id="detect-tag-1"
  local input='{"prompt":"some text <command-name>/supervisor</command-name> more text","session_id":"'"$session_id"'"}'

  set +e
  echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$DETECT_HOOK'" 2>&1
  rc=$?
  set -e

  assert_exit 0 $rc "detect hook exits 0 (command tag)"
  assert_file_exists "$TMPDIR/.claude-sessions/supervisor-active/${session_id}" "command-name tag creates marker"
  teardown
}

test_detect_normal_prompt() {
  setup
  local session_id="detect-normal-1"
  local input='{"prompt":"just a normal message","session_id":"'"$session_id"'"}'

  set +e
  echo "$input" | HOME="$TMPDIR" bash -c "cd '$TMPDIR' && bash '$DETECT_HOOK'" 2>&1
  rc=$?
  set -e

  assert_exit 0 $rc "detect hook exits 0 (normal prompt)"
  assert_file_not_exists "$TMPDIR/.claude-sessions/supervisor-active/${session_id}" "normal prompt does NOT create marker"
  teardown
}

# --- Runner ---
echo "=== [supervisor-guard] Tests ==="
echo ""
echo "-- Syntax --"
test_guard_syntax
test_detect_syntax
test_install_syntax
echo ""
echo "-- Guard hook --"
test_write_source_with_marker
test_edit_source_with_marker
test_write_backlog_with_marker
test_write_sessions_with_marker
test_write_index_with_marker
test_write_source_without_marker
test_module_disabled
test_non_write_edit_tool
test_env_var_fallback
echo ""
echo "-- Detect hook --"
test_detect_supervisor_slash
test_detect_command_tag
test_detect_normal_prompt
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
