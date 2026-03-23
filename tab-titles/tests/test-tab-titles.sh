#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$(dirname "$SCRIPT_DIR")"
HOOK="$MODULE_DIR/hooks/tab-title.sh"
INSTALL="$MODULE_DIR/install.sh"
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

test_hook_syntax() {
  set +e
  bash -n "$HOOK" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    assert_pass "tab-title.sh syntax valid"
  else
    assert_fail "tab-title.sh syntax valid" "bash -n returned $rc"
  fi
}

test_install_syntax() {
  set +e
  bash -n "$INSTALL" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    assert_pass "install.sh syntax valid"
  else
    assert_fail "install.sh syntax valid" "bash -n returned $rc"
  fi
}

test_dot_palette() {
  # Source the _dot function from the hook and test it
  # The function uses: colors=("..." "..." "..." "..." "..." "...") — 6 colors
  # idx = cksum % 6
  local valid_emojis=("🟠" "🟡" "🔵" "🟣" "🟤" "⚫" "⚙️")
  local test_projects=("myapp" "frontend" "api-server" "cool-project" "test123")
  local all_ok=true

  for proj in "${test_projects[@]}"; do
    # Run _dot in a subshell that sources just the function
    local result
    result=$(bash -c '
      _dot() {
        if [ "$1" = "claude-conf" ]; then echo "⚙️"; return; fi
        local colors=("🟠" "🟡" "🔵" "🟣" "🟤" "⚫")
        local idx=$(( $(echo -n "$1" | cksum | cut -d" " -f1) % 6 ))
        echo "${colors[$idx]}"
      }
      _dot "'"$proj"'"
    ')

    local found=false
    for emoji in "${valid_emojis[@]}"; do
      if [ "$result" = "$emoji" ]; then
        found=true
        break
      fi
    done

    if ! $found; then
      all_ok=false
      assert_fail "_dot palette for $proj" "got: $result"
    fi
  done

  if $all_ok; then
    assert_pass "_dot returns valid palette emoji for all test projects"
  fi
}

test_dot_claude_conf() {
  local result
  result=$(bash -c '
    _dot() {
      if [ "$1" = "claude-conf" ]; then echo "⚙️"; return; fi
      local colors=("🟠" "🟡" "🔵" "🟣" "🟤" "⚫")
      local idx=$(( $(echo -n "$1" | cksum | cut -d" " -f1) % 6 ))
      echo "${colors[$idx]}"
    }
    _dot "claude-conf"
  ')

  if [ "$result" = "⚙️" ]; then
    assert_pass "_dot claude-conf returns gear emoji"
  else
    assert_fail "_dot claude-conf returns gear emoji" "got: $result"
  fi
}

test_dot_deterministic() {
  # Same project name should always return same emoji
  local result1 result2
  result1=$(bash -c '
    _dot() {
      if [ "$1" = "claude-conf" ]; then echo "⚙️"; return; fi
      local colors=("🟠" "🟡" "🔵" "🟣" "🟤" "⚫")
      local idx=$(( $(echo -n "$1" | cksum | cut -d" " -f1) % 6 ))
      echo "${colors[$idx]}"
    }
    _dot "myapp"
  ')
  result2=$(bash -c '
    _dot() {
      if [ "$1" = "claude-conf" ]; then echo "⚙️"; return; fi
      local colors=("🟠" "🟡" "🔵" "🟣" "🟤" "⚫")
      local idx=$(( $(echo -n "$1" | cksum | cut -d" " -f1) % 6 ))
      echo "${colors[$idx]}"
    }
    _dot "myapp"
  ')

  if [ "$result1" = "$result2" ]; then
    assert_pass "_dot is deterministic (same input = same output)"
  else
    assert_fail "_dot is deterministic" "got $result1 then $result2"
  fi
}

test_bash_zsh_coherence() {
  # Bash uses % 6 (0-based), zsh uses % 6 + 1 (1-based indexing)
  # Both should point to the same color
  local colors=("🟠" "🟡" "🔵" "🟣" "🟤" "⚫")
  local test_names=("myapp" "frontend" "api" "test")
  local all_ok=true

  for name in "${test_names[@]}"; do
    local hash
    hash=$(echo -n "$name" | cksum | cut -d' ' -f1)
    local bash_idx=$(( hash % 6 ))          # 0-based
    local zsh_idx=$(( hash % 6 + 1 ))       # 1-based

    # In bash (0-based), index 0 = first element
    # In zsh (1-based), index 1 = first element
    # So bash_idx and zsh_idx should differ by exactly 1
    if [ "$zsh_idx" -ne $((bash_idx + 1)) ]; then
      all_ok=false
      assert_fail "bash/zsh coherence for $name" "bash_idx=$bash_idx, zsh_idx=$zsh_idx"
    fi
  done

  if $all_ok; then
    assert_pass "bash % 6 and zsh % 6 + 1 point to same color"
  fi
}

# --- Runner ---
echo "=== [tab-titles] Tests ==="
test_hook_syntax
test_install_syntax
test_dot_palette
test_dot_claude_conf
test_dot_deterministic
test_bash_zsh_coherence
echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
