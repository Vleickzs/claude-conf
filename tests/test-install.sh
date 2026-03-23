#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$ROOT_DIR/install.sh"
PASS=0
FAIL=0

# --- Helpers ---
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

# --- Tests ---

test_syntax_check() {
  set +e
  bash -n "$INSTALL_SCRIPT" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    assert_pass "install.sh syntax valid"
  else
    assert_fail "install.sh syntax valid" "bash -n returned $rc"
  fi
}

test_no_arithmetic_increment() {
  # ((var++)) is a bash-ism that can fail with set -e when var=0
  # The codebase should use $((var + 1)) instead
  set +e
  grep -qE '\(\([a-z]+\+\+\)\)' "$INSTALL_SCRIPT"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    assert_pass "no ((var++)) arithmetic patterns"
  else
    assert_fail "no ((var++)) arithmetic patterns" "found ((var++)) in install.sh"
  fi
}

test_arrays_synchronized() {
  # MODULES, DESCRIPTIONS, DEPS must have same number of elements
  # Count by extracting array content between parentheses
  local modules_count descriptions_count deps_count

  # Source the arrays in a subshell to count them
  modules_count=$(bash -c 'source <(grep -A 1 "^MODULES=" "'"$INSTALL_SCRIPT"'" | head -1 | sed "s/MODULES=//"); echo ${#MODULES[@]}' 2>/dev/null || echo "0")

  # Alternative: count by looking at the structure
  # MODULES is a single-line array
  modules_count=$(grep -oE '"[^"]+"' <(sed -n '/^MODULES=/p' "$INSTALL_SCRIPT") | wc -l | tr -d ' ')

  # DESCRIPTIONS is a multi-line array — count entries between ( and )
  descriptions_count=$(sed -n '/^DESCRIPTIONS=(/,/^)/p' "$INSTALL_SCRIPT" | grep -c '"' | tr -d ' ')

  # DEPS is a multi-line array
  deps_count=$(sed -n '/^DEPS=(/,/^)/p' "$INSTALL_SCRIPT" | grep -c '"' | tr -d ' ')

  if [ "$modules_count" -eq "$descriptions_count" ] && [ "$modules_count" -eq "$deps_count" ]; then
    assert_pass "arrays synchronized (MODULES=$modules_count, DESCRIPTIONS=$descriptions_count, DEPS=$deps_count)"
  else
    assert_fail "arrays synchronized" "MODULES=$modules_count, DESCRIPTIONS=$descriptions_count, DEPS=$deps_count"
  fi
}

test_modules_directories_exist() {
  # Each module in MODULES array should have a directory with install.sh
  local all_exist=true
  local missing=""

  # Extract module names from the MODULES array line
  local modules
  modules=$(grep '^MODULES=' "$INSTALL_SCRIPT" | grep -oE '"[^"]+"' | tr -d '"')

  while IFS= read -r mod; do
    [ -z "$mod" ] && continue
    if [ ! -d "$ROOT_DIR/$mod" ]; then
      all_exist=false
      missing="$missing $mod(dir)"
    elif [ ! -f "$ROOT_DIR/$mod/install.sh" ]; then
      all_exist=false
      missing="$missing $mod(install.sh)"
    fi
  done <<< "$modules"

  if $all_exist; then
    assert_pass "all modules have directory + install.sh"
  else
    assert_fail "all modules have directory + install.sh" "missing:$missing"
  fi
}

# --- Runner ---
echo "=== [install.sh] Tests ==="
test_syntax_check
test_no_arithmetic_increment
test_arrays_synchronized
test_modules_directories_exist
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
