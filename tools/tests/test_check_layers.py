"""Unit tests for tools/check_layers.py (run: python -m unittest discover -s tools/tests)."""

import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import check_layers  # noqa: E402


class CheckLayersTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        (self.root / "project.godot").write_text("config_version=5\n", encoding="utf-8")
        self.write("core/save/save_io.gd", "extends RefCounted\nstatic var root := \"user://\"\n")

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, rel, text):
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def run_check(self):
        out = io.StringIO()
        with redirect_stdout(out):
            code = check_layers.main(["--root", str(self.root), "--skip-refs"])
        return code, out.getvalue()

    def test_clean_tree_ok(self):
        code, out = self.run_check()
        self.assertEqual(code, 0, out)
        self.assertIn("layers: ok", out)

    def test_core_ui_reference_flagged(self):
        self.write("core/run/rewards.gd", 'const V = preload("res://run_system/ui/loot_reward.gd")\n')
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("core/run/rewards.gd:1 L1", out)

    def test_core_scene_tree_flagged(self):
        self.write("core/combat/turns.gd", "func f():\n\tget_tree().current_scene.queue_free()\n")
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("core/combat/turns.gd:2 L2", out)

    def test_content_script_flagged(self):
        self.write("content/cards/strike.json", "{}\n")
        self.write("content/cards/strike_logic.gd", "extends RefCounted\n")
        code, out = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("content/cards/strike_logic.gd L3", out)

    def test_comments_are_ignored(self):
        self.write("core/save/notes.gd", "# never call get_tree() here; see res://run_system/ui/x.gd\n")
        code, out = self.run_check()
        self.assertEqual(code, 0, out)


if __name__ == "__main__":
    unittest.main()
