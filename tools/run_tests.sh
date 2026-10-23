#!/usr/bin/env bash
# One-command test runner (bash version of tools/run_tests.ps1): isolated user
# data, import, smoke boot, scene tests, expected failures, layering check.
#
# Usage:
#   GODOT_BIN=/path/to/godot bash tools/run_tests.sh            # full run
#   GODOT_BIN=/path/to/godot bash tools/run_tests.sh 'save_io*'  # subset, no smoke/layers
#
# Exit codes: 0 = all passed (expected failures allowed), 1 = failure or XPASS,
# 2 = environment problem.
set -u

ONLY="${1:-*}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ERROR_PATTERN='SCRIPT ERROR|Failed to load script|Compile Error|Parse Error|DataValidator: [0-9]+ JSON schema failure'

GODOT="${GODOT_BIN:-$(command -v godot || true)}"
if [ -z "$GODOT" ] || [ ! -e "$GODOT" ]; then
  echo "Godot not found. Set GODOT_BIN to the Godot 4.6 executable." >&2
  exit 2
fi

RUN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cardgame-tests-XXXXXX")"
USER_DIR="$RUN_DIR/userdata"
LOG_DIR="$RUN_DIR/logs"
mkdir -p "$USER_DIR" "$LOG_DIR"
# Godot resolves user:// from APPDATA on Windows and XDG_DATA_HOME on Linux.
if command -v cygpath >/dev/null 2>&1; then
  export APPDATA="$(cygpath -w "$USER_DIR")"
else
  export APPDATA="$USER_DIR"
fi
export XDG_DATA_HOME="$USER_DIR"

EXIT_CODE=0
cleanup() {
  if [ "$EXIT_CODE" -eq 0 ]; then rm -rf "$RUN_DIR"; else echo "Logs kept at $LOG_DIR"; rm -rf "$USER_DIR"; fi
}
trap cleanup EXIT

run_godot() { # <log> <timeout> <args...>
  local log="$1" t="$2"; shift 2
  timeout "$t" "$GODOT" "$@" >"$log" 2>&1
}

echo "Godot:    $GODOT"
echo "Project:  $ROOT"
echo "UserData: $USER_DIR (isolated)"

# Always import: quick when nothing changed, and it refreshes a stale .godot
# cache (new uids after a pull/merge, or a partial cache from a crashed import).
if true; then
  imported=0
  for attempt in 1 2 3; do
    if run_godot "$LOG_DIR/import_$attempt.log" 1200 --headless --path "$ROOT" --import \
      && ! grep -q FATAL "$LOG_DIR/import_$attempt.log"; then
      imported=1
      [ "$attempt" -gt 1 ] && echo "import: retried $((attempt - 1))"
      break
    fi
  done
  if [ "$imported" -ne 1 ]; then echo "import: failed 3 times"; EXIT_CODE=2; exit 2; fi
  echo "import: ok"
fi

FULL_RUN=0
[ "$ONLY" = "*" ] && FULL_RUN=1

if [ "$FULL_RUN" -eq 1 ]; then
  if run_godot "$LOG_DIR/smoke.log" 120 --headless --path "$ROOT" --quit-after 5 \
    && ! grep -Eq "$ERROR_PATTERN" "$LOG_DIR/smoke.log"; then
    echo "smoke: ok"
  else
    echo "smoke: FAIL"; EXIT_CODE=1
  fi
fi

EXPECTED_FILE="$ROOT/tests/expected_failures.txt"
is_expected() { [ -f "$EXPECTED_FILE" ] && grep -Ev '^\s*(#|$)' "$EXPECTED_FILE" | awk '{print $1}' | grep -qx "$1"; }

pass=0; fail=0; xfail=0; xpass=0; found=0
printf '%-40s %-6s %s\n' "Test" "Result" "Seconds"
for scene in "$ROOT"/tests/*_test.tscn; do
  name="$(basename "$scene" .tscn)"
  case "$name" in *visual_capture*) continue ;; esac
  # shellcheck disable=SC2254
  case "$name" in $ONLY) ;; *) continue ;; esac
  found=1
  log="$LOG_DIR/$name.log"
  start=$(date +%s)
  if run_godot "$log" "$TIMEOUT_SECONDS" --headless --path "$ROOT" "res://tests/$name.tscn" \
    && ! grep -Eq "$ERROR_PATTERN" "$log"; then ok=1; else ok=0; fi
  secs=$(( $(date +%s) - start ))
  if is_expected "$name"; then
    if [ "$ok" -eq 1 ]; then status=XPASS; xpass=$((xpass + 1)); EXIT_CODE=1; else status=XFAIL; xfail=$((xfail + 1)); fi
  else
    if [ "$ok" -eq 1 ]; then status=PASS; pass=$((pass + 1)); else status=FAIL; fail=$((fail + 1)); EXIT_CODE=1; fi
  fi
  printf '%-40s %-6s %s\n' "$name" "$status" "$secs"
  if [ "$status" = FAIL ] || [ "$status" = XPASS ]; then tail -30 "$log" | sed 's/^/  /'; fi
  if [ "$status" = XFAIL ]; then grep '^MISMATCH' "$log" | head -20 | sed "s/^/  [$name] /"; fi
done
if [ "$found" -eq 0 ]; then echo "No tests match '$ONLY'."; EXIT_CODE=2; exit 2; fi

if [ "$FULL_RUN" -eq 1 ]; then
  if python -m unittest discover -s "$ROOT/tools/tests" >"$LOG_DIR/tools_unit.log" 2>&1; then
    echo "tools unit tests: ok"
  else
    cat "$LOG_DIR/tools_unit.log"; echo "tools unit tests: FAIL"; EXIT_CODE=1
  fi
  if [ -f "$ROOT/tools/check_layers.py" ]; then
    python "$ROOT/tools/check_layers.py" --root "$ROOT" || EXIT_CODE=1
  else
    echo "layers: skipped"
  fi
fi

echo "passed=$pass failed=$fail xfail=$xfail xpass=$xpass"
[ "$xpass" -gt 0 ] && echo "XPASS: remove the fixed tests from tests/expected_failures.txt"
exit "$EXIT_CODE"
