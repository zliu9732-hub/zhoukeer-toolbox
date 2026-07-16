# 周克儿工具箱 V4

周克儿工具箱是面向 Steam Deck 及其他 SteamOS 掌机的 Bash 工具箱，提供一键新机初始化、常用软件、远程协助、插件商城、系统维护和安全更新入口。界面会按终端宽度收紧导航栏；体检、诊断、攻略和启动器功能尽量适配 SteamOS 掌机，涉及引导、只读分区等系统功能仍会先检查环境。

- 双系统设置：可挂载唯一的未挂载 NTFS/exFAT 互通盘，并可改为只读模式防止 SteamOS 下误写入；可启用既有 systemd-boot 启动菜单，或将菜单等待时间设为 0 秒隐藏菜单，不会删除任何系统或 EFI 启动项。

远程协助中提供 RustDesk 和 ToDesk。RustDesk 使用作者提供的123云盘国内直链安装独立 AppImage 并自动创建桌面图标，不会修改 SteamOS 只读系统分区，也不会被工具箱自动写入任何服务器配置。

## 使用说明与免责声明

本脚本由“闲鱼：超级妹宝双叶”制作，支持所有人免费使用。禁止商业使用、销售、转卖，或以本工具箱直接或间接盈利。工具箱内收录的下载内容均为官方免费发布或开源内容，不包含付费软件本体、破解内容或商业授权；第三方软件和插件仍以各自许可证及使用条款为准。部分国内下载分流由作者本人的123云盘提供；喜欢本工具，欢迎来闲鱼支持作者。若有侵权，请及时联系作者删除。启动工具箱后须点击“知悉并开始使用”方可进入首页。

## 功能

- 一键新机初始化：一次确认后依次检查SteamOS和网络，并自动执行当前清单中的新机常用项目。
- 插件商城：当前完整清单共28款，包括小黄鸭、FSR4、CheatDeck三款独立功能插件，以及包含SimpleDeckyTDP和Unifideck在内的25款精选插件；支持全部一键安装、商店插件分页浏览、单项安装和三件套文件状态检查。Decky-Framegen 即 FSR4，CheatDeck 安装完成后也可在 Decky 右侧栏显示。另有独立的“周克儿汉化（修复版）”，会持续扫描并替换已知 Decky 可见文案，不修改原插件文件。小黄鸭安装完成后会自动检测 Steam 库中是否已有 Lossless Scaling：已安装会提示可继续使用，未安装会打开 Steam 正版页面。

使用小黄鸭前，安装完成后请在 Steam 正版页面打开游戏右侧齿轮，进入“属性 → 测试版”，选择名称以 Linux 开头的可用版本；随后进入游戏模式，按 Steam Deck 机身右下角的“三个点（…）”按钮，在打开的菜单中依次点击插头图标 → 小黄鸭 → 安装 LSFG。
- 常用软件与远程协助：微信直接从腾讯官网国内 CDN 安装官方 AppImage；QQ 会在上海交大和中科大 Flatpak 缓存间测速、限时切换，避开腾讯 QQ AppImage CDN 的 403 限制；Firefox 使用官方 Flathub 的 `org.mozilla.firefox`，RustDesk 使用123云盘国内直链提供的 AppImage。安装成功后会创建桌面快捷方式，不修改SteamOS只读分区。
- GE-Proton兼容层：从固定的123云盘直链下载并校验SHA256，安装到Steam用户的 `compatibilitytools.d` 目录，不需要管理员权限。
- ToDesk：使用固定的第三方SteamOS适配包并校验SHA256，安装完成后恢复只读保护。
- Steam Deck 优化：清理 Steam 下载缓存、着色器缓存，并提供性能模式提示。
- 国内下载源：添加用户级Flathub国内缓存，同时保留官方Flathub作为备用；应用下载时会测速并自动排序，不修改SteamOS只读系统分区。
- Steam加速器：使用Steamcommunity 302官方Linux AMD64固定安装包；首次在官方界面完成设置后，工具箱可一键启动其已有后台服务，不会改写其代理、hosts/DNS 或证书规则。
- 系统密码：支持设置或修改当前SteamOS用户密码，并可启用用户明确选择的明文密码便利模式。
- 安全清理：清理前必须确认，避免误删。
- 一键修复模式：执行网络检测、Steam 下载缓存清理建议和 DNS 处理提示。
- 一键体检：检查 SteamOS、剩余空间、网络与 Steam 域名解析、Decky、Flatpak 软件源和常用软件状态；不修改系统，并把报告保存到桌面。
- 游戏启动诊断：检查 Steam 游戏库、可用空间、Steam 运行状态、兼容数据、自定义 Proton / GE 和日志目录；不删除游戏、兼容数据或缓存。
- 游戏与掌机助手：一键下载 Epic 和战网官方 Windows 安装包，并安全写入 Steam 非 Steam 游戏条目。首次从 Steam 运行安装器时选择 PE 或 GE-Proton 10.0-4 并完成官方安装；工具箱会持续检测同一 `compatdata/pfx/drive_c` 中的主 EXE，自动把原条目切换到启动器本体，保留原有兼容环境和登录数据。
- 攻略与安全中心：提供启动器、Proton、手柄、反作弊和性能空间的中文兼容攻略；可查看高风险操作说明，并将最近 80 条工具箱操作记录导出到桌面。
- 更新日志：可在工具箱内用触屏查看当前版本的主要改动。
- 自动更新工具箱：每次启动会快速检测版本，发现新版本后自动下载并校验更新；优先使用Gitee，失败后切换GitHub，断网或更新失败时继续启动现有版本。
- 纯触控界面：大按钮支持触屏和触控板，菜单忽略键盘数字和字母输入。
- 专用视觉主题：安装时自动配置大字体、深色遮罩和工具箱背景图，不修改其他 Konsole 会话。

## 主菜单

Steam Deck桌面快捷方式会通过兼容启动器打开约 `1220×740` 的双栏 Konsole 界面，并使用 17 号字体和最多 20 行的紧凑布局。直接运行 `main.sh` 也会自动转入专用主题窗口。启动器会依次尝试完整主题、无主题兼容参数、Konsole最小参数和系统中的其他终端；主程序异常退出或所有终端均不可用时会显示明确提示。独立启动日志保存在 `~/.local/state/zhoukeer-toolbox/launcher.log`，不与业务操作日志混用。免责声明使用独立页面，确认按钮始终保留在可见区域；左侧分类、右侧功能和确认按钮都是两行高的大点击区，只响应触屏或触控板，不显示也不接受数字/字母菜单输入。管理员验证可使用下文说明的密码便利模式；记录缺失、失效或系统拒绝自动验证时，仍会显示SteamOS原生密码提示。

## 一行命令安装（推荐）

### 最短安装（使用自有域名 jktool.icu）

```bash
curl -L https://jktool.icu/i | sh
```

### Gitee 国内源（备用）

在 Steam Deck 桌面模式打开 Konsole，使用最短可靠安装指令：

```bash
curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/i|sh
```

完整入口：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/bootstrap.sh | bash
```

GitHub 备用源：

```bash
curl -fsSL https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/bootstrap.sh | bash
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

桌面快捷方式会使用项目中的圆形透明 `assets/icon-round.png`，内部图案仍来自原始 `assets/icon.png`。

如果桌面快捷方式提示不受信任，请右键选择允许启动。

## 运行

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/main.sh"
```

## 常见问题

### 软件显示已安装但桌面没有图标

再次点击该软件的安装按钮即可：工具箱会识别已安装状态，只修复桌面图标而不会重复下载。

### 下载很慢或失败

工具箱会先测速国内源与官方源，并自动优先选择较快来源；每个来源会自动重试，失败后再切换备用源。网络完全不可用时会停止并保留已有软件，不会无限等待。

### 如何查看系统状态与排查问题

工具箱“系统设置 → 查看系统信息”会显示 SteamOS 版本、设备架构、用户目录剩余空间、基础网络状态和常用软件安装状态，同时在桌面生成：

```text
周克儿工具箱诊断报告.txt
```

工具箱操作记录位于：

```text
${HOME}/.local/share/zhoukeer-toolbox/logs/toolbox.log
```

日志不记录系统密码；请在需要协助时只分享与问题相关的末尾几行。

## ToDesk说明

用户提供的 `curl -L todesk.lanbai.top | sh` 会继续下载可变脚本、关闭SteamOS只读保护并使用pacman安装第三方软件包。本工具不会直接执行这条管道命令，而是固定已审查的 `mclanbai/archtodesk` 提交和ToDesk 4.7.2.0软件包SHA256。安装前会明确提示风险并要求管理员验证，完成后尝试恢复只读保护。

ToDesk并非SteamOS原生软件，SteamOS系统更新可能移除通过pacman安装的内容。工具不会删除已有ToDesk用户配置，也不会使用 `chmod 777`。

首次使用ToDesk前，必须先在Steam Deck游戏模式中完成：按 `Steam` 键进入“设置 → 系统”，开启“启用开发者模式”；随后从设置侧栏进入“开发者”，在“杂项”中开启“使用旧版X11桌面模式”，再重新进入桌面模式。工具箱会把这套步骤做成安装前的强制触控说明页，顾客确认两项开关均已开启后才能继续安装。

## Steam加速器说明

工具箱安装的是Steamcommunity 302官方提供的Linux AMD64固定安装包，不使用来源不明的二次打包。安装过程可能需要root权限；实际启用加速时，Steamcommunity 302可能修改本机hosts或DNS、安装自签根证书，并通过本机HTTPS代理处理请求。使用前请阅读官方界面中的说明，退出或卸载前也应按官方方式恢复相关设置。

工具箱本身只完成安装，不会自动开启加速服务，也不会替用户确认上述系统改动。需要自动运行时，请在Steamcommunity 302官方GUI中自行选择“开机运行—后台服务(无界面)”。

## SteamOS密码便利模式

“设置系统密码”和“修改系统密码”会更新当前SteamOS用户的密码，并将新密码以明文写入：

```text
$HOME/Desktop/管理员密码.txt
```

该文件权限固定为 `600`，只有当前用户可以直接读取。工具箱会读取它，并且仅在工具箱自身需要管理员权限时用于sudo自动验证；密码不会写入工具箱日志、不会上传、不会加入安装包或Git仓库，也不会用于其他程序。

这是用户明确选择的便利模式，不是加密密码管理。任何已经取得当前SteamOS用户访问权限的人，都可能读取该文件；分享设备、远程协助或发送诊断资料前请注意保护。若密码被再次手动修改，应同步更新该文件，否则自动验证会失败并回到系统原生密码提示。

## 更新

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/update.sh"
```

桌面启动器会在每次启动时比较本地和远程 `VERSION`，检测到新版本后自动下载发布包。更新包完成 SHA256 校验且包内版本与检测结果一致后才会调用安装器；检测失败、断网或更新失败不会阻止当前版本启动。安装器先在同级暂存目录准备完整新版本，再切换安装目录；准备或切换失败时保留、恢复旧版本。安装器会保留已有非空配置，并在更新时清除已经退役的 RustDesk 服务器字段。需要临时关闭启动自动更新时，可设置环境变量 `ZHOUKEER_AUTO_UPDATE=0`。

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
7. 不要在 Release 包中包含密码、Token、邮箱或个人路径；桌面的 `管理员密码.txt` 仅在用户设备本地生成。

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
- ToDesk安装后是否恢复SteamOS只读保护、服务是否启动、桌面入口是否存在。
- Decky、微信、QQ和Firefox浏览器在当前SteamOS版本是否能正常安装、创建桌面快捷方式并启动。
- 用户级Flathub国内缓存是否可用，官方Flathub备用源是否仍然保留。
- Steamcommunity 302官方Linux AMD64包是否能正常安装；用户在官方GUI启用“开机运行—后台服务(无界面)”后是否按预期启动，以及退出/卸载后hosts、DNS、证书和本机代理是否正确恢复。
- 设置/修改SteamOS密码后，桌面 `管理员密码.txt` 是否为明文新密码且权限为 `600`；工具箱sudo自动验证失败时是否安全回退到系统原生提示。
- 更新菜单能否从Gitee下载并验证固定更新包，Gitee失败时能否切换GitHub。
- 游戏模式/桌面模式之间的菜单显示和中文字体是否正常。
