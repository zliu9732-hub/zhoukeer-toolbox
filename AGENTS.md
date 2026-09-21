# Renkit长期开发规则

## 项目边界

1. 项目名称为“Renkit”，目标平台是 Steam Deck / SteamOS、Bazzite 与 ChimeraOS，主要语言为 Bash。
2. 开发电脑是 macOS。macOS 上只能进行静态检查、语法检查和模拟测试；禁止执行 SteamOS 安装、修复、网络、权限、Flatpak、pacman、systemctl、EFI 或磁盘操作。
3. 小黄鸭优先使用上游官方自带中文的完整插件包，保留原作者与许可证，通过 Gitee 分块清单下载；不得添加非上游署名。
4. 只有 Renkit 实际进行汉化的插件才显示 `RenAmamiya` 汉化署名；上游官方中文包不得添加该署名。
5. 发现高风险问题时先报告，不得擅自执行危险修复。

## 命令与配置安全

1. 禁止使用 `eval`、`bash -c`、`sh -c` 执行动态命令。
2. 禁止直接 `source` 用户可编辑的配置文件；配置必须使用严格白名单解析。
3. 禁止硬编码 `/Users/joker`、`/home/deck`、固定磁盘或个人路径。
4. 禁止提交密码、Token、API Key、SSH 密钥、Cookie 或其他凭据。
5. 下载文件必须检查 HTTP 错误、超时、文件类型和完整性；不能把 HTML、404 页面当成脚本或压缩包执行。
6. 高风险功能必须有中文说明、明确确认、日志、错误处理和安全退出。

## 功能约束

1. rEFInd 功能当前停用，不得重新暴露入口。
2. 国内 Flatpak 源功能保留；关闭 GPG 验证前必须显示风险、远程名称和 URL，并取得明确确认，同时提供恢复官方源的入口。
3. 小黄鸭优先使用上游官方自带中文的完整插件包，保留原作者与许可证，通过 Gitee 分块清单下载；不得添加非上游署名。
4. 只有 Renkit 实际进行汉化的插件才显示 `RenAmamiya` 汉化署名；上游官方中文包不得添加该署名。
5. 独立发布的完整中文插件与 Renkit 署名仓库必须彻底隔离：包内不得带 Renkit 署名，仓库描述、README、Release 标题和文案不得标注“未署名”，不得引用、暗示或链接 Renkit、其创作者或其发布仓库；Renkit 也不得引用独立发布仓库。
6. ChimeraOS 必须使用独立菜单，只允许用户级应用和已有插件环境中的插件安装；插件商城本体由系统自带功能维护。禁止在 ChimeraOS 暴露 pacman、frzr、系统服务替换、系统调优、双系统、互通盘、Clover、EFI 或磁盘操作。
7. Renkit 2.3.6 发布完成后，停止维护 Bazzite 与 ChimeraOS 版本；后续默认只开发、检查和测试 SteamOS 主线。除非用户明确点名，不再读取、修改或测试 `main-bazzite.sh`、`main-chimera.sh` 及其平台专用功能。

## 版本规则

1. Renkit 正式版本必须使用 `主版本.次版本.补丁版本` 三段纯数字格式。
2. 补丁版本只允许 `0` 到 `9`；`x.y.9` 的下一版必须是 `x.(y+1).0`，禁止再发布 `x.y.10` 或更大的补丁号。
3. `1.3.10` 已作为历史兼容版本发布，不得删除、覆盖或改写；其下一正式版本必须是 `1.4.0`，自动更新必须保证已安装 `1.3.10` 的用户可以正常升级到 `1.4.0`。

## 测试与交付

1. 禁止测试框架打印 `FAIL` 后仍返回退出码 0。
2. 修改 Shell 文件后必须运行全部 `bash -n` 和相关测试。
3. 在 macOS 上运行测试前，必须先确认测试完全使用模拟命令，不会联网、提权或执行真实系统操作。
4. 功能修改完成并通过规定检查后，应完成 commit、push 和常规发布；禁止 force push、修改 Git 历史或执行真实系统操作。

## 发布前验证

1. 发布完成的标准是 Gitee v2 更新源可访问、可校验；GitHub 推送成功不等于发布完成。
2. 推送 `main` 后必须实际请求以下 Gitee v2 地址，并确认版本号、SHA256 和更新包均与本次发布一致：
   - `https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/VERSION`
   - `https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/dist/SHA256SUMS`
   - `https://gitee.com/zliu9732-hub/zhoukeer-toolbox-v2/raw/main/dist/renkit.tar.gz`
3. Gitee v2 历史不一致时，只能通过新增同步提交或其他非 force push 方式补齐；在 Gitee v2 校验通过前不得宣布发布成功。
4. 出现更新失败时，必须记录根因并在发布前复验对应更新源，避免同一类发布遗漏再次发生。
5. Gitee v2 仅作为自动更新源：只允许同步 `VERSION`、`dist/SHA256SUMS`、`dist/renkit.tar.gz` 与 `dist/zhoukeer-toolbox.tar.gz`。不得把完整开发仓库、历史发布包或无关资源推入该仓库。
6. Gitee 拒绝推送并提示仓库容量/配额时，先记录服务器返回的容量与错误；不得 force push、改写历史或删除线上引用来绕过限制。确认 GitHub `main` 和当前版本 tag 均已可恢复后，必须取得明确确认才可在 Gitee 执行“存储库 GC”。
7. 存储库 GC 完成后，必须以新增同步提交重新推送 `main`，并再次实际请求第 2 条列出的三个地址；版本号、`SHA256SUMS` 与下载包 SHA256 三者完全一致才算恢复发布能力。

## 默认发布方式

1. 用户所说的“提交并发布”“推送发布”或同义要求，默认且仅指：完成必要检查、生成发布包、提交改动、推送 GitHub `main`、推送当前版本 tag、等待 Gitee v2 自动同步，并按“发布前验证”实际校验 Gitee v2 更新源。
2. 除非用户明确要求“创建 GitHub Release”或“上传 GitHub Release 附件”，不得创建、编辑或发布 GitHub Release，不得打开 GitHub Release 网页上传附件，也不得把普通 Git 推送擅自扩展成 GitHub Release 操作。
3. 默认发布流程使用项目现有 Git 凭据和 `git` 命令；不得仅为普通提交、推送或发布安装、恢复或登录 GitHub CLI（`gh`）。只有用户明确要求使用 `gh` 或明确要求 GitHub Release 且现有方式无法完成时，才可处理 `gh`。
4. 不得因为工具偏好重复已完成的发布步骤。GitHub `main`、版本 tag 与 Gitee v2 已验证一致后，应立即报告结果，避免无关网页操作、重复上传和额外 Token 消耗。
