"""Switch to Windows Decky backend.

Only a single UEFI variable (BootNext) is changed. BootOrder and all EFI files
remain untouched.
"""

import os
import re
import shutil
import subprocess

import decky


WINDOWS_PATH = r"\efi\microsoft\boot\bootmgfw.efi"
BOOT_ENTRY = re.compile(r"^Boot([0-9A-Fa-f]{4})(?:\*|\s)")


class Plugin:
    @staticmethod
    def _run(arguments):
        return subprocess.run(
            arguments,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
        )

    @staticmethod
    def _supported_platform():
        try:
            with open("/etc/os-release", encoding="utf-8") as stream:
                values = dict(
                    line.strip().split("=", 1)
                    for line in stream
                    if "=" in line and not line.lstrip().startswith("#")
                )
        except OSError:
            return False
        platform_id = values.get("ID", "").strip('"').lower()
        return platform_id in {"steamos", "chimeraos"}

    def _windows_boot_number(self):
        result = self._run(["efibootmgr", "-v"])
        if result.returncode != 0:
            raise RuntimeError("无法读取 UEFI 启动项。")

        candidates = []
        for line in result.stdout.splitlines():
            match = BOOT_ENTRY.match(line)
            if not match:
                continue
            lowered = line.lower()
            if "windows boot manager" not in lowered:
                continue
            candidates.append((match.group(1).upper(), WINDOWS_PATH in lowered))

        for number, is_official in candidates:
            if is_official:
                return number
        if candidates:
            return candidates[0][0]
        raise RuntimeError("未找到 Windows Boot Manager 启动项。")

    def _preflight(self):
        if not self._supported_platform():
            raise RuntimeError("此插件仅支持 SteamOS 或 ChimeraOS。")
        if os.geteuid() != 0:
            raise RuntimeError("Decky 未授予 root 后端权限。请重新安装插件后再试。")
        if shutil.which("efibootmgr") is None:
            raise RuntimeError("缺少 efibootmgr，无法设置单次启动项。")

    async def get_status(self):
        try:
            self._preflight()
            number = self._windows_boot_number()
            return {
                "available": True,
                "boot_number": number,
                "message": f"已找到 Windows Boot Manager（Boot{number}）。",
            }
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            return {"available": False, "message": str(error)}

    async def reboot_to_windows(self):
        self._preflight()
        number = self._windows_boot_number()
        setting = self._run(["efibootmgr", "--bootnext", number])
        if setting.returncode != 0:
            raise RuntimeError(setting.stderr.strip() or "设置 Windows 单次启动项失败。")

        decky.logger.info("Switch to Windows: BootNext set to Boot%s", number)
        reboot = self._run(["systemctl", "reboot"])
        if reboot.returncode != 0:
            # Do not leave an unexpected future Windows boot when reboot was refused.
            self._run(["efibootmgr", "--delete-bootnext"])
            detail = reboot.stderr.strip() or "系统未提供错误详情。"
            raise RuntimeError(f"重启失败；已清除刚设置的单次启动项。{detail}")
        return {
            "available": True,
            "boot_number": number,
            "message": "正在重启进入 Windows。",
        }
