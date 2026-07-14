# 周克儿工具箱 V4

周克儿工具箱是面向 Steam Deck / SteamOS 的 Bash 工具箱，提供一键新机初始化、常用软件、远程协助、插件商城、系统维护和安全更新入口。

## 功能

- 一键新机初始化：一次确认后依次检查SteamOS和网络，并自动执行当前清单中的新机常用项目。
- 插件商城：下载并校验Decky官方安装器后启动安装。
- 微信、QQ：优先通过中科大Flathub缓存进行用户级安装，失败后切换官方源；安装成功后自动创建桌面快捷方式，不修改SteamOS只读分区。
- ToDesk：使用固定的第三方SteamOS适配包并校验SHA256，安装完成后恢复只读保护。
- RustDesk 远程工具：支持限时重试下载、SHA256 校验、保留旧版本和自建服务器配置指引。
- Steam Deck 优化：清理 Steam 下载缓存、着色器缓存，并提供性能模式提示。
- 网络检测：检测基础网络连通性。
- 安全清理：清理前必须确认，避免误删。
- 一键修复模式：执行网络检测、Steam 下载缓存清理建议和 DNS 处理提示。
- 更新工具箱：优先从Gitee获取固定更新包和SHA256，失败后切换GitHub；缺少有效校验时拒绝执行。

## 主菜单

```text
A. 新机初始化    第一次使用推荐
B. 常用软件      微信 / QQ / ProtonUp-Qt
C. 远程协助      ToDesk / RustDesk
D. 插件商城      Decky Loader
E. 系统设置      系统信息 / 网络检测
F. 系统优化      Steam Deck优化 / 清理 / 一键修复
G. 工具箱更新    安全检查并更新工具箱
X. 退出
```

Steam Deck桌面快捷方式会打开约 `1000×650` 的双栏Konsole界面，左侧分类、右侧功能和确认按钮均可直接使用触屏或触控板点击，不需要输入数字。只有管理员密码仍需在终端中输入。

需要关闭鼠标事件、主动使用纯键盘终端界面时可运行：

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/main.sh" --text
```

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

桌面快捷方式会使用项目中的 `assets/icon.png`。

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
RUSTDESK_DOWNLOAD_FALLBACK=""
RUSTDESK_SHA256=""
RUSTDESK_ID_SERVER=""
RUSTDESK_RELAY_SERVER=""
RUSTDESK_API=""
RUSTDESK_KEY=""
RUSTDESK_CONFIG_STRING=""
```

`RUSTDESK_KEY` 是可分发给客户端的服务器公钥，不是服务器私钥。禁止在配置中加入服务器私钥、远程密码、API账号、登录Token或其他登录凭据。

RustDesk 1.4.8优先从用户提供的123云盘直链下载，失败后切换官方GitHub；两个来源都必须通过官方SHA256校验。`RUSTDESK_CONFIG_STRING` 只能填写 RustDesk 客户端“导出服务器配置”生成的字符串。工具不会根据服务器字段猜测该字符串，也不会直接修改 `RustDesk2.toml`；无法安全自动导入时会显示手动配置说明。

## ToDesk说明

用户提供的 `curl -L todesk.lanbai.top | sh` 会继续下载可变脚本、关闭SteamOS只读保护并使用pacman安装第三方软件包。本工具不会直接执行这条管道命令，而是固定已审查的 `mclanbai/archtodesk` 提交和ToDesk 4.7.2.0软件包SHA256。安装前会明确提示风险并要求管理员验证，完成后尝试恢复只读保护。

ToDesk并非SteamOS原生软件，SteamOS系统更新可能移除通过pacman安装的内容。工具不会删除已有ToDesk用户配置，也不会使用 `chmod 777`。

## 更新

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/update.sh"
```

更新脚本会下载发布包，完成 SHA256 校验后调用安装器。安装器先在同级暂存目录准备完整新版本，再切换安装目录；准备或切换失败时保留、恢复旧版本。安装器会保留已有非空配置；当指定的 RustDesk 配置项缺失、为空或仍是旧版默认下载源时，先备份原配置，再从 `settings.example.conf` 补充新默认值。

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
ZHOUKEER_GITEE_PACKAGE_URL="https://example.com/zhoukeer-toolbox.tar.gz" \
ZHOUKEER_GITEE_CHECKSUM_URL="https://example.com/SHA256SUMS" \
ZHOUKEER_SHA256="发布包sha256" \
bash bootstrap.sh
```

默认下载顺序：

1. Gitee项目内固定包：`dist/zhoukeer-toolbox.tar.gz`
2. GitHub项目内相同固定包：`dist/zhoukeer-toolbox.tar.gz`

安装包必须与同一来源的 `dist/SHA256SUMS` 匹配，否则安装或更新会停止。

## 需要在真实 Steam Deck 上测试

- 桌面快捷方式是否能通过 Konsole 打开工具箱。
- SteamOS 是否能正确识别。
- Steam 下载缓存和着色器缓存路径是否符合当前 SteamOS 版本。
- RustDesk AppImage 是否能下载、赋权和启动。
- ToDesk安装后是否恢复SteamOS只读保护、服务是否启动、桌面入口是否存在。
- Decky、微信、QQ和ProtonUp-Qt在当前SteamOS版本是否能正常安装和启动。
- 更新菜单能否从Gitee下载并验证固定更新包，Gitee失败时能否切换GitHub。
- 游戏模式/桌面模式之间的菜单显示和中文字体是否正常。
