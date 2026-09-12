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

    def test_accepts_official_loader_when_firmware_renames_label(self):
        self.plugin._run = lambda args: Result(stdout=(
            "Boot0007* MSI Windows HD(1)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n"
        ))
        self.assertEqual(self.plugin._windows_boot_number(), "0007")

    def test_accepts_microsoft_loader_without_the_boot_directory(self):
        self.plugin._run = lambda args: Result(stdout=(
            "Boot0008* Windows HD(1)/File(\\EFI\\Microsoft\\bootmgfw.efi)\n"
        ))
        self.assertEqual(self.plugin._windows_boot_number(), "0008")

    def test_does_not_select_a_custom_file_just_because_it_has_a_windows_label(self):
        self.plugin._run = lambda args: Result(stdout=(
            "Boot0008* Windows HD(1)/File(\\EFI\\Custom\\clover.efi)\n"
        ))
        with self.assertRaises(MODULE._backend.WindowsBootEntryMissing):
            self.plugin._windows_boot_number()

    def test_system_commands_restore_the_original_library_path(self):
        with patch.dict(
            MODULE._backend.os.environ,
            {
                "LD_LIBRARY_PATH": "/tmp/_MEI123",
                "LD_LIBRARY_PATH_ORIG": "/usr/lib",
                "LD_PRELOAD": "/tmp/_MEI123/preload.so",
            },
            clear=True,
        ), patch.object(MODULE._backend.subprocess, "run", return_value=Result()) as run:
            self.plugin._run(["systemctl", "reboot"])

        environment = run.call_args.kwargs["env"]
        self.assertEqual(environment["LD_LIBRARY_PATH"], "/usr/lib")
        self.assertNotIn("LD_LIBRARY_PATH_ORIG", environment)
        self.assertNotIn("LD_PRELOAD", environment)

    def test_status_offers_repair_without_writing_nvram(self):
        with patch.object(self.plugin, "_preflight"), \
             patch.object(
                 self.plugin,
                 "_windows_boot_number",
                 side_effect=MODULE._backend.WindowsBootEntryMissing("missing"),
             ), \
             patch.object(
                 self.plugin,
                 "_windows_loader_target",
                 return_value=("/dev/nvme0n1", "1"),
             ):
            result = asyncio.run(self.plugin.get_status())

        self.assertTrue(result["available"])
        self.assertTrue(result["repairable"])
        self.assertIn("自动补回", result["message"])

    def test_loader_target_requires_a_real_efi_system_partition(self):
        calls = []

        def fake_run(args):
            calls.append(args)
            if args[:2] == ["findmnt", "-rn"]:
                return Result(stdout="/dev/nvme0n1p1\n")
            if args[:3] == ["lsblk", "-nro", "PKNAME"]:
                return Result(stdout="nvme0n1\n")
            if args[:3] == ["lsblk", "-nro", "PARTN"]:
                return Result(stdout="1\n")
            if args[:3] == ["lsblk", "-nro", "PARTTYPE"]:
                return Result(stdout=f"{MODULE._backend.EFI_SYSTEM_PARTITION_GUID}\n")
            if args[:3] == ["lsblk", "-nro", "FSTYPE"]:
                return Result(stdout="vfat\n")
            return Result(code=1)

        self.plugin._run = fake_run
        with patch.object(self.plugin, "_platform_id", return_value="steamos"), \
             patch.object(
                 MODULE.shutil,
                 "which",
                 side_effect=lambda command: None if command == "bootctl" else f"/usr/bin/{command}",
             ), \
             patch.object(
                 MODULE.os.path,
                 "isfile",
                 side_effect=lambda path: path == "/efi/EFI/Microsoft/Boot/bootmgfw.efi",
             ):
            target = self.plugin._windows_loader_target()

        self.assertEqual(target, ("/dev/nvme0n1", "1"))
        self.assertIn(["lsblk", "-nro", "PARTTYPE", "/dev/nvme0n1p1"], calls)
        self.assertIn(["lsblk", "-nro", "FSTYPE", "/dev/nvme0n1p1"], calls)

    def test_missing_entry_is_recreated_and_old_order_is_preserved(self):
        calls = []
        created = False

        def fake_run(args):
            nonlocal created
            calls.append(args)
            if args == ["efibootmgr", "-v"]:
                if created:
                    return Result(stdout=(
                        "Boot0000* Clover - GUI Boot Manager HD/File(\\EFI\\clover\\cloverx64.efi)\n"
                        "Boot0001* SteamOS HD/File(\\efi\\steamos\\steamcl.efi)\n"
                        "Boot0002* Windows Boot Manager HD/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n"
                    ))
                return Result(stdout=(
                    "Boot0000* Clover - GUI Boot Manager HD/File(\\EFI\\clover\\cloverx64.efi)\n"
                    "Boot0001* SteamOS HD/File(\\efi\\steamos\\steamcl.efi)\n"
                ))
            if args == ["efibootmgr"]:
                return Result(stdout="BootOrder: 0000,0001\n")
            if args[:2] == ["efibootmgr", "--create"]:
                created = True
            return Result()

        self.plugin._run = fake_run
        with patch.object(self.plugin, "_preflight"), \
             patch.object(
                 self.plugin,
                 "_windows_loader_target",
                 return_value=("/dev/nvme0n1", "1"),
             ):
            result = asyncio.run(self.plugin.reboot_to_windows())

        self.assertEqual(result["boot_number"], "0002")
        self.assertIn(
            ["efibootmgr", "--bootorder", "0000,0001,0002"],
            calls,
        )
        self.assertEqual(calls[-2:], [
            ["efibootmgr", "--bootnext", "0002"],
            ["systemctl", "reboot"],
        ])

    def test_failed_order_restore_removes_created_entry(self):
        calls = []
        created = False

        def fake_run(args):
            nonlocal created
            calls.append(args)
            if args == ["efibootmgr"]:
                return Result(stdout="BootOrder: 0000,0001\n")
            if args[:2] == ["efibootmgr", "--create"]:
                created = True
                return Result()
            if args == ["efibootmgr", "-v"] and created:
                return Result(stdout=(
                    "Boot0002* Windows Boot Manager HD/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n"
                ))
            if args == ["efibootmgr", "--bootorder", "0000,0001,0002"]:
                return Result(code=1, stderr="write refused")
            return Result()

        self.plugin._run = fake_run
        with patch.object(
            self.plugin,
            "_windows_loader_target",
            return_value=("/dev/nvme0n1", "1"),
        ):
            with self.assertRaisesRegex(RuntimeError, "已尝试撤销"):
                self.plugin._create_windows_boot_entry()

        self.assertIn(
            ["efibootmgr", "--delete-bootnum", "--bootnum", "0002"],
            calls,
        )
        self.assertEqual(calls[-1], ["efibootmgr", "--bootorder", "0000,0001"])

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
            result = asyncio.run(self.plugin.reboot_to_windows())

        self.assertFalse(result["available"])
        self.assertIn("已清除", result["message"])
        self.assertEqual(calls[-1], ["efibootmgr", "--delete-bootnext"])


if __name__ == "__main__":
    unittest.main()
