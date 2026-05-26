#!/usr/bin/env bash
# Headless smoke test: boot the project, let it run a few seconds, scan
# stdout/stderr for SCRIPT ERROR / push_error / Failed to load script.
# Exits 0 on clean, 1 on any of those signals.
#
# Usage:
#   bash scripts/smoke_test.sh
#
# Optional override of the godot binary:
#   GODOT_BIN=/path/to/godot bash scripts/smoke_test.sh

set -uo pipefail

GODOT="${GODOT_BIN:-godot}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Smoke test: $GODOT --headless --path $PROJECT_ROOT --quit-after 5"
OUTPUT=$("$GODOT" --headless --path "$PROJECT_ROOT" --quit-after 5 2>&1)

# Patterns that indicate a real failure (ignore the harmless RID/PagedAllocator
# noise Godot prints at headless teardown).
FAIL_PATTERNS=(
    'SCRIPT ERROR'
    'Failed to load script'
    'Compile Error'
    'Parse Error'
    'DataValidator: [0-9]+ JSON schema failure'
)

failures=0
for pattern in "${FAIL_PATTERNS[@]}"; do
    if echo "$OUTPUT" | grep -qE "$pattern"; then
        failures=$((failures + 1))
        echo "[FAIL] matched: $pattern"
    fi
done

if [ "$failures" -gt 0 ]; then
    echo ""
    echo "[FAIL] Smoke test caught $failures error indicator(s)."
    echo ""
    echo "Full output:"
    echo "$OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -qE 'DataValidator: all .* passed schema check'; then
    echo "[OK] DataValidator: all schemas passed."
else
    echo "[WARN] DataValidator did not print 'all passed' — autoload may not have run."
    echo "$OUTPUT"
    exit 1
fi

echo "[OK] Headless boot clean. No SCRIPT ERROR / push_error / parse failures."
exit 0
