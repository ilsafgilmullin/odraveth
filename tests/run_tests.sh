#!/usr/bin/env bash
# Headless checks for ODRAVETH. Requires Godot 4.7.2 stable (no other version).
#
# Usage:
#   GODOT_BIN=/path/to/Godot_v4.7.2-stable_linux.x86_64 tests/run_tests.sh
#
# Steps:
#   1. import     - builds .godot/ (class_name registry, imports); must log no errors.
#   2. smoke_test - tests/smoke_test.tscn; exit code 0 and no leaks at exit.
#   3. main_scene - runs the real main scene for 300 frames; must reach the main
#                   menu (verbose SceneRouter log) and log no errors or warnings.
# Exit code: 0 = all passed, 1 = a check failed, 2 = Godot missing or wrong version.
set -euo pipefail

REQUIRED_VERSION="4.7.2.stable"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="$(mktemp -d)"
STEP_TIMEOUT_SECONDS=600
# Hard frame cap: if a script fails to compile, the scene would otherwise run forever.
MAX_FRAMES=5000
ERROR_PATTERN='^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING):|Parse Error|leaked'

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "ERROR: Godot binary '$GODOT_BIN' not found. Set GODOT_BIN to Godot $REQUIRED_VERSION." >&2
  exit 2
fi
version="$("$GODOT_BIN" --version | tail -n 1 | tr -d '\r')"
if [[ "$version" != "$REQUIRED_VERSION"* ]]; then
  echo "ERROR: Godot $REQUIRED_VERSION is required, found '$version'." >&2
  exit 2
fi
echo "Godot $version, logs in $LOG_DIR"

# run_step <name> <pattern-or-empty> <godot args...>
# Fails on a non-zero exit code or, when a pattern is given, on matching log lines.
run_step() {
  local name="$1" pattern="$2"
  shift 2
  local log="$LOG_DIR/$name.log"
  local runner=()
  if command -v timeout >/dev/null 2>&1; then
    runner=(timeout "$STEP_TIMEOUT_SECONDS")
  fi
  echo "==> $name"
  if ! "${runner[@]}" "$GODOT_BIN" --headless --path "$PROJECT_DIR" "$@" >"$log" 2>&1; then
    cat "$log"
    echo "FAILED: $name (non-zero exit code)"
    exit 1
  fi
  if [[ -n "$pattern" ]] && grep -nE "$pattern" "$log"; then
    echo "FAILED: $name (errors in log, full log: $log)"
    exit 1
  fi
}

run_step import "$ERROR_PATTERN" --import
# The smoke test prints expected errors of its negative checks and fails by
# itself on unexpected ones; here parse errors and leaks at exit are checked.
run_step smoke_test 'SCRIPT ERROR|Parse Error|leaked' --scene res://tests/smoke_test.tscn --quit-after "$MAX_FRAMES"
if ! grep -E "SMOKE TEST PASSED" "$LOG_DIR/smoke_test.log"; then
  cat "$LOG_DIR/smoke_test.log"
  echo "FAILED: smoke_test (no PASSED summary)"
  exit 1
fi
run_step main_scene "$ERROR_PATTERN" --verbose --quit-after 300
if ! grep -q "SceneRouter: opened 'main_menu'" "$LOG_DIR/main_scene.log"; then
  echo "FAILED: main_scene (Boot did not open the main menu, full log: $LOG_DIR/main_scene.log)"
  exit 1
fi
echo "Boot -> Main Menu confirmed."

echo "All checks passed."
