"""Switch to Windows Decky backend.

Normally only the UEFI BootNext variable is changed. If firmware removed the
Windows entry, the plugin can recreate that NVRAM entry from the existing
Microsoft loader and then restore the previous BootOrder. EFI files remain
untouched.
"""

import os
import re
import shutil
import subprocess

import decky


WINDOWS_PATH = r"\efi\microsoft\boot\bootmgfw.efi"
WINDOWS_LOADER_NAME = "bootmgfw.efi"
BOOT_ENTRY = re.compile(r"^Boot([0-9A-Fa-f]{4})(?:\*|\s)")
BOOT_NUMBER = re.compile(r"^[0-9A-Fa-f]{4}$")
EFI_SYSTEM_PARTITION_GUID = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"


class WindowsBootEntryMissing(RuntimeError):
    pass


class Plugin:
    @staticmethod
    def _system_command_environment():
        """Avoid leaking PyInstaller's bundled libraries into system tools."""
        environment = os.environ.copy()
        original_library_path = environment.pop("LD_LIBRARY_PATH_ORIG", None)
        if original_library_path is None:
            environment.pop("LD_LIBRARY_PATH", None)
        else:
            environment["LD_LIBRARY_PATH"] = original_library_path
        environment.pop("LD_PRELOAD", None)
        return environment

    @staticmethod
    def _run(arguments):
        return subprocess.run(
            arguments,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            env=Plugin._system_command_environment(),
        )

    @staticmethod
    def _platform_id():
        try:
            with open("/etc/os-release", encoding="utf-8") as stream:
                values = dict(
                    line.strip().split("=", 1)
                    for line in stream
                    if "=" in line and not line.lstrip().startswith("#")
                )
        except OSError:
            return ""
        return values.get("ID", "").strip('"').lower()

    @classmethod
    def _supported_platform(cls):
        return cls._platform_id() in {"steamos", "chimeraos"}

    def _windows_boot_number(self):
        result = self._run(["efibootmgr", "-v"])
        if result.returncode != 0:
            raise RuntimeError("无法读取 UEFI 启动项。")

        labeled_candidates = []
        loader_candidates = []
        for line in result.stdout.splitlines():
            match = BOOT_ENTRY.match(line)
            if not match:
                continue
            lowered = line.lower()
            number = match.group(1).upper()
            normalized = lowered.replace("/", "\\")
            has_loader_name = re.search(
                r"\\bootmgfw[.]efi(?:[)]|\\s|$)", normalized
            ) is not None
            has_microsoft_efi_path = "\\efi\\microsoft\\" in normalized
            has_official_loader = WINDOWS_PATH in normalized
            has_windows_label = "windows" in lowered
            has_microsoft_label = "microsoft" in lowered
            has_file_path = "file(" in lowered
            # Some firmware keeps the Microsoft loader path but drops or
            # renames the human-readable NVRAM label. The path is the safer
            # identity check, while the label remains a compatibility fallback
            # for firmware that omits the File(...) path in -v output.
            if has_official_loader or (has_loader_name and has_microsoft_efi_path):
                loader_candidates.append(number)
            elif has_windows_label or has_microsoft_label:
                if not has_file_path:
                    labeled_candidates.append(number)

        if loader_candidates:
            return loader_candidates[0]
        if labeled_candidates:
            return labeled_candidates[0]
        raise WindowsBootEntryMissing("未找到 Windows Boot Manager 启动项。")

    def _boot_order(self):
        result = self._run(["efibootmgr"])
        if result.returncode != 0:
            raise RuntimeError("无法读取当前 BootOrder，未自动修复 Windows 启动项。")
        for line in result.stdout.splitlines():
            if not line.startswith("BootOrder:"):
                continue
            order = [item.strip().upper() for item in line.partition(":")[2].split(",")]
            if order and all(BOOT_NUMBER.fullmatch(item) for item in order):
                return order
        raise RuntimeError("当前 BootOrder 格式异常，未自动修复 Windows 启动项。")

    def _windows_loader_target(self):
        if self._platform_id() != "steamos":
            raise RuntimeError("当前系统不会自动重建 Windows 启动项。")
        for command in ("findmnt", "lsblk"):
            if shutil.which(command) is None:
                raise RuntimeError(f"缺少 {command}，无法安全定位 Windows EFI 分区。")

        candidates = []
        if shutil.which("bootctl") is not None:
            for option in ("--print-esp-path", "--print-boot-path"):
                result = self._run(["bootctl", option])
                if result.returncode == 0 and result.stdout.strip():
                    candidates.append(result.stdout.strip().splitlines()[0])
        candidates.extend(("/efi", "/boot/efi", "/esp", "/boot"))

        visited = set()
        for mountpoint in candidates:
            mountpoint = os.path.abspath(mountpoint)
            if mountpoint in visited:
                continue
            visited.add(mountpoint)
            loader = os.path.join(
                mountpoint, "EFI", "Microsoft", "Boot", "bootmgfw.efi"
            )
            if not os.path.isfile(loader):
                continue

            source = self._run(["findmnt", "-rn", "-T", mountpoint, "-o", "SOURCE"])
            if source.returncode != 0:
                continue
            device = source.stdout.strip().splitlines()[0] if source.stdout.strip() else ""
            if not re.fullmatch(r"/dev/[A-Za-z0-9._-]+", device):
                continue

            parent = self._run(["lsblk", "-nro", "PKNAME", device])
            partition = self._run(["lsblk", "-nro", "PARTN", device])
            part_type = self._run(["lsblk", "-nro", "PARTTYPE", device])
            filesystem = self._run(["lsblk", "-nro", "FSTYPE", device])
            if any(
                result.returncode != 0
                for result in (parent, partition, part_type, filesystem)
            ):
                continue
            disk_name = parent.stdout.strip().splitlines()[0] if parent.stdout.strip() else ""
            part_number = (
                partition.stdout.strip().splitlines()[0]
                if partition.stdout.strip()
                else ""
            )
            if not re.fullmatch(r"[A-Za-z0-9._-]+", disk_name):
                continue
            if not part_number.isdigit() or int(part_number) < 1:
                continue
            if part_type.stdout.strip().lower() != EFI_SYSTEM_PARTITION_GUID:
                continue
            if filesystem.stdout.strip().lower() not in {"vfat", "fat", "fat16", "fat32"}:
                continue
            return f"/dev/{disk_name}", part_number

        raise RuntimeError(
            "Windows 启动项已丢失，且未在已挂载的 EFI 分区找到 bootmgfw.efi。"
        )

    def _create_windows_boot_entry(self):
        old_order = self._boot_order()
        disk, partition = self._windows_loader_target()
        create = self._run([
            "efibootmgr",
            "--create",
            "--disk",
            disk,
            "--part",
            partition,
            "--label",
            "Windows Boot Manager",
            "--loader",
            r"\EFI\Microsoft\Boot\bootmgfw.efi",
        ])
        if create.returncode != 0:
            detail = create.stderr.strip() or "固件没有提供错误详情。"
            raise RuntimeError(f"自动恢复 Windows 启动项失败：{detail}")

        try:
            number = self._windows_boot_number()
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            self._run(["efibootmgr", "--bootorder", ",".join(old_order)])
            raise RuntimeError(
                f"启动项已尝试创建，但无法验证；已恢复原 BootOrder。{error}"
            ) from error

        restored_order = old_order.copy()
        if number not in restored_order:
            restored_order.append(number)
        restore = self._run(["efibootmgr", "--bootorder", ",".join(restored_order)])
        if restore.returncode != 0:
            self._run(["efibootmgr", "--delete-bootnum", "--bootnum", number])
            self._run(["efibootmgr", "--bootorder", ",".join(old_order)])
            detail = restore.stderr.strip() or "固件没有提供错误详情。"
            raise RuntimeError(
                f"无法恢复原启动顺序，已尝试撤销新启动项：{detail}"
            )

        decky.logger.info(
            "Switch to Windows: recreated Boot%s on %s partition %s",
            number,
            disk,
            partition,
        )
        return number

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
            try:
                number = self._windows_boot_number()
            except WindowsBootEntryMissing:
                self._windows_loader_target()
                return {
                    "available": True,
                    "repairable": True,
                    "message": "Windows 启动项已丢失；点击后将自动补回并重启。",
                }
            return {
                "available": True,
                "boot_number": number,
                "message": f"已找到 Windows Boot Manager（Boot{number}）。",
            }
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            return {"available": False, "message": str(error)}

    async def reboot_to_windows(self):
        try:
            self._preflight()
            try:
                number = self._windows_boot_number()
            except WindowsBootEntryMissing:
                number = self._create_windows_boot_entry()
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
        except (OSError, subprocess.SubprocessError, RuntimeError) as error:
            return {"available": False, "message": str(error)}
