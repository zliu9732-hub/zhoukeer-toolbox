# Switch to Windows

Decky Loader 插件。点击按钮后设置 UEFI `BootNext` 为 Windows Boot Manager，并立即重启。若 SteamOS 中的 Windows NVRAM 启动项被固件删除，但官方 `EFI/Microsoft/Boot/bootmgfw.efi` 仍在，插件会自动补回启动项并恢复原 `BootOrder`，不会修改默认启动系统或任何 EFI 文件。请先保存所有工作。

制作人：RenAmamiya。

支持 SteamOS 与 ChimeraOS，要求系统已有 `efibootmgr` 及 Decky 的 root 后端权限。Windows 启动项自动恢复仅在 SteamOS 启用，并且必须确认官方启动文件位于已挂载的 FAT 格式 GPT EFI System Partition；ChimeraOS 仍要求系统已有 Windows Boot Manager 启动项。若系统拒绝重启，插件会尝试清除刚写入的 `BootNext`。

## 1.1.0

- 新增“仅修复 Windows 引导”：当 Clover 等启动管理器隐藏 Windows 项时，可单独补建 `Windows Boot Manager`，不重启、不改变原先默认启动项。
- 修复时会校验已挂载 EFI System Partition 的磁盘、分区号、分区类型与 FAT 文件系统；不会硬编码 `/dev/nvme0n1p1`。

## 1.0.3

- 修复 PyInstaller 打包环境影响 `systemctl`：调用系统命令时不再加载临时目录中的 OpenSSL 库，避免 `OPENSSL_3.4.0 not found` 导致重启失败。
- 放宽 Windows Boot Manager 的识别，兼容省略中间 `Boot` 目录、使用 `/` 分隔符或标签不同的标准 Microsoft 引导项。
- 预期的后端失败会返回可读原因，不再只显示笼统的 Python Exception。

## 打包与安装

运行 `pnpm run build` 后，将 `switch-to-windows/` 目录作为 ZIP 唯一顶层目录压缩。可通过 Decky 的“从 ZIP 安装”加载。插件商城发布时使用同一 ZIP；官方构建使用 `backend/src` 中的后端源码。
