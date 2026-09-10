import asyncio
import importlib.util
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch


DECKY = types.SimpleNamespace(logger=types.SimpleNamespace(info=lambda *args: None))
sys.modules.setdefault("decky", DECKY)
MODULE_PATH = Path(__file__).resolve().parents[1] / "main.py"
SPEC = importlib.util.spec_from_file_location("switch_to_windows_main", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class Result:
    def __init__(self, code=0, stdout="", stderr=""):
        self.returncode = code
        self.stdout = stdout
        self.stderr = stderr


class SwitchToWindowsTests(unittest.TestCase):
    def setUp(self):
        self.plugin = MODULE.Plugin()

    def test_prefers_official_windows_loader(self):
        self.plugin._run = lambda args: Result(stdout=(
            "Boot0003* Windows Boot Manager HD(1)/File(\\EFI\\Custom\\clover.efi)\n"
            "Boot0007* Windows Boot Manager HD(1)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n"
        ))
        self.assertEqual(self.plugin._windows_boot_number(), "0007")

    def test_reboot_writes_only_bootnext_then_reboots(self):
        calls = []

        def fake_run(args):
            calls.append(args)
            if args == ["efibootmgr", "-v"]:
                return Result(stdout="Boot0001* Windows Boot Manager HD/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n")
            return Result()

        self.plugin._run = fake_run
        with patch.object(self.plugin, "_supported_platform", return_value=True), \
             patch.object(MODULE.os, "geteuid", return_value=0), \
             patch.object(MODULE.shutil, "which", return_value="/usr/bin/efibootmgr"):
            result = asyncio.run(self.plugin.reboot_to_windows())

        self.assertEqual(result["boot_number"], "0001")
        self.assertEqual(calls, [
            ["efibootmgr", "-v"],
            ["efibootmgr", "--bootnext", "0001"],
            ["systemctl", "reboot"],
        ])

    def test_failed_reboot_clears_new_bootnext(self):
        calls = []

        def fake_run(args):
            calls.append(args)
            if args == ["efibootmgr", "-v"]:
                return Result(stdout="Boot0001* Windows Boot Manager HD/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n")
            if args == ["systemctl", "reboot"]:
                return Result(code=1, stderr="reboot refused")
            return Result()

        self.plugin._run = fake_run
        with patch.object(self.plugin, "_supported_platform", return_value=True), \
             patch.object(MODULE.os, "geteuid", return_value=0), \
             patch.object(MODULE.shutil, "which", return_value="/usr/bin/efibootmgr"):
            with self.assertRaisesRegex(RuntimeError, "已清除"):
                asyncio.run(self.plugin.reboot_to_windows())

        self.assertEqual(calls[-1], ["efibootmgr", "--delete-bootnext"])


if __name__ == "__main__":
    unittest.main()
