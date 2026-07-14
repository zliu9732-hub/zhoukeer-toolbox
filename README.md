# 周克儿工具箱 V4

周克儿工具箱是面向 Steam Deck / SteamOS 的 Bash 工具箱，提供设备检测、RustDesk 远程工具、Steam Deck 优化、网络检测、安全清理和一键修复入口。

## 功能

- 设备检测：显示系统、发行版和 SteamOS 环境识别结果。
- RustDesk 远程工具：支持限时重试下载、SHA256 校验、保留旧版本和自建服务器配置指引。
- Steam Deck 优化：清理 Steam 下载缓存、着色器缓存，并提供性能模式提示。
- 网络检测：检测基础网络连通性。
- 安全清理：清理前必须确认，避免误删。
- 一键修复模式：执行网络检测、Steam 下载缓存清理建议和 DNS 处理提示。

## 一行命令安装

在 Steam Deck 桌面模式打开 Konsole，优先使用 Gitee 国内源：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/bootstrap.sh | bash
```

GitHub 备用源：

```bash
curl -fsSL https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/bootstrap.sh | bash
```

未来绑定域名后，目标形式是：

```bash
curl -fsSL https://我的域名/i | bash
```

默认安装目录：

```bash
${HOME}/.local/share/zhoukeer-toolbox
```

安装前预演，不修改文件：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/bootstrap.sh | bash -s -- --dry-run
```

安装完成后会创建：

- 桌面快捷方式：`~/Desktop/周克儿工具箱.desktop`
- 应用菜单入口：`~/.local/share/applications/zhoukeer-toolbox.desktop`

如果桌面快捷方式提示不受信任，请右键选择允许启动。

## 运行

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/main.sh"
```

## 配置 RustDesk

首次使用前编辑：

```bash
${HOME}/.local/share/zhoukeer-toolbox/config/settings.conf
```

可配置项：

```bash
RUSTDESK_DOWNLOAD=""
RUSTDESK_SHA256=""
RUSTDESK_ID_SERVER=""
RUSTDESK_RELAY_SERVER=""
RUSTDESK_API=""
RUSTDESK_KEY=""
RUSTDESK_CONFIG_STRING=""
```

`RUSTDESK_KEY` 是可分发给客户端的服务器公钥，不是服务器私钥。禁止在配置中加入服务器私钥、远程密码、API账号、登录Token或其他登录凭据。

`RUSTDESK_CONFIG_STRING` 只能填写 RustDesk 客户端“导出服务器配置”生成的字符串。工具不会根据服务器字段猜测该字符串，也不会直接修改 `RustDesk2.toml`。该项留空、当前 AppImage 不支持普通用户执行 `--config` 或导入失败时，工具会显示手动配置说明。RustDesk 1.4.6 虽然包含 `--config` 命令入口，但要求已安装并使用管理员权限；工具不会为此调用 `sudo`，便携 AppImage 会回退到手动配置。

## 更新

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/update.sh"
```

更新脚本会下载发布包，完成 SHA256 校验后调用安装器覆盖程序文件。安装器会保留已有非空配置；当指定的 RustDesk 配置项缺失或为空时，先备份原配置，再从 `settings.example.conf` 补充默认值。

预演更新：

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/update.sh" --dry-run
```

## 卸载

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/uninstall.sh"
```

卸载脚本会先确认，删除前可选择保留用户配置和日志。

预演卸载：

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/uninstall.sh" --dry-run
```

## 发布 GitHub Release

建议发布流程：

1. 确认 `bash -n` 检查通过。
2. 确认 `config/settings.conf` 不包含私人配置。
3. 执行 `bash scripts/package_release.sh` 生成发布包、`.sha256` 和 `SHA256SUMS` 校验文件。
4. 提交代码并打 tag，例如 `v4.0.0`。
5. 在 GitHub Release 中上传发布包和 `.sha256` 校验文件。
6. 在 Release 中写明安装、更新、卸载命令。
7. 不要在 Release 包中包含私有 RustDesk Key、Token、邮箱或个人路径。

`bootstrap.sh` 和 `update.sh` 支持通过环境变量指定正式发布包：

```bash
ZHOUKEER_PACKAGE_URL="https://example.com/zhoukeer-toolbox-v4.0.0.tar.gz" \
ZHOUKEER_SHA256="发布包sha256" \
bash bootstrap.sh
```

默认下载顺序：

1. Gitee 项目包：`https://gitee.com/zliu9732-hub/zhoukeer-toolbox/repository/archive/main.tar.gz`
2. GitHub 备用包：`https://github.com/zliu9732-hub/zhoukeer-toolbox/archive/refs/heads/main.tar.gz`

## 需要在真实 Steam Deck 上测试

- 桌面快捷方式是否能通过 Konsole 打开工具箱。
- SteamOS 是否能正确识别。
- Steam 下载缓存和着色器缓存路径是否符合当前 SteamOS 版本。
- RustDesk AppImage 是否能下载、赋权和启动。
- 游戏模式/桌面模式之间的菜单显示和中文字体是否正常。
