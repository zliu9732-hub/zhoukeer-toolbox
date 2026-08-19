# Renkit

Renkit是面向 SteamOS 与 Bazzite 掌机的 Bash 工具集。同一条安装命令会自动选择独立版本：SteamOS 保留完整原版功能，Bazzite 使用单独菜单，仅开放已适配的常用软件、Decky、兼容层、启动器、模拟器和诊断功能。

当前正式版：Renkit 1.8.5；从 Renkit 1.0 起按语义化版本递增。

- SteamOS 版：继续使用原有 `main.sh`，系统初始化、国内源、插件与高级功能保持原逻辑。
- Bazzite 版：使用独立 `main-bazzite.sh`；Decky 通过官方 `ujust setup-decky` 安装，并可整组或逐个安装官方商店插件；Flatpak 默认使用带 GPG 验证的官方 Flathub，国内镜像仅在用户确认风险后以用户级远程启用，并可恢复官方源；提供用户级软件、启动器、模拟器与 GE-Proton 安装/卸载，以及 Yuzu 自备密钥、诊断、攻略和快捷方式维护；不调用 pacman、steamos-readonly、ToDesk、AnyDesk或内存调优。Clover 双系统引导作为独立高风险入口开放，动态识别 Bazzite EFI，并提供状态检查和恢复。

- 双系统设置：提供互通盘挂载与只读保护、TF 卡 NTFS 初始化、NTFS/exFAT 基础修复、只读健康检查、受保护的第三方引导项清理、双系统引导修复，以及桌面“切换至 Windows”快捷方式。工具箱入口只创建图标，不会立即重启；用户主动打开图标并二次确认后才切换。rEFInd 继续停用，不提供入口。

远程协助中提供 RustDesk、AnyDesk 和 ToDesk。RustDesk 使用作者 GitHub Release 安装独立 AppImage 并自动创建桌面图标，不会修改 SteamOS 只读系统分区，也不会被Renkit自动写入任何服务器配置；AnyDesk 通过 Flathub 国内镜像安装；ToDesk 使用固定官方 DEB 的 SteamOS 适配包。

[查看 Steam Deck ToDesk 图文安装教程](TODESK_GUIDE.md)

[查看 Steam Deck 忘记密码／重置密码教程](STEAMDECK_PASSWORD_RESET_GUIDE.md)

## 使用说明与免责声明

本脚本由“Ren-Amamiya-pixie / zliu9732-hub（闲鱼RenAmamiya）”制作。个人玩家可免费使用；禁止商业使用、销售、转卖或二次盈利发布，详细条款见仓库根目录 `LICENSE`。Renkit内收录的下载内容均为官方免费发布或开源内容，不包含付费软件本体、破解内容或商业授权；第三方软件和插件仍以各自许可证及使用条款为准。第三方下载均从作者或官方发布页获取；喜欢本工具，欢迎支持作者。若有侵权，请及时联系作者删除。启动Renkit后须点击“知悉并开始使用”方可进入首页。

## 功能

- 一键新机初始化：一次确认后执行 18 项客户交付流程，检查 SteamOS、网络、电源和系统组件，配置国内源与中文输入法，安装常用软件、Decky、FreeDeck、Epic、常用插件、修改器兼容层、虚拟内存和 Steamcommunity 302，并生成桌面报告与使用说明；战网、Ubisoft Connect 和黑盒工坊开始前可选。
- 插件商城：常用组合包含小黄鸭、FSR4、CheatDeck、游戏封面更换（SteamGridDB）、主题美化（CSS Loader 中文版）、文件传输助手（Friendeck）和音乐播放器（Decky Music），另提供 Decky 官方精选插件；支持整组或单项安装和七款文件状态检查。Decky Loader 子菜单提供 ROG White 白色主题一键安装，把主题文件放入 CSS Loader themes 目录后即可在 CSS Loader 中开启。独立提供 DeckRecall 与 SavePulse：SavePulse 可自动保留存档版本，并使用每位用户自己的坚果云或标准 WebDAV 做加密备份和换机恢复。固定版本均执行 SHA256、ZIP 结构与插件目录校验。安装或检测到功能插件后会在桌面补充风灵月影、小黄鸭和 FSR4 小白教程；检测到 FSR4 时另建 OptiScaler 官方 Wiki 已测试游戏清单。小黄鸭安装完成后会自动检测 Steam 库中是否已有 Lossless Scaling：已安装会提示可继续使用，未安装会打开 Steam 正版页面。

使用小黄鸭前，安装完成后请在 Steam 正版页面打开游戏右侧齿轮，进入“属性 → 测试版”，选择名称以 Linux 开头的可用版本；随后进入游戏模式，按 Steam Deck 机身右下角的“三个点（…）”按钮，在打开的菜单中依次点击插头图标 → 小黄鸭 → 安装 LSFG。
- 常用软件与远程协助：微信使用腾讯官网官方 AppImage；QQ、Chrome、Edge、AnyDesk、百度网盘、LibreOffice、VLC、OBS Studio、LocalSend、PeaZip、WiliWili、QQ音乐、网易云音乐、YesPlayMusic、qBittorrent、Motrix、Free Download Manager、Media Downloader、Flameshot、OnlyOffice、Joplin、Protontricks、Bottles 通过上海交大和中科大 Flathub 国内缓存安装；Xbox 云游戏通过 Flathub 安装 Greenlight，云游戏需 Xbox 账号；Heroic、Lutris、Chiaki4Deck、Parsec 通过 Flathub 安装并自动加入 Steam 库；WiliWili 也会同步加入 Steam 库；Firefox 使用官方 Flathub 的 `org.mozilla.firefox`；RustDesk 使用作者 GitHub Release 提供的 AppImage。安装成功后会创建桌面快捷方式，不修改 SteamOS 只读分区。
- 安装与卸载：软件、兼容层和插件会先检测现有完整安装，已安装时不重复下载；独立的七页卸载菜单可逐项移除，启动器卸载保留游戏与下载文件，模拟器卸载保留存档与配置，系统组件和全部插件仍需风险确认。
- GE-Proton兼容层：安装入口提供“最新 GE 兼容层”和“修改器所需常用兼容层”（GE-Proton 7-55/8-25/9-27/10-29）两个选项；最新版安装不再删除旧版。下载后校验 SHA256，安装到 Steam 用户的 `compatibilitytools.d` 目录，不需要管理员权限；安装完成后自动重启 Steam 使其生效。
- ToDesk：使用固定的第三方SteamOS适配包并校验SHA256，安装完成后恢复只读保护。
- Steam Deck 优化：清理 Steam 下载缓存、着色器缓存，并提供性能模式提示。
- 国内下载源与系统组件：先检测 SteamOS 基础组件，已安装且无对应更新时跳过 pacman 更新；archlinuxcn 使用上海交大、中科大和官方 HTTPS 镜像逐级回退，安装并加载 GPG 密钥环；三条线路均失败时撤销Renkit写入的该仓库并继续配置 locale 与 Flatpak 国内缓存，不阻断其他软件安装。完成后恢复只读保护，恢复入口不覆盖用户原有配置。
- Steam加速器：使用Steamcommunity 302官方Linux AMD64固定安装包；安装后自动启用 Steam 与 GitHub 规则、立即后台运行并设置开机自启，并检查官方就绪标记或本地 DNS/代理监听，避免只看到进程就误报成功。
- 主机加速器：提供奇游、迅游、网易UU的官方主机加速安装与配置入口；三家没有 SteamOS 原生客户端，因此不会下载 Windows 包，只引导使用手机 App、路由插件或加速盒。
- 更多设置：集中提供国内源、Steam302、zram 与磁盘 swap 一键优化、修改管理员密码和双系统工具。
- 安全诊断包：一键在桌面生成可发给维护人员的本地诊断包，自动隐藏用户名、HOME、网络地址、密码、Token、Cookie、代理认证和远程协助凭据；不会读取管理员密码便利模式文件，不上传、不联网发送。
- 设置备份与恢复：只处理Renkit白名单配置、Renkit管理的国内源状态、Steam302 规则、内存参数和Renkit快捷方式；不处理游戏、存档、Steam 账号数据、整个 HOME 或非Renkit管理的系统配置。
- 高风险预检：国内源与系统更新、Decky、Steam302、内存优化和新机初始化在执行前统一检查空间、网络、SteamOS、系统保护和电量；不满足条件时不会强行继续。
- 受控下载：下载域名、用途、文件类型、版本策略、校验方式、大小上限和回退规则由代码白名单集中维护；未知来源、HTML/403、超限或校验失败的内容不会执行。
- 安全清理：清理前必须确认，避免误删。
- 一键修复模式：执行网络检测、Steam 下载缓存清理建议和 DNS 处理提示。
- 一键体检：检查 SteamOS、剩余空间、网络与 Steam 域名解析、Decky、Flatpak 软件源和常用软件状态；不修改系统，并把报告保存到桌面。
- 游戏启动诊断：检查 Steam 游戏库、可用空间、Steam 运行状态、兼容数据、自定义 Proton / GE 和日志目录；不删除游戏、兼容数据或缓存。
- 游戏与掌机助手：一键下载 Epic、战网和育碧官方 Windows 安装包，自动创建带Renkit标识的桌面入口，并写入当前 Steam 账号的非 Steam 游戏库及完整封面。Windows 虚拟目录默认放在用户可见的 `~/游戏启动器`，Steam 条目直接绑定真实 EXE 与 Proton 10.0-4，并把 Steam compatdata 的 drive_c 链接到同一份目录，便于黑盒工坊等插件定位游戏文件。Epic 安装包先走 Gitee 分块镜像，失败后回退官方源与官方 CDN 固定版；小黄鸭和 FSR4 使用 Gitee 国内归档优先、GitHub Release 回退的双源下载，Gitee 失败后自动切换 GitHub。战网由 Steam 原生条目配合 Proton Experimental 完成安装并复用同一兼容环境；Epic 与育碧继续由Renkit自动准备兼容层，缺少时通过 Steam 补齐官方 Proton。
- 实用指南：独立提供启动器、Proton、手柄、反作弊和性能空间的中文兼容攻略；可查看常用快捷键、外接设备状态、高风险操作说明，并将最近 80 条Renkit操作记录导出到桌面。
- 更新日志：可在Renkit内用触屏查看当前版本的主要改动。
- 自动更新Renkit：每次启动会快速检测版本，发现新版本后自动下载并校验更新；优先使用Gitee，失败后切换GitHub，断网或更新失败时继续启动现有版本。
- 纯触控界面：大按钮支持触屏和触控板，菜单忽略键盘数字和字母输入。
- 专用视觉主题：安装时自动配置大字体、深色遮罩和Renkit背景图；启动免责声明使用终端文字版，不展示大图开屏，不修改其他 Konsole 会话。

## 主菜单

桌面快捷方式会通过兼容启动器打开约 `1280×740` 的双栏 Konsole 界面，使用 12 号中文字体和固定九分类触控坐标。直接运行当前平台对应的主程序也会自动转入专用主题窗口。启动器会依次尝试完整主题、无主题兼容参数、Konsole最小参数和系统中的其他终端；主程序异常退出或所有终端均不可用时会显示明确提示。独立启动日志保存在 `~/.local/state/zhoukeer-toolbox/launcher.log`，不与业务操作日志混用。

## 一行命令安装（推荐）

### Gitee 国内源

国内网络优先使用下面的命令：

```bash
curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/i|sh
```

## 三款核心插件独立安装

以下命令由Renkit下载器统一处理：Gitee 分块镜像优先，失败后回退作者 GitHub Release；下载后校验 SHA256 并原子替换 Decky 插件目录，不使用或转存第三方 ZIP。运行前请先安装 Decky Loader。

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/scripts/install-decky-plugin.sh | bash -s -- lsfg
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/scripts/install-decky-plugin.sh | bash -s -- framegen
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/scripts/install-decky-plugin.sh | bash -s -- cheatdeck
```

安装后完全退出游戏模式再重新进入一次，让 Decky 重新扫描插件。小黄鸭、Decky-Framegen 和 CheatDeck 的插件作者分别为 xXJSONDeruloXx、xXJSONDeruloXx、SheffeyG，请支持原作者。

Gitee 完整入口：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/bootstrap.sh | bash
```

默认安装目录：

```bash
${HOME}/.local/share/zhoukeer-toolbox
```

安装前预演，不修改文件：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/bootstrap.sh | bash -s -- --dry-run
```

安装完成后会创建：

- 桌面快捷方式：`~/Desktop/Renkit.desktop`
- 应用菜单入口：`~/.local/share/applications/zhoukeer-toolbox.desktop`

桌面快捷方式使用 `assets/icon-toolbox-deck.png` 作为图标；如需更换，直接替换该文件后重新安装即可。

如果桌面快捷方式提示不受信任，请右键选择允许启动。

## 运行

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/launch.sh"
```

## 常见问题

### 软件显示已安装但桌面没有图标

再次点击该软件的安装按钮即可：Renkit会识别已安装状态，只修复桌面图标而不会重复下载。

### 下载很慢或失败

Renkit会先测速国内源与官方源，并自动优先选择较快来源；每个来源会自动重试，失败后再切换备用源。网络完全不可用时会停止并保留已有软件，不会无限等待。

### 如何查看系统状态与排查问题

Renkit首页点击“检查与维护 → 发给维护人员”会在桌面生成：

```text
Renkit诊断包-时间戳.tar.gz
```

诊断包只包含安全摘要并自动脱敏，不会读取或复制桌面的 `管理员密码.txt`，也不会上传或自动发送。旧版文字报告和Renkit操作记录仍可在“使用帮助与设置”中单独查看。

Renkit操作记录位于：

```text
${HOME}/.local/share/zhoukeer-toolbox/logs/toolbox.log
```

日志不记录系统密码；请在需要协助时只分享与问题相关的末尾几行。

## ToDesk说明

用户提供的 `curl -L todesk.lanbai.top | sh` 和旧版 yay 教程会执行可变脚本或引入 AUR、base-devel 与第三方软件包。本工具不会执行这些流程，而是通过现有 GitHub Release 镜像测速链路下载未修改的 ToDesk 官方 4.8.6.2 DEB，全部镜像失败时再在后台尝试官网，全程不需要浏览器。安装包必须通过固定 SHA256、DEB 格式与包内结构校验，然后才在本机只提取数据文件、重新生成最小 SteamOS 软件包；不会执行官方 DEB 自带的维护脚本，也不依赖第三方 ToDesk 包。安装前会明确提示风险并要求管理员验证，完成后尝试恢复只读保护。

ToDesk并非SteamOS原生软件，SteamOS系统更新可能移除通过pacman安装的内容。工具不会删除已有ToDesk用户配置，也不会使用 `chmod 777`。

首次使用ToDesk前，必须先在Steam Deck游戏模式中完成：按 `Steam` 键进入“设置 → 系统”，开启“启用开发者模式”；随后从设置侧栏进入“开发者”，在“杂项”中开启“使用旧版X11桌面模式”，再重新进入桌面模式。Renkit会把这套步骤做成安装前的强制触控说明页，顾客确认两项开关均已开启后才能继续安装。

## Steam加速器说明

Renkit安装的是Steamcommunity 302官方提供的Linux AMD64固定安装包，不使用来源不明的二次打包。安装过程可能需要root权限；实际启用加速时，Steamcommunity 302可能修改本机hosts或DNS、安装自签根证书，并通过本机HTTPS代理处理请求。使用前请阅读官方界面中的说明，退出或卸载前也应按官方方式恢复相关设置。

Renkit会生成只启用 Steam 与 GitHub 的配置，并创建带管理标记的 systemd 服务，安装完成后立即启动并设置开机自启。启动、更新、重置和状态检查不会只看 systemd 进程，而会继续检查官方 `S302.run` 就绪标记，或本地 DNS 53 与代理 80/443 监听；进程存在但代理未就绪时会提示打开一次官方配置界面完成证书和 DNS 初始化。桌面不会出现 Steamcommunity 302 图标；停止或卸载时只处理Renkit生成的同名服务，不覆盖或删除其他程序创建的服务。官方 CLI 仍可能按自身实现修改 hosts、DNS、证书或本机代理，使用前请阅读风险说明。

奇游、迅游、网易UU目前都没有可直接安装到 SteamOS 的官方 Linux 客户端。Renkit的“主机加速器”页面只打开三家的官方主机加速安装与配置入口，按官网方案使用手机 App、路由器插件、电脑共享或加速盒；不会把 Windows 客户端装进 Wine 后误报为可用。

## SteamOS密码便利模式

“设置管理员密码”和“修改管理员密码”会更新当前 SteamOS 用户的密码，并将新密码以明文写入：

```text
$HOME/Desktop/管理员密码.txt
```

该文件权限固定为 `600`，只有当前用户可以直接读取。Renkit会读取它，并且仅在Renkit自身需要管理员权限时用于sudo自动验证；密码不会写入Renkit日志、不会上传、不会加入安装包或Git仓库，也不会用于其他程序。

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

## 发布版本

建议发布流程：

1. 确认 `bash -n` 检查通过。
2. 确认 `config/settings.conf` 不包含私人配置。
3. 更新 `VERSION` 与 `CHANGELOG.md`，确认本机 SSH 可以推送 Gitee。
4. 执行 `bash scripts/deploy_release.sh` 生成发布包、`.sha256` 和 `SHA256SUMS` 校验文件；发布包必须不超过 9,437,184 字节。
5. 只显式暂存本次发布文件，提交代码并打 tag，例如 `v1.2.0`；禁止 `git add .`、force push 或改写历史。
6. 只推送 `main` 与当前版本 tag（例如 `v1.6.1`），禁止使用 `git push --tags`；避免把已清理的旧标签带回仓库。再在 Gitee Release 中上传版本化发布包和 `.sha256` 校验文件。
7. 在 Release 中写明安装、更新、卸载命令。
8. 不要在 Release 包中包含密码、Token、邮箱或个人路径；桌面的 `管理员密码.txt` 仅在用户设备本地生成。

默认下载顺序：

1. Gitee项目内固定包：`dist/renkit.tar.gz`

## 当前版本与维护

当前正式版为 Renkit 1.8.5，后续版本从 1.0 起按语义化版本递增。后续维护同时覆盖 SteamOS 与 Bazzite 的独立菜单；rEFInd 继续停用，Clover 通常由 UEFI GOP 自动选择分辨率，GPD WIN 3 会优先请求 1280x720 横屏模式；Bazzite 安装/修复 Clover 时会备份并清理检测到的旧 SteamOS 引导，但不会删除系统分区，其他通用 EFI 高风险工具不开放。

安装包必须与同一来源的 `dist/SHA256SUMS` 匹配，否则安装或更新会停止。
