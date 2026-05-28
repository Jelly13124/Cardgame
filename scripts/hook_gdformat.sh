#!/usr/bin/env bash
# PostToolUse hook. After Claude edits a file, if the target is a project
# .gd script, run gdformat (gdtoolkit) on it in place so GDScript stays
# consistently formatted. Non-blocking: a parse error mid-edit is reported
# but never blocks (the Stop-hook smoke test is the real correctness gate).
#
# gdtoolkit is installed in the user site (gdformat.exe isn't on PATH), so we
# invoke the formatter via `python -m gdtoolkit.formatter`, which only needs
# `python` on PATH.
#
# Wired from .claude/settings.json hooks.PostToolUse (matcher Edit|Write).

set -uo pipefail

INPUT="$(cat)"

TARGET="$(printf '%s' "$INPUT" | python -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
ti = data.get("tool_input", {}) or {}
print(ti.get("file_path") or "")
' 2>/dev/null)"

[ -z "$TARGET" ] && exit 0

NORM="${TARGET//\\//}"

# Only GDScript, and never reformat vendored / generated code.
case "$NORM" in
    *.gd) : ;;
    *) exit 0 ;;
esac
case "$NORM" in
    */addons/*|addons/*|*/generated_sheet/*) exit 0 ;;
esac

[ -f "$TARGET" ] || exit 0

if ! python -m gdtoolkit.formatter "$TARGET" >/dev/null 2>fmt_err.tmp; then
    echo "[hook_gdformat] gdformat could not format '$TARGET' (likely a parse error mid-edit; left untouched):" >&2
    sed 's/^/  /' fmt_err.tmp >&2 2>/dev/null || true
    rm -f fmt_err.tmp
    exit 0  # non-blocking
fi
rm -f fmt_err.tmp
exit 0
