
## V4.0.78 公开版 — 2026-07-17

- 修复刷新应用索引卡死问题：改为逐个源刷新（Sjtu→Ustc→flathub），每个源 60 秒超时，不再一次性等 180 秒。
- 修改文件：`modules/domestic_source.sh`。




## V4.0.77 公开版 — 2026-07-17

- 修复国内源验证失败问题：验证前先刷新 AppStream；自动检测源级别（system/user）；超时从 30 秒增至 60 秒。
- 修改文件：`modules/domestic_source.sh`。




## V4.0.76 公开版 — 2026-07-17

- system_setup 增加 sudo -n 快速路径：sudo 缓存有效时直接使用，无需交互；无效时才走 toolbox_sudo 自动提权。
- 修改文件：`modules/software.sh`。




## V4.0.75 公开版 — 2026-07-17

- system_setup、flatpak_mirror_delete、flatpak_mirror_reset 改为使用 toolbox_sudo 读取桌面密码文件自动提权，不再强制 passwd。
- 为 software.sh 和 domestic_source.sh 添加 core/auth.sh 支持。
- 修改文件：`modules/software.sh`、`modules/domestic_source.sh`。



## V4.0.74 公开版 — 2026-07-17

- 新增 system_setup、flatpak_mirror_delete、flatpak_mirror_reset 函数并接入菜单。
- 修改文件：`modules/software.sh`、`modules/domestic_source.sh`、`main.sh`。




## V4.0.73 公开版 — 2026-07-17

- 修复所有子菜单侧栏导航无法返回主菜单的问题：nav-* 处理器改为调用 apply_navigation 更新 NEXT_CATEGORY 后再返回。
- 修改文件：`main.sh`。




## V4.0.72 公开版 — 2026-07-17

- 修复插件商城分页仍然跳出循环的问题：移除 apply_navigation 拦截和 NEXT_CATEGORY 守卫，翻页不再退回主菜单。
- 清理所有文件中的 Unicode 转义序列残余。
- 修改文件：`main.sh`。





## V4.0.71 公开版 — 2026-07-17

- 修复终端打印原始 Unicode 转义序列的问题：改用字面 UTF-8 中文字符。
- 修复 GPG 公钥仍无效的问题：国内镜像（Sjtu/Ustc）增加 --no-gpg-verify 关闭签名校验避免 "public key not found"。
- 修改文件：`modules/domestic_source.sh`。



## V4.0.70 公开版 — 2026-07-17

- Flatpak 应用安装失败时自动修复环境并重试：调用 init_domestic_flatpak 修复 GPG/镜像源后重新安装。
- 修改文件：`modules/software.sh`。




## V4.0.69 公开版 — 2026-07-17

- 新增 `init_domestic_flatpak` 函数：一键修复 GPG 公钥、配置交大/中科大镜像、刷新 AppStream，解决 "public key not found" 和应用索引不可读问题。
- 重写 `scripts/deploy_release.sh`：全自动发布脚本，自动递增版本号、打包、提交、打标签、双推，无需人工输入。
- 修改文件：`modules/domestic_source.sh`、`scripts/deploy_release.sh`、`main.sh`。

## V4.0.68 公开版 — 2026-07-17

- 修复 Flatpak 国内镜像 GPG 公钥缺失和应用索引无法读取的问题：新增 GPG 公钥下载导入、官方源/镜像源双路回退、`flatpak update --appstream` 强制刷新元数据。
- 新增发布部署脚本 `scripts/deploy_release.sh`，支持自动打包、打标签、双推（GitHub + Gitee）。
- 修改文件：`modules/domestic_source.sh`、`scripts/deploy_release.sh`。

## V4.0.67 公开版 — 2026-07-17

- 完善交大 Flatpak 镜像配置函数：现在会自动安装 Flatpak（如缺失）、添加官方源、添加交大镜像。
- 新增 Firefox 交大镜像安装（flatpak install Sjtu firefox）。
- 修改文件：`modules/domestic_source.sh`、`modules/software.sh`。

## V4.0.66 公开版 — 2026-07-17

- 新增 Firefox pacman 系统级安装：临时关闭只读保护，通过 pacman 安装到系统分区。
- 新增交大 Flatpak 镜像源（系统级）添加：适合配合 pacman 安装的 Flatpak 应用。
- 修改文件：`modules/software.sh`、`modules/domestic_source.sh`、`main.sh`。

## V4.0.65 公开版 — 2026-07-17

- 安装 rEFInd 前增加 EFI 引导项检测：发现非标准引导项时列出并让用户确认，避免影响客户机器上已有的引导配置。
- 修改文件：`modules/dual_system.sh`。

## V4.0.64 公开版 — 2026-07-17

- rEFInd 移除改为更安全的"隐藏/恢复"：隐藏 = timeout 设为 0（开机直接进系统），恢复 = 改回 timeout 10（显示选择画面），不再删除文件和 EFI 引导项。
- 修改文件：`modules/dual_system.sh`、`main.sh`。

## V4.0.63 公开版 — 2026-07-17

- rEFInd 下载增加 GitHub 镜像回退，优先走 ghproxy.net / gh.api.99988866.xyz 加速。
- 修改文件：`modules/dual_system.sh`。

## V4.0.62 公开版 — 2026-07-17

- 新增 rEFInd 图形引导管理器安装/卸载功能：开机显示 SteamOS / Windows 系统图标供选择，替代 systemd-boot 文本菜单。
- 修改文件：`modules/dual_system.sh`、`main.sh`。

## V4.0.61 公开版 — 2026-07-17

- 修复着色器缓存清理不彻底的问题：之前只清理默认 Steam 库的缓存，现在通过读取 libraryfolders.vdf 发现所有 Steam 库（包括 SD 卡上的），逐一清理。
- 修改文件：`modules/clean.sh`、`modules/steam.sh`。

## V4.0.60 公开版 — 2026-07-17

- 修复清理用户缓存时因部分文件属主为 root 导致"权限不够"的问题：清理操作改用 sudo 执行。
- 修改文件：`core/safety.sh`。

## V4.0.59 公开版 — 2026-07-17

- 所有 Flatpak 网络操作（remote-add、remote-modify、remote-ls）统一增加 30 秒超时，防止因网络不通导致工具卡死。
- 修改文件：`modules/software.sh`、`modules/domestic_source.sh`。

## V4.0.58 公开版 — 2026-07-17

- 修复新机初始化时 Firefox 安装卡死的问题：Firefox 改为使用国内 Flathub 镜像源（交大/中科大），不再连接官方 Flathub（dl.flathub.org 在国内几乎不可用）。
- 修改文件：`modules/software.sh`。

## V4.0.57 公开版 — 2026-07-17

- 修复 QQ 下载失败（腾讯 CDN 403）的问题：QQ AppImage 下载 curl 增加浏览器 User-Agent 和 Referer 头，模拟浏览器请求绕过 CDN 限制。
- 修改文件：`modules/software.sh`。

## V4.0.56 公开版 — 2026-07-17

- 下载优先级改为 Gitee → GitHub → 域名（jktool.icu），避免部分网络下 .icu 域名连接被重置时更新失败。
- 修改文件：`bootstrap.sh`、`update.sh`。

## V4.0.55 公开版 — 2026-07-17

- 修复 macOS 打包带入 Apple 扩展属性（LIBARCHIVE.xattr.com.apple.provenance）导致 SteamOS 解压时大量警告的问题：打包脚本 `package_release.sh` 改用 `--no-xattrs`。
- 修复解压后部分文件权限异常导致 `install.sh` 复制时报"无法以读取模式打开"的问题：`bootstrap.sh` 和 `update.sh` 解压时也使用 `--no-xattrs`。
- 重新构建 dist 发布包。

## V4.0.54 公开版 — 2026-07-17

- GITHUB_MIRRORS 默认值统一到 core/env.sh 的 load_config() 中，各模块不再各自维护 fallback。
- 新增 software.sh 的 load_config 调用。




## V4.0.53 公开版 — 2026-07-17

- GitHub 镜像提取为统一配置 `GITHUB_MIRRORS`，定义在 `config/settings.example.conf`，各模块通过变量引用，不再硬编码镜像地址。
- 修改文件：`modules/ge_proton.sh`、`modules/software.sh`、`modules/plugin_store.sh`、`config/settings.example.conf`。




## V4.0.52 公开版 — 2026-07-17

- GitHub 下载自动回退：下载 GE-Proton、RustDesk、Decky 功能插件时，自动尝试 ghproxy.net、gh.api.99988866.xyz 两个国内镜像，镜像不可用时回退 GitHub 官方源。
- 修改文件：`modules/ge_proton.sh`、`modules/software.sh`、`modules/plugin_store.sh`。

# 周克儿工具箱更新日志

## V4.0.51 公开版 — 2026-07-17

- Steamcommunity 302 安装完成后自动开启后台加速（Steam + GitHub）并设为开机自启，无需手动点"一键开启加速"。
- 新增 systemd 系统服务管理，安装时自动创建 `/etc/systemd/system/steamcommunity302.service` 并启用。
- 卸载时自动停止并移除开机自启服务。

## V4.0.50 公开版 — 2026-07-17

- 彻底移除插件商城和 Decky 安装流程中的 Steamcommunity 302 前置检查。插件商城国内源不再需要 302 加速，下载失败时仅提示可去系统设置启用。

## V4.0.49 公开版 — 2026-07-17

- 插件商城下载不再提示必须安装 Steamcommunity 302，改为在下载慢时提醒去「系统设置」→「Steamcommunity 302」自行下载启用。
- 插件加速检测消息从"所需"改为"可选的"，弱化强制感。

## V4.0.48 公开版 — 2026-07-16

- 修复双系统菜单添加和隐藏可能被 `bootctl` 错误识别 ESP 而同时失败的问题：已找到 `loader` 目录时只修改对应的 `loader.conf`，并在管理员权限验证失败时明确提示原因。

## V4.0.47 公开版 — 2026-07-16

- RustDesk、GE-Proton、SimpleDeckyTDP 与 Unifideck 统一使用作者 GitHub Release 并固定 SHA256 校验，不再提供第三方云盘下载。
- 优化初始化国内源的功能：写入上海交大和中科大 Flathub 用户级缓存后，立即验证两边都能读取 Firefox 应用索引；验证失败会明确提示当前不可用的镜像，且不改动 SteamOS 只读系统分区。
- Steamcommunity 302 成功开启后明确显示已接管 GitHub 与 Steam；自动开启失败时提供桌面程序的三步恢复操作和完成标志。

## V4.0.46 公开版 — 2026-07-16

- 修复三款常用功能插件仍可能沿用失效第三方地址的问题：新的和历史的工具箱配置都会迁移到插件作者固定 GitHub Release。
- 三款功能插件下载改为两轮完整获取，每轮五次网络重试；支持的 SteamOS curl 会额外重试临时网络错误。失败时显示轮次、curl 退出码与桌面 302 的明确恢复步骤。

## V4.0.45 公开版 — 2026-07-16

- 插件加速预检改为不阻断 Decky 安装跳转：302 自动启动失败时显示桌面手动操作提示，但仍用当前网络继续提交插件商城请求。
- 小黄鸭统一使用作者 `0.12.5` 的 `Decky LSFG-VK` 官方目录；安装时清理可确认的旧“小黄鸭”副本并显示实际版本，避免 Decky 继续加载旧版。独立短命令同步修复。
- Epic 与战网入库后同步生成桌面启动图标；关闭首次登录窗口不会删除安装，之后可从 Steam 非 Steam 游戏或桌面图标再次打开。
- 战网优先使用 Proton Experimental 或 Proton 10.0-4；安装器首次拉起失败时会自动在两者之间切换重试，并让 Steam 包装器使用实际成功的那一套兼容层。

## V4.0.44 公开版 — 2026-07-16

- 修复 Steamcommunity 302 官方 CLI 以 root 身份运行时，普通用户执行 `kill -0` 因权限不足而被误判为进程退出的问题。
- 加速状态改为读取 `/proc` 并核对官方 CLI 命令行；证书生成期间不再错误显示“操作未完成”。
- 修复小黄鸭官方 `v0.12.5` 已完整安装，却因 `plugin.json` 使用官方名称 `Decky LSFG-VK` 而被状态检查误报缺失的问题；继续兼容旧汉化包名称。
- 三款常用功能插件写入完成后自动重启 Decky 插件加载服务，避免文件夹已存在但插头菜单仍不显示。
- 周克儿汉化升级至 `0.4.1`：不再只监听首次打开的页面；切换 Decky 插件后会重新发现所有 Steam 页面并自动补上汉化观察器。
- 安装 Decky Loader、三款常用插件或官方商城插件前统一检测 Steam/GitHub 加速；未运行时自动安装并启动 302，失败则暂停下载并提示桌面手动勾选与启动步骤。
- Epic 与战网移除拥挤的五步说明/二次确认页；在常用软件中点选后立即执行一键安装，并在启动动作前清理迟到的触控事件，避免终端出现控制码残留。

## V4.0.43 公开版 — 2026-07-16

- Epic、战网在联网下载安装器之前先扫描现有 Proton 前缀；找到 `EpicGamesLauncher.exe`、`Battle.net Launcher.exe` 或 `Battle.net.exe` 时，直接生成启动包装器并入库。
- 已安装机器不再重复下载、校验或运行官方安装程序；同名旧 Steam 条目会原地更新到真实启动包装器。

## V4.0.42 公开版 — 2026-07-16

- 更新请求统一加入防缓存标记，避免域名、Gitee 或 GitHub CDN 返回成套旧版本文件，导致掌机持续运行旧模块。
- 安装器在原子替换前新增关键模块完整性检查，确认 302 中文路径校验修复和 Epic/战网一键 Proton 安装函数都已进入新目录。
- 延续 4.0.41 的 302 修复：官方包即使在 C 语言环境中把中文文件名显示为八进制转义，也只使用稳定的英文 CLI、规则和图标路径完成安全校验。

## V4.0.41 公开版 — 2026-07-16

- Epic 与战网迁移到“常用软件”，系统优化只保留游戏启动诊断，功能位置更符合软件安装习惯。
- Epic、战网升级为真正的一键兼容安装：自动寻找 GE-Proton / Proton Experimental，缺少时自动安装 GE-Proton，直接运行官方安装器；安装完成后生成 Linux 包装器并写入 Steam，无需手动选择兼容层或从 Steam 启动安装器。
- 兼容战网的 `Battle.net Launcher.exe` 与 `Battle.net.exe` 两种主程序路径；升级旧条目时按名称原地切换，避免 Steam 库出现重复启动器。
- 修复 Steamcommunity 302 官方压缩包中文文件名在 C 语言环境下被转义后误报“目录结构异常”的问题；仍保留固定来源、MD5、SHA256、路径和文件类型校验。

## V4.0.40 公开版 — 2026-07-16

- 302 改为工具箱内置 Steam + GitHub 加速：一键安装官方 CLI、生成限定规则并直接后台启停，不再要求客户先打开 302 图形界面。
- 修复 Epic、战网安装后 Steam 入库失败时的 `shortcuts.vdf contains trailing data`，兼容多余结束标记并在写回时规范化。
- 修复汉化插件只显示入口但不生效的问题，改为注入 Decky 官方共享页面并持续扫描动态界面；版本更新为 0.4.0。
- 更新日志页面改为读取当前 `CHANGELOG.md` 和 `VERSION`，不再固定显示旧日期。

## V4.0.39 公开版 — 2026-07-16

- 修复自动更新替换旧安装目录后，终端仍停留在已删除目录并反复显示 `getcwd/chdir` 的问题；更新前后会主动切换到有效工作目录。
- 修复发布安装器遗漏 `scripts` 目录，导致 Epic、战网提示“Steam 入库组件缺失”的问题；新增安装包完整性与原地更新回归测试。

## V4.0.38 公开版 — 2026-07-16

- 小黄鸭、Decky-Framegen 和 CheatDeck 改为作者 GitHub Release 固定版本并校验 SHA256；旧版工具箱写入的默认下载地址会在运行时自动迁移，用户自定义地址不受影响。
- 新增三款插件的独立短命令脚本，脚本只下载作者的官方 Release，不重新托管或二次打包插件文件。

## V4.0.37 公开版 — 2026-07-16

- 触控主菜单改为更舒展的 24 行布局，窗口扩大至 1280×860，保留 17 号可读字体；功能按钮和底部提示不再挤在同一区域。
- “实用指南”从系统优化中独立到左侧主导航，集中放置兼容攻略、掌机快捷键、外接设备检查与操作记录；游戏与掌机助手只保留启动器和诊断。

## V4.0.36 公开版 — 2026-07-16

- Epic 和战网改为自动写入 Steam 非 Steam 游戏列表，不再要求客户右键 Add to Steam 或手动寻找安装后的主 EXE。
- 首次从 Steam 使用 PE 或 GE-Proton 10.0-4 完成官方安装后，后台会检测同一 `compatdata/pfx/drive_c` 的 EpicGamesLauncher.exe 或 Battle.net.exe，安全退出 Steam、切换原条目目标并重新启动 Steam；重复执行不会生成重复条目。

## V4.0.35 公开版 — 2026-07-16

- 修复周克儿汉化插件“能打开但没有实际效果”：不再依赖 Decky 容易变化的卡片 class 名，改为持续扫描并替换已知可见文案；插件名称带版本号时也能识别。
- 汉化提示统一为“请支持插件原作者与汉化者”，并把工具箱入口标为修复版，安装时会原子替换旧文件并重新加载 Decky。

## V4.0.34 公开版 — 2026-07-16

- Firefox 改为从官方 Flathub 安装 `org.mozilla.firefox`，不再使用第三方下载分流或国内镜像，后续更新交由 Flatpak 管理。
- Steamcommunity 302 新增“一键开启加速服务”：仅启动已由官方界面创建的后台服务，不改写代理、hosts/DNS 或证书规则；首次仍需在官方界面完成设置。
- 触控界面在重绘前清理迟到的触控板事件，并关闭遗留鼠标协议，减少启动时出现控制字符残留的情况。
- 修正 Decky 官方插件整组安装的回传状态，明确区分已是最新版、已提交和未确认。

## V4.0.24 公开版 — 2026-07-16

- RustDesk 改用作者 GitHub Release 的 AppImage，并增加格式与 SHA256 校验；移除 AnyDesk 下载入口。
- 从商城分页和批量安装名单移除会报错的 Game Theme Music，插件总数同步调整为28款。
- 修正 CheatDeck 说明：安装完成后可在 Decky 右侧栏显示。

## V4.0.23 公开版 — 2026-07-16

- 修复周克儿汉化“运行但完全不生效”：动态文字节点现在会回溯到所属页面处理，并每秒兼容扫描一次新版 Decky 页面。
- 汉化插件新增“立即扫描当前页面”按钮和扫描结果提示，并补充小黄鸭、Decky Framegen 的显示名称别名。

## V4.0.22 公开版 — 2026-07-16

- 修复“一键清空已装插件”触控入口：改用工具箱内置大按钮确认页，不再依赖可能被终端遮挡的 KDE 确认窗口。

## V4.0.21 公开版 — 2026-07-16

- 修复 QQ 下载 `403`：改用上海交大与中科大 Flathub 国内缓存安装 `com.qq.QQ`，不再请求被腾讯 CDN 拒绝的 AppImage 地址。

## V4.0.20 公开版 — 2026-07-16

- 插件商城新增“一键清空已装插件”：一次确认后清空插件根目录的全部内容，Decky Loader 本体不会被删除，完成后自动重载插件列表。
- 修复周克儿汉化更新后漏装模块声明的问题，避免 Decky 将其按旧插件加载并报 `Unexpected token 'export'`。

## V4.0.19 公开版 — 2026-07-16

- 优化 Gitee 国内更新链路：版本检查与更新包下载均增加等待时间和自动重试，只有多次失败后才切换 GitHub 备用源。
- 周克儿汉化安装完成后自动重启 Decky Loader，使新插件立即被重新扫描并显示在插件列表中。

## V4.0.18 公开版 — 2026-07-16

- 修正常用 Decky 三件套的完成提示：安装后逐项检查小黄鸭、FSR4 与 CheatDeck 的文件是否完整写入 Decky 目录。
- 明确 CheatDeck 从游戏库内单个游戏的齿轮或右键菜单进入，不会作为第三个插件侧栏图标显示；新增“三件套状态检查”入口。
- 修复自动更新包遗漏周克儿汉化组件的问题，更新到本版后即可正常安装。

## V4.0.17 公开版 — 2026-07-16

- 重做触控终端界面：导航、标题、说明和按钮使用统一暗色信息卡与红色强调线，提升壁纸背景下的阅读对比度。
- 界面改为 SteamOS 掌机通用文案；窄终端自动收紧导航栏，适配更多 SteamOS 掌机的桌面模式。

## V4.0.16 公开版 — 2026-07-16

- 新增中文兼容攻略卡，整理启动器、Proton、手柄、反作弊、性能和空间的通用处理建议。
- 新增攻略与安全中心：查看新手安全说明，并将最近 80 条工具箱操作记录导出到桌面。

## V4.0.15 公开版 — 2026-07-16

- 修复 ToDesk 下载 `400`：改为从可访问的固定 Gitee 提交拉取安装包，继续校验 SHA256，不执行上游在线安装脚本。
- 游戏与掌机助手新增 Epic、战网官方安装包下载；安装完成后按引导在原 Steam 条目中换为软件目录内的主 EXE，并保留原 Proton 环境。
- 新增掌机常用快捷键与外接显示器、蓝牙设备的只读检查。

## V4.0.14 公开版 — 2026-07-16

- 系统优化新增“游戏启动诊断”，检查 Steam 游戏库、空间、运行状态、兼容数据、Proton / GE 和日志目录。
- 诊断只读取状态、保存报告，不会删除游戏、兼容数据或缓存。

## V4.0.13 公开版 — 2026-07-16

- 将“查看系统信息”升级为“一键体检”，检查 SteamOS、空间、网络、Steam 域名解析、Decky、Flatpak 软件源和常用软件状态。
- 一键体检不会修改系统或清理数据，并将中文报告保存到桌面。

## V4.0.12 公开版 — 2026-07-16

- 主页右侧功能说明改为与左侧菜单同名、同顺序的独立条目，修复双系统设置及底部功能说明挤在一起的问题。

## V4.0.11 公开版 — 2026-07-16

- 将工具箱一行安装指令压缩为 `curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/i|sh`。

## V4.0.10 公开版 — 2026-07-16

- 首个公开版，结束开发版标记，保持自动更新版本号连续。
- 汉化署名改为“闲鱼双叶汉化制作，请支持汉化者”。

## V4.0.9 开发版 — 2026-07-16

- 插件商城新增“周克儿汉化（测试版）”独立安装入口。
- 新增独立 Decky 汉化层，首批覆盖29款插件的标题与常见操作文案。
- 插件页显示“闲鱼双叶汉化，请支持插件原作者”，不改写原插件文件。
- 汉化范围限制在识别到的插件面板，避免误改 Steam 系统菜单。
- 修复发布打包规则，确保 Decky 插件的前端运行文件被包含且不带开发依赖。

## V4 开发版 — 2026-07-14

- 全新触控分类界面，支持触屏和触控板直接点击。
- 加入黑白主题背景、工具箱图标和桌面快捷方式。
- 常用软件加入微信、QQ、Firefox，安装后自动创建桌面入口。
- 新增上海交大、中科大双国内缓存源和 Steamcommunity 302 安装管理。
- 新增系统密码设置、修改及工具箱自动验证。
- 插件商城加入 Decky Loader、小黄鸭、FSR4、CheatDeck。
- ToDesk 安装前显示开发者模式与旧版 X11 设置教程。
- 远程协助加入 RustDesk 与 AnyDesk，一键安装后自动创建桌面入口。
- QQ 改用腾讯官网国内 CDN 的官方 AppImage，下载失败时保留旧版本。
- 微信改用腾讯官网国内 CDN 的官方 AppImage，避开Flatpak额外下载链。
- 浏览器改用Firefox完整压缩包安装，不再依赖Chrome、Chromium或Flatpak来源。
- 修复固定更新包被旧文件覆盖后仍显示Chrome浏览器的问题。
- 发布版本更新至4.0.5-dev，确保客户端重新触发自动更新。
- 桌面和图形菜单改用圆形工具箱图标，保留原有图案不重绘。
- Firefox加入URL参数、应用菜单及默认网页处理器注册，修复战网调用浏览器登录卡住。
- 圆形工具箱图标改为独立透明PNG，修复SteamOS/KDE无法加载外部引用SVG的问题。
- 插件商城主菜单更新为当前29款完整清单，补充SimpleDeckyTDP与Unifideck说明。
- Flatpak 软件加入双国内缓存测速、限时切换和明确失败提示，不再自动转连官方源。
- 系统信息加入存储、网络、软件状态和桌面诊断报告。
- 一键新机初始化加入国内源、常用软件、Decky 和 ToDesk。
- 修复旧版密码记录无法识别的问题。
- 修复部分新版 SteamOS/Konsole 点击桌面图标无法启动工具箱的问题。
