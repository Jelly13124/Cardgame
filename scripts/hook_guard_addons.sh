#!/usr/bin/env bash
# PreToolUse guard. Blocks Edit/Write/NotebookEdit on machine-generated files
# that must never be hand-edited:
#   - addons/                  vendored (card-framework) per ADR-0005
#   - **/generated_sheet/**    Codex art-pipeline intermediates (ADR-0005: Codex
#                              owns assets/images/**, Claude must not touch them)
#   - *.import                 Godot writes these on import (project-rules §4)
#   - *.uid                    Godot-generated script UID sidecars
# Reads the tool-call JSON on stdin, pulls the target path, and exits 2
# (deny + feed message to Claude) if it matches one of the patterns.
#
# Wired from .claude/settings.json hooks.PreToolUse (matcher Edit|Write|NotebookEdit).

set -uo pipefail

INPUT="$(cat)"

# Extract the target path from the tool input. Edit/Write use file_path;
# NotebookEdit uses notebook_path. python3 is available in this project's env.
TARGET="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)
ti = data.get("tool_input", {}) or {}
print(ti.get("file_path") or ti.get("notebook_path") or "")
' 2>/dev/null)"

if [ -z "$TARGET" ]; then
    exit 0  # no path / unparseable → let it through
fi

# Normalize backslashes to forward slashes for the match.
NORM="${TARGET//\\//}"

case "$NORM" in
    */addons/*|addons/*)
        echo "[hook_guard_addons] BLOCKED: '$TARGET' is under addons/ (vendored — card-framework). Per ADR-0005 these are never hand-edited. If you genuinely need to change vendored code, do it outside Claude or update the ADR first." >&2
        exit 2
        ;;
    */generated_sheet/*)
        echo "[hook_guard_addons] BLOCKED: '$TARGET' is under a generated_sheet/ folder — Codex art-pipeline intermediates. Per ADR-0005 Codex owns assets/images/** and Claude must not hand-edit generated art. Change the asset-spec doc instead, or let Codex regenerate." >&2
        exit 2
        ;;
    *.import)
        echo "[hook_guard_addons] BLOCKED: '$TARGET' is a Godot .import sidecar — auto-generated on import (project-rules §4). Never hand-edit it; let Godot rewrite it." >&2
        exit 2
        ;;
    *.uid)
        echo "[hook_guard_addons] BLOCKED: '$TARGET' is a Godot .uid sidecar — auto-generated. Never hand-edit it." >&2
        exit 2
        ;;
esac

exit 0
