# Switch to Windows

Decky Loader 插件。点击按钮后仅设置 UEFI `BootNext` 为 Windows Boot Manager，并立即重启；它不会修改 `BootOrder`、默认启动系统或任何 EFI 文件。请先保存所有工作。

制作人：RenAmamiya。

支持 SteamOS 与 ChimeraOS，要求系统已有 `efibootmgr`、Windows Boot Manager 启动项及 Decky 的 root 后端权限。若系统拒绝重启，插件会尝试清除刚写入的 `BootNext`。

## 打包与安装

运行 `pnpm run build` 后，将 `switch-to-windows/` 目录作为 ZIP 唯一顶层目录压缩。可通过 Decky 的“从 ZIP 安装”加载。插件商城发布时使用同一 ZIP；官方构建使用 `backend/src` 中的后端源码。
