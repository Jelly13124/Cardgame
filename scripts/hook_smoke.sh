#!/usr/bin/env bash
# Stop-hook smoke gate. Runs ONLY when there are uncommitted .gd / .json /
# .tscn changes in the working tree, so non-code turns don't pay the
# ~5s headless-boot tax. On failure it prints to stderr and exits 2,
# which Claude Code treats as "block stop" — the failure is fed back so
# Claude fixes it before declaring the turn done.
#
# Wired from .claude/settings.json hooks.Stop.

set -uo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT" || exit 0

# Any code/data files dirty? (staged or unstaged)
CHANGED="$(git status --porcelain 2>/dev/null | grep -E '\.(gd|json|tscn)$' || true)"
if [ -z "$CHANGED" ]; then
    exit 0  # nothing code-relevant changed this turn — skip the smoke run
fi

GODOT="${GODOT_BIN:-godot}"
OUTPUT=$("$GODOT" --headless --path "$PROJECT_ROOT" --quit-after 5 2>&1)

# Same failure patterns as scripts/smoke_test.sh.
if echo "$OUTPUT" | grep -qE 'SCRIPT ERROR|Failed to load script|Compile Error|Parse Error|DataValidator: [0-9]+ JSON schema failure'; then
    echo "[hook_smoke] Headless smoke FAILED — fix before finishing the turn:" >&2
    echo "$OUTPUT" | grep -E 'SCRIPT ERROR|Failed to load script|Compile Error|Parse Error|DataValidator: [0-9]+ JSON schema failure' >&2
    exit 2
fi

exit 0
