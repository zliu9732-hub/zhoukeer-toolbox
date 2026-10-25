#!/usr/bin/env python3
"""Offline package, translation, UI and backend regression checks."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import localize_screen_colors as module
from framegen_package import extract_verified


class ScreenColorsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.fixture = ROOT / "tests/fixtures/screen-colors-v1.0.0.zip"

    def test_actual_archive_prepares_complete_chinese_package(self):
        output = self.root / "plugin"
        module.prepare(self.fixture, output)
        module.verify(output)
        metadata = module.metadata(True)
        self.assertEqual(json.loads((output / "plugin.json").read_text())["name"], "屏幕色彩（Screen Colors）")
        self.assertEqual(json.loads((output / "plugin.json").read_text())["author"], "PacificSilent")
        self.assertEqual(json.loads((output / "plugin.json").read_text())["flags"], ["root"])
        for relative in ("main.py", "LICENSE", "CREDITS.md"):
            self.assertEqual(metadata["files"][relative], module.metadata()["files"][relative])
        self.assertTrue((output / "src/index.tsx").is_file())
        self.assertTrue((output / "pnpm-lock.yaml").is_file())

    def test_frontend_actual_ui_states_and_ast(self):
        original = self.root / "original"
        extract_verified(self.fixture, original, module.metadata())
        output = self.root / "plugin"
        module.prepare(self.fixture, output)
        node = shutil.which("node")
        self.assertIsNotNone(node, "Node.js is required for the complete frontend audit")
        subprocess.run([node, str(ROOT / "scripts/verify_screen_colors_ui.mjs"), str(original / "dist/index.js"), str(output / "dist/index.js")], check=True)

    def test_partial_chinese_or_modified_backend_cannot_pass(self):
        output = self.root / "plugin"
        module.prepare(self.fixture, output)
        index = output / "dist/index.js"
        content = index.read_text()
        index.write_text(content.replace("红色强度", "Red gain"))
        with self.assertRaises(ValueError):
            module.verify(output)
        index.write_text(content)
        (output / "main.py").write_text("modified backend")
        with self.assertRaises(ValueError):
            module.verify(output)

    def test_unknown_upstream_and_symlink_installation_rejected(self):
        with self.assertRaises(ValueError):
            module.build_frontend(b"new upstream UI")
        output = self.root / "plugin"
        output.symlink_to(self.root / "other")
        with self.assertRaises(ValueError):
            module.prepare(self.fixture, output)

    def test_menu_routing_uses_localized_installer_in_both_interfaces(self):
        for file in ("main.sh", "core/gui.sh"):
            source = (ROOT / file).read_text()
            self.assertIn('"$PROJECT_ROOT/modules/plugin_store.sh" screen-colors', source)
            self.assertIn("屏幕色彩", source)
        source = (ROOT / "modules/plugin_store.sh").read_text()
        self.assertIn('source "$PROJECT_ROOT/modules/screen_colors.sh"', source)
        self.assertIn("ensure_screen_colors_chinese_current", source)


if __name__ == "__main__":
    unittest.main()
