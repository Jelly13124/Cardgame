"""Check the architecture layering rules (docs/conventions/architecture-layers.md).

Usage (from the project root):
    python tools/check_layers.py            # all rules
    python tools/check_layers.py --skip-refs

Rules:
  L1  core/ must not reference UI paths (ui/, run_system/ui/),
      whether written as res:// or as a uid:// that resolves to one.
  L2  core/ must not use the scene tree (get_tree(), current_scene, get_node(,
      get_node_or_null(, $Node).
  L3  content/ holds data only: no .gd files.
  L4  scripts and scenes are referenced by uid:// (delegates to godot_refs.py check).
Comments are ignored. Prints `layers: ok` or one line per violation; exit 1 on
any violation.
"""

from __future__ import annotations

import argparse
import io
import re
import sys
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot_refs  # noqa: E402

UI_PATH = re.compile(r'res://(?:ui|run_system/ui)/')
UID_LITERAL = re.compile(r'uid://[a-z0-9]+')
SCENE_TREE = re.compile(
    r'\bget_tree\(\)|\bcurrent_scene\b|\bget_node(?:_or_null)?\(|(?<![\w"\'])\$[A-Za-z_"%]'
)


def _code_lines(path: Path):
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, _ = godot_refs.split_comment(line)
        yield number, code


def check(root: Path, include_refs: bool) -> list[str]:
    violations: list[str] = []
    core = root / "core"
    if core.is_dir():
        # References are written as uid://, so resolve them back to paths for L1.
        path_by_uid = {uid: path for path, uid in godot_refs.build_uid_map(root).items()}
        for script in sorted(core.rglob("*.gd")):
            rel = script.relative_to(root).as_posix()
            for number, code in _code_lines(script):
                targets = code + " " + " ".join(
                    path_by_uid.get(uid, "") for uid in UID_LITERAL.findall(code)
                )
                if UI_PATH.search(targets):
                    violations.append(f"{rel}:{number} L1 core references a UI path")
                if SCENE_TREE.search(code):
                    violations.append(f"{rel}:{number} L2 core uses the scene tree")
    content = root / "content"
    if content.is_dir():
        for script in sorted(content.rglob("*.gd")):
            violations.append(f"{script.relative_to(root).as_posix()} L3 content/ must hold data only")
    if include_refs:
        out = io.StringIO()
        with redirect_stdout(out):
            refs_code = godot_refs.main(["check", "--root", str(root)])
        if refs_code != 0:
            for line in out.getvalue().splitlines():
                if line.startswith("  "):
                    violations.append(f"{line.strip()} L4 use uid:// (or mark # path-ok: <why>)")
    return violations


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=".", help="project root (default: current directory)")
    parser.add_argument("--skip-refs", action="store_true", help="skip L4 (uid reference check)")
    args = parser.parse_args(argv)
    violations = check(Path(args.root).resolve(), include_refs=not args.skip_refs)
    if violations:
        for v in violations:
            print("layers: " + v)
        return 1
    print("layers: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
