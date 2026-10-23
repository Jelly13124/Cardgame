"""Unit tests for tools/godot_refs.py (run: python -m unittest discover -s tools/tests)."""

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import godot_refs  # noqa: E402


class ProjectFixture:
    """A tiny Godot-like project tree in a temp directory."""

    def __init__(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "project.godot").write_text("config_version=5\n", encoding="utf-8")
        self.script("a/x.gd", "extends Node\n", uid="uid://bxscript")
        self.scene("ui/m.tscn", uid="uid://cmenu")

    def close(self):
        self._tmp.cleanup()

    def script(self, rel, text, uid=None):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        if uid:
            Path(str(path) + ".uid").write_text(uid + "\n", encoding="utf-8")
        return path

    def scene(self, rel, uid=None):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        header = f'[gd_scene format=3 uid="{uid}"]' if uid else "[gd_scene format=3]"
        path.write_text(header + '\n\n[node name="Root" type="Node"]\n', encoding="utf-8")
        return path

    def run(self, *args):
        out = io.StringIO()
        with redirect_stdout(out):
            code = godot_refs.main(["--root", str(self.root), "--dirs", "a,b,ui", *args])
        return code, out.getvalue()


class GodotRefsTest(unittest.TestCase):
    def setUp(self):
        self.p = ProjectFixture()

    def tearDown(self):
        self.p.close()

    def convert(self, rel, text):
        path = self.p.script(rel, text)
        code, out = self.p.run("convert")
        return code, out, path.read_text(encoding="utf-8")

    def test_preload_rewritten_with_comment(self):
        code, _, text = self.convert("b/use.gd", 'const A = preload("res://a/x.gd")\n')
        self.assertEqual(code, 0)
        self.assertEqual(text, 'const A = preload("uid://bxscript")  # res://a/x.gd\n')

    def test_multiline_preload_rewritten(self):
        src = 'const A = preload(\n\t"res://a/x.gd"\n)\n'
        _, _, text = self.convert("b/use.gd", src)
        self.assertEqual(text, 'const A = preload(\n\t"uid://bxscript"  # res://a/x.gd\n)\n')

    def test_scene_const_and_change_to_rewritten(self):
        src = 'const P := "res://ui/m.tscn"\nfunc go():\n\tSceneTransition.change_to("res://ui/m.tscn")\n'
        _, _, text = self.convert("b/use.gd", src)
        self.assertIn('const P := "uid://cmenu"  # res://ui/m.tscn', text)
        self.assertIn('change_to("uid://cmenu")  # res://ui/m.tscn', text)

    def test_script_const_used_only_by_load_rewritten(self):
        src = (
            'const PANEL := "res://a/x.gd"\n'
            "func open():\n"
            "\tif ResourceLoader.exists(PANEL):\n"
            "\t\tload(PANEL)\n"
        )
        _, _, text = self.convert("b/use.gd", src)
        self.assertIn('const PANEL := "uid://bxscript"  # res://a/x.gd', text)

    def test_script_const_read_as_source_untouched(self):
        src = 'const SRC := "res://a/x.gd"\nfunc t():\n\tFileAccess.get_file_as_string(SRC)\n'
        _, _, text = self.convert("b/use.gd", src)
        self.assertEqual(text, src)

    def test_extends_comments_marked_and_concatenated_untouched(self):
        src = (
            'extends "res://a/x.gd"\n'
            "# see res://a/x.gd\n"
            '## `"res://a/x.gd"` in a doc comment\n'
            'var s := "res://a/x.gd"  # path-ok: compared with resource_path\n'
            'var d := "res://data/%s.json" % id\n'
            'var e := DIR + "x.gd"\n'
        )
        _, _, text = self.convert("b/use.gd", src)
        self.assertEqual(text, src)

    def test_literal_nested_in_single_quoted_string_untouched(self):
        src = "\tassert(source.contains('const P := \"res://ui/m.tscn\"'))\n"
        _, _, text = self.convert("b/use.gd", src)
        self.assertEqual(text, src)

    def test_missing_uid_reports_and_writes_nothing(self):
        self.p.script("a/no_uid.gd", "extends Node\n")
        src = 'const A = preload("res://a/no_uid.gd")\nconst B = preload("res://a/x.gd")\n'
        code, out, text = self.convert("b/use.gd", src)
        self.assertEqual(code, 1)
        self.assertIn("res://a/no_uid.gd", out)
        self.assertEqual(text, src)

    def test_idempotent(self):
        self.convert("b/use.gd", 'const A = preload("res://a/x.gd")\n')
        code, out = self.p.run("convert")
        self.assertEqual(code, 0)
        self.assertIn("rewritten 0 references", out)

    def test_sync_comments_refreshes_moved_paths(self):
        path = self.p.script(
            "b/use.gd",
            'const A = preload("uid://bxscript")  # res://old/place/x.gd\n'
            'const B = preload("uid://bxscript")  # res://a/x.gd\n',
        )
        code, out = self.p.run("sync-comments")
        self.assertEqual(code, 0)
        self.assertIn("updated 1 comments", out)
        self.assertEqual(
            path.read_text(encoding="utf-8"),
            'const A = preload("uid://bxscript")  # res://a/x.gd\n'
            'const B = preload("uid://bxscript")  # res://a/x.gd\n',
        )

    def test_check_lists_leftovers(self):
        self.p.script("b/use.gd", 'const SRC := "res://a/x.gd"\nfunc t():\n\tFileAccess.get_file_as_string(SRC)\n')
        code, out = self.p.run("check")
        self.assertEqual(code, 1)
        self.assertIn("b/use.gd:1", out)

    def test_check_ignores_extends_comments_and_marked_lines(self):
        self.p.script(
            "b/use.gd",
            'extends "res://a/x.gd"\n'
            "# res://a/x.gd\n"
            'const SRC := "res://a/x.gd"  # path-ok: source text\n',
        )
        code, out = self.p.run("check")
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main()
