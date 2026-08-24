# Renkit 完整开发与账号迁移交接

更新时间：2026-08-13（Asia/Shanghai）

这份文档是给“完全没有旧聊天上下文的新 Codex 账号/新维护者”使用的。它记录当前真实状态、仓库关系、发布方式、已经做完的功能、真机结论、尚未解决的问题，以及此前踩过的坑。任何数字、版本或远端状态都有可能继续变化，因此接手后仍要先执行核验命令，不能把本文中的提交号永久当作事实。

## 1. 项目身份与不可改变的边界

- 项目名称：Renkit。
- 主要目标平台：Steam Deck / SteamOS，同时提供独立的 Bazzite 菜单。
- 主要语言：Bash；少量 Python 用于 Steam 数据和本地辅助。
- 开发机：macOS。macOS 只能做静态检查、语法检查、打包和完全模拟测试。
- 禁止在 macOS 执行真实 SteamOS/Bazzite 安装、`sudo` 系统修改、Flatpak/pacman、systemd、EFI、NVRAM 或磁盘操作。
- SteamOS 与 Bazzite 必须继续使用独立菜单和平台隔离，不能为了复用代码把两边高风险系统操作混在一起。
- rEFInd 已停用，不得重新显示入口；双引导只维护 Clover。
- 已经工作的模块只做最小修改，不做无关重构。
- 不得写入密码、Token、Cookie、SSH 私钥或个人绝对路径。
- 不得用 `eval`、动态 `bash -c`/`sh -c`，也不得直接 `source` 用户可编辑配置。
- 所有下载必须检查 HTTP 失败、超时、文件大小/类型、SHA256 和压缩包结构，不能执行 HTML/404 页面。
- 高风险操作必须有中文说明、明确确认、日志、失败回滚和安全退出。

这些规则的最新版本以根目录 `AGENTS.md` 为准；本文件不能取代它。

## 2. 接手第一步：先核对，不要直接改

在仓库根目录依次执行：

```bash
pwd
cat AGENTS.md
cat docs/RENKIT_HANDOFF.md
git status --short --branch
git remote -v
git fetch origin main --tags
git fetch gitee-v2 main --tags
git log --oneline --decorate -12 origin/main
git log --oneline --decorate -12 gitee-v2/main
git show origin/main:VERSION
git show gitee-v2/main:VERSION
gh auth status
```

然后核对公网实际更新源：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/VERSION
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/dist/SHA256SUMS
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/latest.txt
```

如果工作区有用户未提交文件，不要删除、覆盖、stash、reset 或 checkout。只显式暂存本次任务文件，禁止 `git add .`。

## 3. 2026-08-13 的关键真实状态

### 3.1 当前存在版本分叉，必须优先处理

截至本文写入时（交接文档本身随后可能作为“仅文档提交”叠加在对应分支顶部）：

- 本地 `main` 与 GitHub `origin/main`：提交 `6e14f94`，源码版本 `1.4.4`。
- GitHub 最新正式 Release：`v1.4.4`。
- Gitee v2 的当前功能代码基线：提交 `0abc034`，部署版本 `1.4.7`。
- Gitee v2 的 `1.4.7` 包已公网验证：`VERSION=1.4.7`，包内 `core/env.sh` 也是 `1.4.7`。
- 当时公网 `dist/renkit.tar.gz` SHA256：`289a8607a1add4d3cd7f03751960704bcf0603773e361c856ee909c57a701e96`；接手时应重新读取，不要永久硬编码这个值。
- Gitee v2 有 `v1.4.5`、`v1.4.6`、`v1.4.7` 标签；GitHub 没有这些版本的 Release。

因此，用户实际通过国内一行命令和自动更新拿到的是 `1.4.7`，不是 GitHub 的 `1.4.4`。在完成对齐前：

- 绝不能从 GitHub 1.4.4 继续升版并覆盖 Gitee v2，否则会把 1.4.5～1.4.7 功能删掉。
- 绝不能重新发布或改写历史版本 `1.4.5`、`1.4.6`、`1.4.7`。
- 下一正常功能版本应从 `1.4.8` 开始。
- 下一位维护者的首要任务是把 Gitee v2 的 1.4.7 完整树安全同步回 GitHub `main`，跑全测后为 GitHub补建 `v1.4.7` Release；不需要伪造 1.4.5/1.4.6 的 GitHub 提交历史。

### 3.2 安全对齐建议

不要在当前有脏文件的工作目录直接覆盖。使用临时 clone/worktree：

```bash
SYNC_ROOT="$(mktemp -d)"
git clone git@github.com:zliu9732-hub/zhoukeer-toolbox.git "$SYNC_ROOT/github"
git clone git@gitee.com:zliu9732-hub/zhoukeer-toolbox-v2.git "$SYNC_ROOT/v2"
git -C "$SYNC_ROOT/github" checkout -b codex/sync-v2-1.4.7 origin/main
git -C "$SYNC_ROOT/github" rm -r --ignore-unmatch .
git -C "$SYNC_ROOT/v2" archive --format=tar HEAD | tar -x -C "$SYNC_ROOT/github"
git -C "$SYNC_ROOT/github" add -A
git -C "$SYNC_ROOT/github" status --short
git -C "$SYNC_ROOT/github" diff --cached --stat
```

确认 `VERSION`、`core/env.sh`、`README.md`、`CHANGELOG.md`、`install.sh`、`data/`、插件中文组件和 `dist/` 与 v2 一致后，再在这个临时 clone 运行全部测试、提交、推送。上述删除只发生在新建临时 clone 内，不能把路径替换成用户主工作区。

### 3.3 1.4.5～1.4.7 已部署功能

- 1.4.5：DeckRecall 更新到 v0.3.2，移除旧 v0.2.8 Gitee 路由；旧前端补丁只用于旧版本；Decky RPC 错误显示更具体。
- 1.4.6：新机初始化扩展为 18 项；默认包含 Epic、FreeDeck、常用软件、Decky、常用插件、四个修改器 GE-Proton、虚拟内存和 Steamcommunity 302；战网、Ubisoft、黑盒开始前可选；移除新机初始化中的 ToDesk。
- 1.4.6：常用插件新增 SteamGridDB、CSS Loader 中文版、Friendeck、Decky Music；用户看到的名称分别为“游戏封面更换”“主题美化”“文件传输助手”“音乐播放器”。
- 1.4.6：FSR4 桌面兼容清单采用 OptiScaler 官方 Wiki 2026-08-07 快照，排除《怪物猎人：荒野》后为 683 条，并明确 Steam Deck RDNA2/Proton/VKD3D/Mesa/反作弊限制。
- 1.4.7：修复安装器漏复制 `data` 与 CSS Loader 运行文件，用户更新后可正确得到 FSR4 清单和主题美化中文前端。

以上内容目前以 Gitee v2 的树和 CHANGELOG 为准，GitHub 1.4.4 尚未包含。

## 4. 仓库、账号与凭据关系

### 4.1 仓库拓扑

- GitHub 主源码：`git@github.com:zliu9732-hub/zhoukeer-toolbox.git`，remote 名 `origin`。
- Gitee 旧主仓库：`git@gitee.com:zliu9732-hub/zhoukeer-toolbox.git`，remote 名 `gitee`。它历史老、体积曾超限，现有安装更新不应依赖它。
- Gitee v2 国内更新仓库：`git@gitee.com:zliu9732-hub/zhoukeer-toolbox-v2.git`，remote 名 `gitee-v2`。国内一行安装、自动更新、Decky Loader 分块和启动器封面都依赖它。
- Gitee 大文件镜像：`zhoukeer-toolbox-mirror` 至 `zhoukeer-toolbox-mirror-7`。不同插件、模拟器和 GE-Proton 分散在这些仓库。
- DeckRecall 上游/作者仓库当前是 `Ren-Amamiya-pixle/DeckRecall`；注意这里账号拼写是 `pixle`。项目界面署名文字中另有 `Ren-Amamiya-pixie`，不要凭印象互换 URL。

### 4.2 Codex 账号与 Git 账号不是一回事

换 Codex/ChatGPT 账号通常不会自动转移或清除 macOS 钥匙串、SSH Key 和 `gh` 登录；但新账号不能假设权限仍在，必须执行 `gh auth status` 和只读远端检查。

当机器上同时登录两个 GitHub 账号时，发布前必须切到仓库所有者：

```bash
gh auth switch -h github.com -u zliu9732-hub
gh auth status
```

历史上 `Ren-Amamiya-pixle` 曾被设为 active，结果 Git 可以通过 SSH 推送，但 `gh workflow run` 返回 `HTTP 403: Must have admin rights`，`gh release create` 也失败。不要只看到 `git push` 成功就认为 `gh` 权限正确。

### 4.3 如果真的迁移 GitHub/Gitee 仓库所有者

仅换 Codex 账号时不要改仓库 URL。如果用户明确把仓库迁到新 GitHub/Gitee 账号，则至少要同步修改和验证：

- `git remote -v` 中的 `origin`、`gitee`、`gitee-v2`。
- README、`i`、`bootstrap.sh`、`update.sh`、`core/download_policy.sh`、`modules/network.sh`、`modules/plugin_store.sh`、`scripts/install-decky-plugin.sh` 中的所有固定 owner/repo URL。
- `.github/workflows/sync-decky-gitee.yml` 与 `scripts/sync_gitee_mirrors.sh` 的 Gitee owner。
- 新 GitHub 仓库 Actions secret：`GITEE_TOKEN`。
- GitHub Actions 的 `contents: write` 权限和工作流启用状态。
- Gitee v2 公网 raw 地址、包 SHA、分块、服务模板和安装命令。
- GitHub Release 内由本项目托管的插件资产 URL。

用下面命令搜索遗漏：

```bash
rg -n 'zliu9732-hub|Ren-Amamiya-pixle|zhoukeer-toolbox-v2|zhoukeer-toolbox-mirror' . \
  --glob '!dist/*.tar.gz' --glob '!*.zip'
```

不要把 Token 写进交接文档、命令历史、源码或截图。Actions 中的 `GITEE_TOKEN` 只能确认“存在/工作”，不能读取其值；换仓库后应在 GitHub 网页重新创建 secret。

## 5. 安装、启动与主要调用关系

主链路：

```text
Gitee 一行命令 i
  -> bootstrap.sh 下载并校验 dist/renkit.tar.gz
  -> install.sh 原子安装到 ~/.local/share/zhoukeer-toolbox
  -> launch.sh
  -> core/platform.sh / core/detect.sh 白名单识别平台
  -> SteamOS: main.sh
  -> Bazzite: main-bazzite.sh
```

国内推荐安装命令：

```bash
curl -fsSL https://jktool.icu/i | bash
```

核心目录：

- `core/`：环境、平台、下载策略、权限、安全、UI、日志。
- `modules/`：每个菜单功能模块。
- `main.sh`：SteamOS 主菜单。
- `main-bazzite.sh`：Bazzite 独立菜单。
- `assets/clover/`：Clover 配置、主题、驱动和开机修复服务。
- `third_party/`：经核验的中文前端/覆盖组件，后端原则上保持上游原版。
- `decky-installer-cn/`：Decky Loader 国内分块、清单和服务模板。
- `launcher-covers/`：启动器封面镜像清单/版本包，不进入主更新包。
- `scripts/`：打包、镜像、Steam 条目、封面、Decky RPC 等辅助脚本。
- `tests/`：macOS 上使用临时目录和 mock 命令的测试。

## 6. SteamOS/Bazzite 平台现状

### 6.1 SteamOS

- 保留完整原工具箱：国内源、软件、插件、启动器、模拟器、内存、Steamcommunity 302、双系统工具、ToDesk 等。
- SteamOS 系统级功能不得进入 Bazzite 菜单。
- 管理员密码便利模式会在用户明确选择后把密码写到桌面 `管理员密码.txt`，权限 600；诊断包必须排除它，日志不得记录密码。

### 6.2 Bazzite

- 同一安装包自动进入 `main-bazzite.sh`，名称显示为 Renkit Bazzite版。
- 用户空间软件、Flatpak/AppImage、GE-Proton、启动器、模拟器、诊断和 Decky 已适配。
- Bazzite 安装 Decky Loader 只调用官方 `ujust setup-decky`，不能套用 SteamOS 的 pacman、只读系统或服务替换流程。
- Bazzite 的 Flatpak 默认使用官方 Flathub并保留 GPG；国内源只有在显示风险、完整 URL 和 remote 名后由用户确认，且只改用户级 remote；必须保留恢复官方源入口。
- ToDesk/AnyDesk 在 Bazzite Wayland 下不作为可靠交付方案，Bazzite 菜单目前刻意不开放。
- Bazzite 上 Intel Iris Xe / GPD WIN 3 已成功安装并进入系统；不同掌机不应直接克隆同一 Bazzite 系统分区来冒充通用镜像，优先在目标机器用官方 ISO 安装，再由 Renkit 做用户空间配置。

## 7. Clover 双系统引导：已完成、真机结论和限制

### 7.1 代码已完成

- Bazzite 使用 Fedora shim；SteamOS 使用原启动路径。
- 动态识别 EFI 设备和分区，不硬编码 `/dev/nvme0n1p1`。
- 安装前备份 Clover、Windows 启动文件和 BootOrder；恢复入口可回滚。
- BootOrder 调整只把 Clover 放首位，保留 Windows、Bazzite、PXE 和其他已有项。
- Bazzite 重装到原 SteamOS 双系统盘后，会只识别指向 `steamcl.efi` 的旧 SteamOS NVRAM 项，先归档再移除；不会删系统分区。
- Bazzite 的 root-only `/boot/efi` 通过现有管理员权限通道复核。
- FAT32 写入不再使用 `cp -a`，避免所有权/权限“不允许的操作”。
- 解压时 macOS `LIBARCHIVE.xattr` 警告不再被误当临时目录。
- 临时目录不再同时保留仅大小写不同的 `cloverx64.efi`/`CLOVERX64.efi`。
- Bazzite 开机修复服务等待 `local-fs.target`，并用 `/usr/bin/bash` 启动脚本以兼容 SELinux。
- Windows 官方 `EFI/Microsoft/Boot/bootmgfw.efi` 被旧版移走时会迁回。
- 通用设备由 UEFI GOP 自动选分辨率；GPD WIN 3（`G1618-03`）请求 `1280x720` 横屏。
- 当前主题背景是 `assets/clover/zhoukeer-phantom/background.png`；升级时替换活动主题目录，避免残留旧图。

### 7.2 真机信息

- 在 GPD WIN 3（Intel Iris Xe）上，Bazzite + Windows 已成功安装并进入 Bazzite。
- Clover 曾经成功写入且菜单可用。
- 早期真机出现过 Clover 不是默认启动项、菜单竖屏、桌面“切换至 Windows”失效、开机修复服务失败。这些分别对应 BootOrder、GPD 横屏、Windows bootmgfw 恢复和 Bazzite systemd/SELinux 修复，代码已在 1.2.8/1.2.9 后处理。
- 仍应做一次当前 1.4.7 的冷启动真机回归：断电开机默认进入 Clover、横屏显示、Bazzite/Windows 都能启动、桌面切换 Windows 可用、第二次安装幂等、恢复入口有效。
- 不能因为菜单能显示就宣布完成，必须分别启动两个系统。

### 7.3 绝对不要做

- 不删除未知 EFI 目录或未知 NVRAM 项。
- 不把 Windows 启动文件替换成 Clover 文件。
- 不固定磁盘名、分区号或 GUID。
- 不把“旋转不影响使用”当最终产品标准；可以临时交付说明，但代码应按机型/GOP修正。
- 不恢复 rEFInd。

## 8. 双系统、PMFX 与互通盘经验

这部分是人工镜像方案，不等于 Renkit 已自动实现 PMFX 制作。

- PMFX 是 DiskGenius 分区备份/镜像格式，不是 Bazzite ISO。
- 用户目标是制作可恢复到 512GB 硬盘的 Windows + Bazzite 双系统模板，并可在 1TB 硬盘恢复后扩容数据区。
- 已讨论的简化方案：先恢复已有 SteamOS + Windows PMFX，删除原 SteamOS 的 Home/目标 Linux 分区，在目标设备现场用 Bazzite 官方 ISO 安装到该空间，之后用 Renkit 重装/修复 Clover并清理旧 SteamOS 引导。
- 不建议把 GPD WIN 3 的完整 Bazzite 分区直接克隆到所有不同掌机；内核本身较通用，但机型固件、控制器、旋转、HHD/输入映射和专用修复不同。Windows 同理可以进系统后补驱动，但不能保证所有机器即插即用。
- 从 1TB 制作 512GB 可恢复镜像时，要求被备份分区的布局终点和总容量落在 512GB 范围内，不是只看“已使用空间”。可把 1TB 尾部保留为未分配/临时分区，不纳入 512GB 模板。
- 典型规划曾使用：ESP、MSR、Linux 预留、Windows 约 100GB、共享 Game NTFS 约 260GB，剩余空间留给 1TB 扩容。具体数值不是代码常量，恢复前必须看目标盘实际容量。
- Bazzite 可读写 NTFS，但 Proton/Steam 游戏库放 NTFS 存在符号链接、权限、文件名、compatdata 和 Windows 快速启动/休眠脏卷风险。追求稳定时，Linux 游戏与 Proton 前缀优先放 Btrfs/ext4；NTFS 主要作为 Windows/Bazzite 共享数据盘。不要承诺所有游戏在共享 NTFS 上稳定。
- Windows 必须关闭快速启动和休眠，避免 Bazzite 挂载 NTFS 为只读或造成文件系统风险。
- 制作可克隆母盘时通常不启用 Bazzite 磁盘加密，否则恢复和跨设备管理复杂；这不是通用安全建议，只是该镜像用途的取舍。
- Bazzite 安装器必须创建本地用户；无需启用 root 账户。

## 9. Decky Loader、插件商城与国内镜像

### 9.1 Bazzite 插件范围

Bazzite 菜单已经包含官方插件分页、功能插件和掌机插件，包括：

- 小黄鸭（LSFG）、FSR4/Decky-Framegen、CheatDeck。
- DeckRecall、Freedeck、NewFreedeck、ToMoon、Unifideck。
- SteamGridDB、CSS Loader 中文版、Friendeck、Decky Music。
- 掌机功耗控制、Ally Center、HueSync、Legion Go Remapper、GPD Control、Legion Go Vibe、Legion Go 2 Fan。
- OneXPlayer Apex Tools；仅适用于明确机型，必须保留高风险提示，不能在其他掌机安装。

汉化原则：安装作者官方原包并保留后端/驱动，只覆盖同版本的 `plugin.json`、`dist/index.js` 或经核验运行组件；插件目录名、清单名和前端内部身份必须一致，否则容易空白页。

### 9.2 “显示安装成功但没装上”的旧坑

早期 Bazzite 官方商店只把请求提交成功当安装成功。现在必须轮询 Decky 已安装列表并核对目标版本；缺失、无版本或超时应返回失败。不要退回“已排队即成功”。

### 9.3 Decky 国内最新版安装命令

稳定版：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/install_latest.sh | sudo sh -s -- release
```

测试版：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/decky-installer-cn/install_latest.sh | sudo sh -s -- prerelease
```

必须把 `sudo` 放在 `sh` 前。旧写法 `curl ... | sh -s -- prerelease` 进入脚本后尝试 `exec sudo "$0" "$@"`，管道场景下 `$0` 是 `sh`，可能变成让 `sh` 打开名为 `prerelease` 的文件，从而报“没有那个文件或目录”。

### 9.4 Decky 自动镜像工作流

- `.github/workflows/sync-decky-gitee.yml` 每 6 小时运行，也支持手动触发。
- `scripts/sync_decky_gitee.sh` 获取稳定/预发布元数据，下载 PluginLoader，验证 GitHub Release digest，下载服务模板，按 8MiB 分块，全部成功后才原子替换工作区。
- GitHub 临时 503、元数据不全或校验失败时，当前逻辑保留上一套已校验镜像并以 warning 正常退出，避免定时任务连续发失败邮件或留下半套文件。
- 推 Gitee 时必须克隆 `zhoukeer-toolbox-v2` 当前历史，仅 sparse checkout `decky-installer-cn` 后创建普通提交；不能再把 GitHub `main` 直接推到 Gitee。

历史两次不同故障：

1. 旧工作流把 GitHub main 推到已分叉 Gitee，报 `non-fast-forward (fetch first)`。修复：基于 v2 当前历史同步单目录。
2. 修复后一次运行遇到 GitHub 上游 `503`。修复：重试、使用 Actions token降低匿名限流，并在上游临时失败时保留旧镜像。

2026-08-13 最近两次 Decky 同步任务均成功；接手时用：

```bash
gh run list --repo zliu9732-hub/zhoukeer-toolbox \
  --workflow sync-decky-gitee.yml --limit 10
```

## 10. Gitee 分块镜像与体积限制

- Gitee Raw 单文件按 9MiB 安全上限管理，项目分块通常为 8MiB。
- 主更新包 `dist/renkit.tar.gz` 必须小于等于 `9,437,184` 字节。
- `zhoukeer-toolbox-mirror` 曾接近/超过配额，不要继续无计划塞大文件。
- mirror-2～7 分担 GE-Proton、模拟器和插件。推新镜像前先核对脚本映射，不要随便换仓库。
- `scripts/seed_gitee_local_asset.sh` 在部分克隆后必须先恢复索引/读取现有树；旧实现没有 `read-tree HEAD`，曾把镜像仓库其他目录一起删除。
- 自动镜像脚本不能先清空整个仓库，只能替换目标 id/version 目录。
- 下载器先校验每块 SHA，再重组并校验完整 SHA；任一步失败回退上游，不执行不完整文件。
- ShadPS4、Yuzu、Cemu、DuckStation、PCSX2、RPCS3 已有国内分块，模拟器本体不包含游戏、BIOS、固件或密钥。

## 11. 版本规则

- 正式版本必须是三段纯数字 `主.次.补丁`。
- 补丁位只允许 0～9；例如 `1.4.9` 的下一版必须是 `1.5.0`，禁止 `1.4.10`。
- 历史 `1.3.10` 是已发布兼容例外，不能删除、覆盖或改写；它之后已正确进入 `1.4.0`。
- 自动更新测试必须保留 `1.3.10 -> 1.4.0` 兼容断言，并增加 `1.3.10 -> 当前版`。
- 升版至少同步：`VERSION`、`core/env.sh`、README 当前版本、CHANGELOG、相关配置/测试中的固定版本，以及两个正式包。
- 不允许只改 Gitee `VERSION` 而不更新包，或只更新包而不更新 `dist/SHA256SUMS`。

## 12. 测试与发布包

### 12.1 macOS 测试边界

运行任何测试前先检查它只使用临时目录、mock 命令和本地 fixture。确认无真实联网、提权、systemd、EFI 或磁盘操作后：

```bash
find . -type f -name '*.sh' -not -path './.git/*' -print0 | \
  while IFS= read -r -d '' file; do bash -n "$file" || exit 1; done
bash tests/run.sh
git diff --check
```

修改单模块时先跑相关测试，交付前仍要跑全部 `tests/run.sh`。测试输出 `FAIL` 时必须非零退出，不能打印失败后返回 0。

### 12.2 打包

```bash
bash scripts/deploy_release.sh
```

战网/黑盒独立一行引导与独立打包流程已在 Renkit 2.0.5 退役；主工具箱内原有战网和黑盒工坊功能保持不变。

`deploy_release.sh` 只生成和检查包，不会自动提交。`scripts/package_release.sh` 只打包 Git 已跟踪文件，这一点非常重要：

- 不要依赖 `.gitignore` 下只存在于本机的 `dist/index.js` 或图片。
- FSR4、LSFG、CSS Loader等运行组件必须被 Git 跟踪，并在 `VERIFY_FILES` 中校验。
- 曾经用 `git archive HEAD` 同步 v2 时，GitHub 没跟踪的汉化前端构建文件从 v2 快照消失；之后 v2 已重新跟踪。任何同步都要检查这些文件仍在包内。
- macOS AppleDouble `._*` 和扩展属性必须排除，否则 SteamOS 可能把 `._xxx.sh` 当脚本。

包检查示例：

```bash
tar -xOf dist/renkit.tar.gz ./VERSION
shasum -a 256 dist/renkit.tar.gz
cat dist/SHA256SUMS
tar -tzf dist/renkit.tar.gz | rg '(^|/)\._' && echo '错误：含 AppleDouble'
```

## 13. 完整发布流程（对齐 1.4.7 后使用）

1. 确认 active GitHub 账号为 `zliu9732-hub`。
2. 获取 GitHub/Gitee v2 最新状态并确认没有版本分叉。
3. 最小修改，更新版本和 CHANGELOG。
4. 跑全部 Bash 语法、相关测试和 `tests/run.sh`。
5. 生成 Renkit 包，核对版本、SHA、体积和必要文件；不生成已退役的战网/黑盒独立包。
6. `git status`/`git diff` 人工复核；只 `git add` 本次文件。
7. 提交后推 GitHub `main`；禁止 force push、rebase 已发布历史或 `git push --tags`。
8. 只创建当前版本的 annotated tag 并单独推送，例如 `git push origin v1.4.8`。
9. 创建 GitHub Release，只上传版本化 Renkit 包及其 `.sha256`。
10. 在临时 Gitee v2 clone 中，用 GitHub 已提交树替换 v2 跟踪树并普通提交；禁止 force push。
11. 如果只更新 Decky 分块，使用现有 sparse 单目录工作流，不做全树快照。
12. 公网回读 `VERSION`、`dist/SHA256SUMS`、`dist/renkit.tar.gz`、`decky-installer-cn/latest.txt` 和 `launcher-covers/latest.txt`。
13. 实际下载 Gitee 更新包，核对完整 SHA和包内 VERSION。
14. 查看两个 Actions 工作流最近运行：Decky v2 同步与 Gitee mirror 资产同步。
15. 只有 GitHub、Gitee v2、Release、包 SHA 和公网回读全部一致，才能宣布“发布完成”。

GitHub Release 示例：

```bash
gh release create v1.4.8 \
  dist/renkit-1.4.8.tar.gz \
  dist/renkit-1.4.8.tar.gz.sha256 \
  --repo zliu9732-hub/zhoukeer-toolbox \
  --title 'Renkit 1.4.8' \
  --notes '一句面向用户的变更说明'
```

如果 `gh release create` 或 `gh workflow run` 返回权限错误，先检查 active 账号，不要重复生成标签或改历史。

## 14. 启动器、封面与 Proton 的旧坑

- `shortcuts.vdf` 非 Steam 游戏条目必须写入 Steam 认可的 appid；名称、exe、StartDir 变化后要重算。
- 封面写入前要探测 Steam 实际 AppID；必要时覆盖候选 ID。
- 竖版 Capsule 应为 600×900，Wide Capsule 不能复用竖图；1.4.3 已修成独立 920×430 横图。
- 启动器封面应先完整准备，再原子替换；下载失败不能先删旧封面。
- `launcher-covers` 包必须放在 `launcher-covers/<version>/launcher-covers.tar.gz`，不能放根目录，否则下载器 404。
- 封面缓存标记变更后，旧用户需运行“修复启动器封面”刷新。
- Proton 映射内部名称曾见 `proton_10`，但真机实际可用名称可能不同；若自动映射不生效，先读 `config.vdf` 和 Steam当前工具名，不要盲改所有启动器。
- 战网/黑盒在真机手动选择 Proton 10.0-4 后曾正常运行。
- 更详细记录见 `docs/steam-cover-compat-handover.md`；其中仍有用户本地未提交修改，接手时不要覆盖。

## 15. 安装系统过程中出现过但不属于 Renkit 代码的坑

- DiskGenius 创建/删除分区后必须点“保存更改”；曾因没保存，Bazzite 安装器仍看到空间不足。
- Bazzite Anaconda 出现 `Unable to create PID file`，通常是上次实例未正常退出或强制重启后的残留；不要连续启动多个安装器。
- 安装器 `Initializing` 或最后脚本可能长时间无进度；先等待和查看错误，不要只因数字不动就断电。
- DISM 应用 WIM 曾在 62% 长时间不变，按键后继续；无错误时可以继续等，但最终必须看到“操作成功完成”和成功创建启动文件。
- Bazzite Live ISO 安装阶段主要读 U 盘本地内容，但首次启动和最后更新会访问网络；国内网络慢时可用可靠热点/加速，但不能把“剩余 1 秒”当卡死依据。
- 安装器屏幕键盘在 GPD WIN 3 上可能遮挡界面；外接键鼠或重进安装器比乱点安全。
- 自定义分区时只能格式化明确预留给 Bazzite 的分区；EFI 使用现有 ESP 挂载 `/boot/efi`，不得格式化 Windows/Game。

## 16. 目前优先待办

按优先级：

1. 对齐 Gitee v2 1.4.7 到 GitHub主源码，补 GitHub `v1.4.7` Release，消除双源版本分叉。
2. 用当前版本在 GPD WIN 3 做 Clover 冷启动回归：默认项、横屏、Windows/Bazzite、Windows 桌面切换、开机修复服务和恢复。
3. 在真实 Bazzite 验证 1.4.7 的插件组合：CSS Loader 中文前端、FSR4 683 条清单、DeckRecall v0.3.2、SteamGridDB、Friendeck、Decky Music。
4. 验证 Bazzite 下插件“安装成功”必须对应实际插件目录和 Decky 列表，不是仅提交请求。
5. 在 SteamOS 真机验证 1.4.7 新机初始化 18 项，尤其四个 GE-Proton、302就绪检测和可选战网/Ubisoft/黑盒流程。
6. 完成 512GB PMFX 原型时，先做一台测试盘，不把尚未跨机验证的 Bazzite 分区宣传成全掌机通用镜像。
7. 保持 Decky/Gitee 两个定时工作流连续成功；偶发上游 503只应 warning 并保留旧镜像。

## 17. 当前工作区用户文件，必须保留

写本文时工作区有下列未提交/本地文件。它们可能属于用户其他任务，不得因为清理仓库而删除：

- `docs/steam-cover-compat-handover.md` 的本地修改。
- `.agents/`（包含本地 Renkit 开发/安全审计技能）。
- `.pet-runs/`、`desktop-pet/`、`assets/codex-pet-girlfriend.png`。
- `create_exam_first4.py`、`create_math_exam.py`、`create_polynomial_practice.py`。
- `dist/Ally-Center-zh-v1.2.0.zip` 及副本。
- `dist/一键安装Decky插件.sh`。
- `scripts/__pycache__/`。

不要使用 `git clean`、`git reset --hard` 或递归删除工作区。本文不包含任何密码/Token，可以提交；根目录 `HANDOFF.md` 是指向本文的入口。

## 18. 用户已经明确的产品决定与协作方式

这些是本轮长期开发里用户已经明确确认过的方向。新账号不要反复从零追问，也不要擅自改回相反方案：

- Renkit 用同一条安装命令，根据 SteamOS/Bazzite 自动进入对应版本；两套菜单和高风险实现保持独立，不能破坏原 SteamOS 功能。
- 实际目标平台就是 SteamOS 与 Bazzite，不需要为了理论上的其他 Linux 发行版增加复杂交互；但未知平台仍要安全失败，不能误跑磁盘/系统命令。
- Bazzite 版优先同步用户空间、安全且已有成熟实现的功能；SteamOS 专属 pacman、只读系统、ToDesk 等不能硬搬。
- Clover 的安装、修复、旧 Renkit/Clover 文件清理、旧 SteamOS NVRAM 项清理应合并在同一套双引导流程中；所有清理都必须先备份，只删除明确属于 Renkit/旧 SteamOS 的目标。
- Clover 主题升级必须删除活动主题中的旧背景后再写新图，不能让旧文件残留；当前指定背景是 `assets/clover/zhoukeer-phantom/background.png`。
- 不再维护或恢复 rEFInd。
- 用户是 DeckRecall 作者；维护本项目内 DeckRecall 中文适配时无需再次向用户追问其本人授权，但第三方依赖、其他插件和上游资产仍要遵守各自许可证。
- 掌机插件只要上游真实存在、机型适配边界清楚，就可以进入 Bazzite 插件页；OneXPlayer 相关工具必须保留明确机型警告。
- 插件、模拟器和 Decky Loader 应优先使用已校验的 Gitee 分块镜像，失败再回退上游；不能为了“国内源”牺牲 SHA、版本一致性或原子替换。
- 版本号严格按三段数字和补丁位 0～9推进；不存在 `1.2.10` 这类新版本。历史 `1.3.10` 只能兼容，不能复制这种命名继续发布。
- PMFX 的现实交付策略是复用已有 Windows/SteamOS 双系统模板，再在目标机器删除明确的旧 Linux/Home 分区并用官方 ISO现场安装 Bazzite，最后让 Renkit 覆盖/修复 Clover；当前不把 Bazzite 系统分区本身当全掌机通用镜像。
- 对真机安装、分区、EFI等现场指导要一次只给一个明确步骤，先根据用户新截图确认结果，再给下一步；不要在用户疲劳时同时给多套互相冲突的分区方案。
- GPD WIN 3 桌面触控错位曾由 KDE 默认 180% 缩放引起，改为 100% 后恢复；遇到同类问题先查缩放，不要直接判定触摸驱动损坏。
- Bazzite 系统区约 100GB 在“不安装 Steam 游戏，只放系统、Proton和着色器”的前提下可用；共享游戏区和母盘尺寸仍按实际需求规划。
- 用户更看重能交付、能回滚、真机确实可启动，不接受仅凭脚本输出或菜单出现就声称成功。

沟通时优先给结论和当前唯一下一步。代码修改可以完整验证，但给正在操作真机的用户不要一次堆太多文字。

## 19. 分支与历史处理注意事项

- `main` 是正式维护分支；发布版本必须最终落到 `main`。
- 写本文时远端还可能存在 `codex/steam302-inspect` 等检查分支，它们不是新版主线，也不能替代 Gitee v2 的 1.4.7 源码。
- 不要把旧分支强推到 `main`，不要为了“让历史好看”重写已发布提交。
- GitHub 与 Gitee v2 对齐时，以文件内容审计和普通提交保留差异，不以某个旧分支名或旧聊天中的提交号为准。
- 仅更新交接文档不需要为了凑版本发布运行包；任何运行代码、包内容或用户可见功能变化才进入正常升版/发布流程。

## 19.1 2026-08-19 小黄鸭/FSR4 完整包与账号隔离

- 小黄鸭已基于上游 `0.12.8` 新 i18n 架构重新构建完整中文前端，不再使用 `0.12.5` 前端伪装版本号。
- 小黄鸭与 FSR4 的 Renkit 版本均为完整 Decky ZIP，保留官方 `bin/`、`py_modules/`、后端、运行资源与许可证；署名只显示 `RenAmamiya`。
- Renkit 安装固定使用 `zhoukeer-toolbox-mirror-3`：
  - `lsfg-zh-signed/v0.12.8`，2 个 8 MiB 分块。
  - `fsr4-zh-signed/v0.17`，24 个 8 MiB 分块。
- 工具箱禁止回退 GitHub 或本地内置覆盖层；Gitee 镜像失败时必须保留现有插件并返回失败。
- 旧小黄鸭与 FSR4 本地覆盖源码已从安装包链路移除，发布包不再携带两套旧组件。
- 独立发布包与 Renkit 署名仓库必须完全隔离：独立包本身不写署名，公开说明只描述“完整中文插件”，不得出现“未署名”、Renkit、Renkit 账号或双方关系；Renkit 代码和文档也不得引用独立发布仓库。
- Gitee v2 与 GitHub 的部分同名历史标签指向不同提交；接手时对 Gitee v2 使用 `git fetch --no-tags gitee-v2 main`，禁止覆盖或改写已发布标签。

仍需在真实 SteamOS/Bazzite 验证：小黄鸭 `0.12.8`、FSR4 `0.17` 的分块下载、Decky 安装/重载、旧版迁移与新机初始化组合。macOS 不能代替此项。

## 19.2 2026-08-19 短域名与界面背景

- `jktool.icu/i` 继续优先下载 Gitee v2 的 `bootstrap.sh`；只有入口脚本获取或校验失败时，才依次尝试 GitHub Raw 与 `jktool.icu/bootstrap.sh`。这项回退不改变任何插件的 Gitee 清单、分块重组或严格失败逻辑。
- 短入口会在执行前拒绝空文件、符号链接、超过 1 MiB 的响应、HTML/403 错误页和 Bash 语法错误；测试覆盖 Gitee 成功短路及 Gitee 失败、GitHub 返回 HTML、域名成功的顺序。
- `assets/background.jpg` 已替换为 `1586×992` 黑红极简几何背景，与红色桌面图标呼应；灰原哀和全部人物元素已移除，中央及左侧保留终端菜单留白。
- Renkit 对外显示的创作者与汉化署名统一为 `RenAmamiya`，不得再附加 GitHub 用户名或“闲鱼”。

## 20. 最后检查清单

新账号开始实际改代码前，应能回答：

- 当前用户真正收到的版本是 GitHub 还是 Gitee v2 的哪一版？
- `gh` active 账号是否有仓库 admin/release/workflow 权限？
- 本次修改属于 SteamOS、Bazzite还是两边共用？是否会跨平台误调用？
- 修改是否触碰 EFI、磁盘、管理员权限、系统服务或关闭 GPG？若是，中文确认和回滚在哪里？
- 下载地址、大小、SHA、格式与回退是否完整？
- 相关测试是否完全模拟？全量测试是否通过？
- 发布包是否只包含 Git 跟踪文件且无 AppleDouble/凭据？
- GitHub main、tag、Release、Gitee v2 VERSION、包 SHA 是否一致？
- 真机验证做了什么，哪些仍只是模拟？

只要其中一项答不上来，就不能宣布功能或发布完成。
