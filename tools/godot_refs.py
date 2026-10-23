"""Rewrite GDScript references to scripts and scenes from res:// paths to uid://.

A uid:// reference survives moving the file (as long as its .uid sidecar or
scene header moves with it), so later directory reorganisations do not break
preloads. The original path is kept as a trailing comment for readability.

Usage (from the project root):
    python tools/godot_refs.py convert [--dry-run]
    python tools/godot_refs.py check

What is converted:
  * preload("res://...gd|tscn") / load(...) literals, including a preload( whose
    argument sits on the next line;
  * every other "res://....tscn" literal (scene constants, change_to(...)),
    unless the line reads the file as text (FileAccess / get_file_as_string);
  * `const NAME := "res://....gd"` when NAME is only used by load(), preload()
    or ResourceLoader.exists().
Never converted: `extends "res://..."` (Godot 4.6 has no uid support there),
comments, concatenated or formatted paths, and lines marked `# path-ok: <why>`
(e.g. tests that read a script's source text, resource_path comparisons).

`convert` is all-or-nothing: if any reference has no uid it reports them and
writes nothing (exit 1). `check` lists remaining path references (exit 1).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

DEFAULT_DIRS = ["autoload", "battle_scene", "core", "run_system", "tests"]
LITERAL = re.compile(r'"(res://[^"%+]+?\.(?:gd|tscn))"')
SCENE_UID = re.compile(r'^\[gd_scene[^\]]*\buid="(uid://[a-z0-9]+)"')
LOAD_CALL = re.compile(r'(?:pre)?load\(\s*$')
TEXT_READ = re.compile(r'FileAccess|get_file_as_string')
CONST_DECL = re.compile(r'^\s*const\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*\w+)?\s*:?=\s*"res://')


def build_uid_map(root: Path) -> dict[str, str]:
    """Map res:// paths of scripts (via .uid sidecars) and scenes (via header) to uids."""
    uids: dict[str, str] = {}
    for path in root.rglob("*"):
        rel_parts = path.relative_to(root).parts
        if rel_parts and rel_parts[0] == ".godot":
            continue
        if path.name.endswith(".gd.uid"):
            target = path.with_name(path.name[: -len(".uid")])
            uid = path.read_text(encoding="utf-8").strip()
            if uid.startswith("uid://"):
                uids["res://" + target.relative_to(root).as_posix()] = uid
        elif path.suffix == ".tscn":
            with path.open(encoding="utf-8") as f:
                m = SCENE_UID.match(f.readline())
            if m:
                uids["res://" + path.relative_to(root).as_posix()] = m.group(1)
    return uids


def split_comment(line: str) -> tuple[str, str]:
    """Split a GDScript line into (code, comment) at the first # outside a string."""
    quote = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            return line[:i], line[i:]
        i += 1
    return line, ""


def _is_skipped(code: str, comment: str) -> bool:
    stripped = code.strip()
    return stripped == "" or stripped.startswith("extends") or "path-ok" in comment


def _const_only_loaded(name: str, lines: list[str], decl_index: int) -> bool:
    use = re.compile(r'\b' + re.escape(name) + r'\b')
    allowed = re.compile(r'(?:(?:pre)?load|ResourceLoader\.exists)\(\s*' + re.escape(name) + r'\s*[,)]')
    used = False
    for i, line in enumerate(lines):
        if i == decl_index:
            continue
        code, _ = split_comment(line)
        for m in use.finditer(code):
            used = True
            if not allowed.search(code[max(0, m.start() - 40): m.end() + 2]):
                return False
    return used


def _convertible(lines: list[str], index: int, code: str, match: re.Match) -> bool:
    path = match.group(1)
    before = code[: match.start()]
    if LOAD_CALL.search(before):
        return True
    if before.strip() == "":
        for j in range(index - 1, -1, -1):
            prev_code, _ = split_comment(lines[j])
            if prev_code.strip():
                return bool(LOAD_CALL.search(prev_code.rstrip()))
    if path.endswith(".tscn"):
        return not TEXT_READ.search(code)
    decl = CONST_DECL.match(code)
    if decl and decl.end() - len('"res://') == match.start():
        return _const_only_loaded(decl.group(1), lines, index)
    return False


def _rewrite_line(line: str, replacements: list[tuple[str, str]]) -> str:
    ending = ""
    body = line
    for nl in ("\r\n", "\n"):
        if body.endswith(nl):
            body, ending = body[: -len(nl)], nl
            break
    code, comment = split_comment(body)
    paths = []
    for path, uid in replacements:
        code = code.replace(f'"{path}"', f'"{uid}"', 1)
        paths.append(path)
    note = ", ".join(paths)
    if comment:
        comment = comment.rstrip() + f" ({note})"
        return code + comment + ending
    return code.rstrip() + f"  # {note}" + ending


def iter_scripts(root: Path, dirs: list[str]):
    for d in dirs:
        base = root / d
        if base.is_dir():
            yield from sorted(base.rglob("*.gd"))


def convert(root: Path, dirs: list[str], dry_run: bool) -> int:
    uids = build_uid_map(root)
    pending: dict[Path, str] = {}
    missing: list[str] = []
    count = 0
    for script in iter_scripts(root, dirs):
        text = script.read_text(encoding="utf-8")
        lines = text.splitlines(keepends=True)
        changed = False
        for i, line in enumerate(lines):
            code, comment = split_comment(line)
            if _is_skipped(code, comment):
                continue
            reps = []
            for m in LITERAL.finditer(code):
                if not _convertible(lines, i, code, m):
                    continue
                path = m.group(1)
                uid = uids.get(path)
                if uid is None:
                    missing.append(f"{script.relative_to(root).as_posix()}:{i + 1} {path}")
                    continue
                reps.append((path, uid))
            if reps:
                lines[i] = _rewrite_line(line, reps)
                count += len(reps)
                changed = True
        if changed:
            pending[script] = "".join(lines)
    if missing:
        print("No uid found for these references (nothing written):")
        for item in missing:
            print("  " + item)
        return 1
    if not dry_run:
        for script, text in pending.items():
            script.write_text(text, encoding="utf-8", newline="")
    print(f"rewritten {count} references in {len(pending)} files" + (" (dry run)" if dry_run else ""))
    return 0


def check(root: Path, dirs: list[str]) -> int:
    leftovers = []
    for script in iter_scripts(root, dirs):
        for i, line in enumerate(script.read_text(encoding="utf-8").splitlines()):
            code, comment = split_comment(line)
            if _is_skipped(code, comment):
                continue
            for m in LITERAL.finditer(code):
                leftovers.append(f"{script.relative_to(root).as_posix()}:{i + 1} {m.group(1)}")
    if leftovers:
        print("Script/scene path references left (use uid:// or mark `# path-ok: <why>`):")
        for item in leftovers:
            print("  " + item)
        return 1
    print("refs: ok")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("command", choices=["convert", "check"])
    parser.add_argument("--root", default=".", help="project root (default: current directory)")
    parser.add_argument("--dry-run", action="store_true", help="convert: report without writing")
    parser.add_argument("--dirs", default=",".join(DEFAULT_DIRS), help="comma-separated directories to scan")
    args = parser.parse_args(argv)
    root = Path(args.root).resolve()
    dirs = [d for d in args.dirs.split(",") if d]
    if args.command == "convert":
        return convert(root, dirs, args.dry_run)
    return check(root, dirs)


if __name__ == "__main__":
    sys.exit(main())
