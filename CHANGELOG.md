## Renkit 1.9.8 暂停问题插件入口 — 2026-08-21

- 暂时隐藏沉浸式翻译的触控菜单与 GUI 安装入口，避免在尚未完成 Steam Deck 真机稳定性复验前继续安装。
- 从 SteamOS、Bazzite 和 GUI 的 Decky 官方插件页及整组推荐安装清单中移除 ProtonDB Badges；已安装的插件不会被 Renkit 自动删除。

## Renkit 1.9.7 沉浸式翻译升级至官方 0.9.1 — 2026-08-21

- 沉浸式翻译由过时的 0.8.0 升级为官方最新 0.9.1，包含新版 SteamOS 布局、商店与媒体层输入、Python 运行时和屏幕捕获兼容修复；保留完整简体中文界面与 `RenAmamiya` 汉化署名。
- 中文包直接以官方 0.9.1 Release ZIP 为底，仅替换校验后的中文前端与清单，并内置官方固定 SHA256 的完整依赖归档；旧 0.8.0 会被版本、前端、后端和依赖四重校验强制升级。
- 0.9.1 完整包继续从 Gitee 分块源下载，清单固定在 mirror-3；分块跨 Gitee 镜像仓库承载，任一分块或整包校验失败时保留现有插件。

## Renkit 1.9.6 游戏数据插件运行依赖修复 — 2026-08-20

- 修复沉浸式翻译 mirror-3 中文包漏装 0.8.0 官方后端依赖，导致 Decky 后端持续崩溃并表现为插件商城反复重启的问题；修正版完整包内置固定 SHA256 的官方依赖归档。
- 安装器新增后端文件与依赖归档校验：已经安装 1.9.5 坏包的设备会自动识别缺失依赖并强制重装，不会因为版本号仍为 0.8.0 而跳过。
- SteamDB 游戏数据后端切换到当前 Decky 的 `decky_plugin` 模块名，并纳入后端哈希校验；两款修正版仍只通过 Gitee mirror-3 分块下载，失败时保留现有插件。

## Renkit 1.9.5 游戏模式数据与沉浸式翻译 — 2026-08-20

- 插件第二页新增“游戏数据与翻译”子菜单，可安装 SteamDB 游戏数据中文版，在游戏商店页查看价格史低与在线峰值。
- 新增沉浸式翻译中文版，可翻译 Steam Deck 游戏兼容性评价与屏幕文字；界面固定为简体中文，并统一显示 `RenAmamiya` 汉化署名。
- 两个完整插件包均固定通过 Gitee mirror-3 分块清单下载、重组并校验 SHA256；镜像失败时保留现有插件，不使用 GitHub 或本地覆盖层回退。

## Renkit 1.9.4 插件后端连接与兼容层菜单修复 — 2026-08-20

- 修复小黄鸭与 FSR4 修改 `plugin.json` 外显名后，前端仍用旧英文身份连接 Python 后端，导致小黄鸭无法检测 Lossless Scaling、FSR4 无法安装 OptiScaler 并显示 Python error 的问题；后端、运行库和安装脚本保持上游原文件。
- 两个署名完整包继续只走 Gitee mirror-3：小黄鸭保持 2 个分块，FSR4 保持 24 个分块；下载、重组和校验逻辑不变，仅同步修正版完整包、分块和固定 SHA256。
- “修改器所需常用兼容层”新增子菜单，可单独安装 GE-Proton 7-55、8-25、9-27、10-29，第五项保留原来的四款全部安装。
- Epic 与育碧准备安装环境时会识别自定义 Steam 库中的 Proton Experimental/10.0-4，避免兼容层已安装仍重复打开 Steam 安装页并等待。

## Renkit 1.9.3 插件名称升级判定 — 2026-08-20

- 修复已安装 1.9.1 插件时仅凭版本号与前端哈希跳过更新的问题；带署名小黄鸭与 FSR4 现在还会严格核对 `plugin.json` 外显名。
- 旧英文名称会触发从原有 Gitee mirror-3 分块源重新安装，新名称分别固定为“小黄鸭”和 `Decky-Framegen（FSR4）`。
- 保持两份完整包、SHA256、镜像 ID、分块数量和下载逻辑不变，仅补强本地幂等检测与升级路径。

## Renkit 1.9.2 Decky 插头列表名称修复 — 2026-08-20

- 修复带署名小黄鸭与 FSR4 完整包的 `plugin.json` 仍保留英文名称，导致 Decky 插头列表显示英文、进入插件后才显示中文的问题。
- 小黄鸭外显名统一为“小黄鸭”，FSR4 外显名统一为 `Decky-Framegen（FSR4）`；插件目录、后端、中文界面与 `RenAmamiya` 署名保持不变。
- 两个完整包继续只使用 Gitee mirror-3 分块清单下载；镜像 ID、版本、文件名、分块数量和下载逻辑均保持不变，仅更新包 SHA256 与对应分块。

## Renkit 1.9.1 小黄鸭与 FSR4 展示名称 — 2026-08-19

- 小黄鸭界面顶部显示 `RenAmamiya汉化`，Decky 插头菜单与标题显示“小黄鸭”；插件目录、清单和后端身份保持上游原值。
- FSR4 的 Decky 插头菜单与标题由 `Decky-Framegen` 调整为 `Decky-Framegen（FSR4）`，其余插件文件与功能不变。
- 小黄鸭继续使用 2 个 mirror-3 分块，FSR4 继续使用 24 个 mirror-3 分块；下载、重组和校验代码不变，仅同步新包及四项固定 SHA256。

## Renkit 1.9.0 小黄鸭固定中文界面 — 2026-08-19

- 修复小黄鸭 0.12.8 中文包仍跟随 Steam 界面语言、在英文 Steam 环境下整页回退英文的问题；中文包现在固定使用简体中文。
- 仅更新小黄鸭完整 ZIP、固定 SHA256 与 mirror-3 的两块内容；Gitee 分块数量、大小、下载、重组及校验逻辑保持不变。

## Renkit 1.8.9 Decky 与新机流程紧急修复 — 2026-08-19

- 旧版小黄鸭/FSR4 汉化覆盖配置改为静默退役，升级时自动清理，不再在每个安装项目前重复报警。
- 网络诊断只跟踪、等待和回收自身探测进程；用户中断后先终止后台探测，再删除临时目录，避免后续出现 `/tmp/...` 文件不存在。
- Decky Loader 保持既有 Gitee 版本判断、分块下载、逐块校验、重组和回退逻辑；分块完成后恢复服务模板下载进度，避免界面长时间无提示。
- ROG Ally / Ally X 自动配置在插件目录缺失时先补装 Decky Loader，再从既有 mirror-3 镜像安装 Ally Center 中文版。

## Renkit 1.8.8 小黄鸭/FSR4 完整署名包固定 Gitee 分块 — 2026-08-19

- 小黄鸭改用上游 0.12.8 新 i18n 架构重新汉化，补齐中文词条，不再使用 0.12.5 前端只改版本号。
- 小黄鸭与 FSR4 均改为带 `RenAmamiya` 署名的完整 Decky ZIP，固定从 Gitee mirror-3 分块下载；镜像失败时保留现有插件，不回退 GitHub 或本地覆盖层。
- 清理发布包中的小黄鸭 0.12.5 与 FSR4 旧本地覆盖源码，并补充严格 Gitee 失败返回非零的模拟测试。
- 独立完整中文插件的公开仓库与 Renkit 署名发布完全隔离，公开文案只描述完整插件，不标注署名状态或双方关系。
- 修复 `jktool.icu/i` 短安装入口：默认补齐 GitHub Raw 与域名自身回退，并在逐源尝试时拒绝 HTML、超大响应和 Shell 语法错误。
- 工具箱背景改为与红色桌面图标呼应的黑红极简几何设计，移除灰原哀及其他人物元素，并保留菜单文字所需的低对比留白。

## Renkit 1.8.7 小黄鸭 0.12.8 镜像切换 mirror-3 — 2026-08-19

- 小黄鸭官方 v0.12.8 分块镜像上传到 `zhoukeer-toolbox-mirror-3`，安装不再出现“镜像清单校验值与当前固定版本不一致”。
- 删除 Gitee 旧版 v0.12.5 小黄鸭镜像，安装流程完全使用 v0.12.8。

## Renkit 1.8.6 小黄鸭更新 0.12.8 并拆分中文组件仓库 — 2026-08-19

- 小黄鸭官方升级到 v0.12.8；工具箱开始拆分独立中文组件。
- Decky-Framegen 中文组件独立到 `zliu9732-hub/decky-framegen-zh`，版本号和原作者信息与上游一致。
- 安装流程改为官方原版 + 独立中文组件叠加，不改变菜单入口和新机初始化流程。

## Renkit 1.8.5 发布包补齐 MAKO 英文替换表 — 2026-08-19

- 修复 1.8.4 发布包遗漏 `data/mako_zh_en.json`，导致安装 MAKO 时提示“英文替换表缺失”的问题。

## Renkit 1.8.4 MAKO 全量英文界面替换为中文 — 2026-08-19

- 在 MAKO 前端中直接替换 192 条英文界面文本为简体中文，不再依赖 MAKO 自带多语言机制。

## Renkit 1.8.3 MAKO 强制使用中文界面 — 2026-08-19

- MAKO 汉化不再跟随 Steam 系统语言，补丁内强制切换为简体中文，并保留顶部署名。

## Renkit 1.8.2 修复 MAKO 汉化前端异常 — 2026-08-19

- 修复 MAKO 汉化补丁插入 React 元素后导致插件加载异常的问题；署名改为在现有面板内追加，并通过 `node --check` 验证前端语法。

## Renkit 1.8.1 MAKO 分块镜像固定 mirror-3 — 2026-08-19

- MAKO 安装与自动同步固定使用 `zhoukeer-toolbox-mirror-3`，避免主镜像仓库超配额后回退 GitHub 慢速下载。

## Renkit 1.8.0 MAKO 尝鲜版修复与独立汉化 — 2026-08-19

- 修正 MAKO 安装包来源为 `eugeniosegala/MAKO`，资产名匹配 `MAKO-Decky-v*.zip`，解决“最新 Release 元数据获取失败”。
- MAKO 安装到独立 `Mako` 目录，不再覆盖旧版小黄鸭；安装后注入完整简体中文词条，并在界面顶部保留 RenAmamiya汉化署名。
- Gitee 分块镜像同步同步改为 MAKO 官方仓库，更新版本后自动上传分块镜像。

## Renkit 1.7.9 小黄鸭新增 MAKO 尝鲜版 — 2026-08-19

- 小黄鸭安装改为版本选择子菜单：保留 v0.12.5 旧版汉化，新增 eugeniosegala/MAKO 的 MAKO 尝鲜版；尝鲜版安装官方运行核心后叠加 Renkit 汉化，顶部署名沿用 RenAmamiya。
- MAKO 尝鲜版继续走 Gitee 分块镜像优先、GitHub Release 回退，并在上游更新版本后由同步流程上传分块镜像。

## Renkit 1.7.8 左下角 Steam 菜单白字黑边 — 2026-08-17

- 三个主题针对左下角 Steam 菜单 Logo：字母强制白色、黑色描边，菜单背景使用主题底色，不再出现黑色残留。

## Renkit 1.7.7 全面修复主题菜单黑色残留 — 2026-08-17

- 三个主题统一扩大修复：所有菜单表面强制使用主题底色，所有 Logo/HeaderLogo/Steam 相关 SVG 强制白色，不再出现左下角黑色或 steam 字母变黑。

## Renkit 1.7.6 独立粉白渐变主题与 Steam logo 修复 — 2026-08-17

- 独立出“粉白渐变”（Pink White Gradient）主题，保留 1.7.4 的浅粉白渐变效果；Handheld Pink 保持深粉版。
- 三个主题统一修复 Steam 菜单左下角 “steam” 字母变黑的问题，并强制 UI 根背景使用主题底色，避免黑色残留。

## Renkit 1.7.5 粉色主题加深与 Steam logo 修复 — 2026-08-17

- Handheld Pink 粉色加深并扩大粉色覆盖面，保留渐变观感；ROG White 与 Handheld Pink 同步修复左下角 Steam logo 被压黑的问题。

## Renkit 1.7.4 新增 掌机 Pink 粉色主题 — 2026-08-17

- 新增 Handheld Pink 粉色主题：基于 ROG White，白底全部替换为粉色，其余布局与规则不变；在 Decky Loader 子菜单提供独立安装入口。

## Renkit 1.7.3 ROG White 修复 logo/头像/手柄图消失 — 2026-08-17

- ROG White 升级到 v1.4.5：Steam logo、右上角头像、游戏 logo 与手柄/控制器图片保持原色且背景透明，不再被白色规则遮盖；键位小图标仍为黑色。

## Renkit 1.7.2 一键切换 Windows 优先选择官方启动项 — 2026-08-17

- 一键切换 Windows 时优先选择路径为 `\EFI\Microsoft\Boot\bootmgfw.efi` 的官方 Windows Boot Manager 启动项，避免误选到 Clover 相关入口后仍进入 Clover。

## Renkit 1.7.1 切换 Windows 一键直达 — 2026-08-17

- “切换至 Windows”桌面快捷方式不再要求输入 `WINDOWS` 二次确认，双击后直接设置 BootNext 并重启进入 Windows；仅保留终端中的风险提示。

## Renkit 1.7.0 切换至 Windows 图标改为圆形 — 2026-08-17

- “切换至 Windows”快捷方式图标由桌面 `switchtowin.png` 生成圆形版本，替换 `assets/windows-switch.png`；功能与操作逻辑不变。

## Renkit 1.6.9 更换切换至 Windows 快捷方式图标 — 2026-08-17

- 将桌面的 `switchtowin.png` 替换为 `assets/windows-switch.png`；“切换至 Windows”桌面快捷方式图标更新，功能与操作逻辑不变。

## Renkit 1.6.8 ROG White 修复游戏内菜单黑色栏 — 2026-08-16

- ROG White 升级到 v1.4.4：改用 `mainmenuapprunning_*`、`mainpanelapprunning_*` 当前精确类名强制白色背景，修复“继续游戏 / 控制器详情 / 查看游戏详情”栏目仍为黑色的问题。

## Renkit 1.6.7 更换 Renkit 圆角图标 — 2026-08-16

- 使用桌面 `image.png` 生成新的圆角 Renkit 图标，替换 `assets/icon.png`、`assets/icon-round.png` 与 `assets/icon-toolbox-deck.png`。
- 更新后强制重建桌面与应用菜单快捷方式，避免继续显示旧图标。

## Renkit 1.6.6 修复 Clover 背景目录未找到 — 2026-08-16

- “应用 Renkit 开机背景”自动查找已存在的 Apocalypse 主题目录（不区分大小写）；找不到时只创建该目录并放入背景图，不修改其他 Clover 文件。

## Renkit 1.6.5 恢复应用 Renkit 开机背景入口 — 2026-08-16

- 重新加入独立入口“应用 Renkit 开机背景”，仅替换已存在的 `esp/efi/clover/themes/Apocalypse/background.png`，不创建目录、不修改其他 Clover 文件。

## Renkit 1.6.4 仅安全替换 Clover 背景图 — 2026-08-16

- 修正 Clover 背景替换：只在已存在的 `Apocalypse` 主题目录中替换 `background.png`，不创建目录、不修改其他 Clover 文件。

## Renkit 1.6.2 修复游戏启动 Steam logo 消失 — 2026-08-16

- ROG White 升级到 v1.4.3：游戏启动转圈页、加载模板和启动详情统一改为白色背景，Steam logo、转圈图标和启动图标强制黑色，避免白色背景下 logo 隐形。

## Renkit 1.6.1 游戏内 Steam 菜单全面白色化 — 2026-08-16

- ROG White 升级到 v1.4.2：游戏内 Steam 按钮菜单、应用覆盖层、指南、截图、手柄设置和键位界面统一改为白色背景。
- 键位图标、手柄设置图标和 Steam 按键提示强制改为黑色，避免白色背景下看不清；Decky 插头保护继续保留。

## Renkit 1.6.0 修复 ROG White 启用后 Decky 插头消失 — 2026-08-16

- ROG White 升级到 v1.4.1：新增 Decky 插头图标保护规则，白色主题下强制把 Quick Access 中的 FaPlug 图标恢复为深色，并清除可能隐藏图标的滤镜。
- 安装完成提示补充说明：若启用主题后 Decky 插头或插件商城消失，请完全退出并重新进入 Steam，这是 Decky Loader 已知的 QAM 标签丢失问题。

## Renkit 1.5.9 新增 ROG White 白色主题 — 2026-08-16

- 游戏与插件新增“安装 ROG White 白色主题”：Renkit 内置 ROG White v1.4.0，安装时只把 `theme.json` 与 `shared.css` 放入 CSS Loader 的 `themes` 目录，SHA256 校验后原子替换；启用仍在 CSS Loader 中完成。
- Decky Loader 触控与 GUI 子菜单同步新增入口，并提供 `install`、`status`、`uninstall` 子命令；重复执行幂等，带 SteamOS/Bazzite 平台保护与 CSS Loader 依赖检测。

## Renkit 1.5.8 修复“仅改名”插件空白页与功能失效 — 2026-08-16

- 修复 SteamGridDB（游戏封面更换）、Friendeck（文件传输助手）、Decky Music（音乐播放器）打开空白页、无法传文件、播放异常的问题。
- 根因：旧版把 plugin.json 的 name 改成中文，导致 Decky 插件目录名、清单名与前端内部身份不一致；新版恢复官方名称，仅保留工具箱菜单中的中文名。
- 已安装旧版中文名插件的用户再次运行安装或常用插件组合会自动恢复官方名称，不改动官方后端、版本和前端。

## Renkit 1.5.7 HMCL 改用 Gitee 分块镜像下载 — 2026-08-15

- HMCL 启动器与 Temurin JRE 21 下载改为项目原有 Gitee 分块镜像优先，镜像缺失或校验失败才回退 GitHub 加速链路与官方源。
- 新增 HMCL 与 Temurin JRE 的 Gitee 镜像清单和定时同步条目，后续镜像工作流会自动更新分块。

## Renkit 1.5.6 HMCL 下载接入 GitHub 加速链路 — 2026-08-15

- HMCL 启动器安装不再直连 GitHub 官方下载，改为复用 Renkit 统一下载链路：按实际测速优先使用 GitHub 加速代理/国内镜像，官方源兜底，SHA256 与文件格式校验不变。
- 同步更新启动器下载回归测试，防止后续改回慢速直连。

## Renkit 1.5.5 游戏与插件新增 Linux 原生 HMCL 启动器 — 2026-08-15

- 游戏与插件新增“HMCL 启动器”：自动下载官方 HMCL 与 Temurin JRE 21，校验 SHA256 后安装到用户目录，创建桌面入口并加入 Steam 库；全程无需管理员权限。
- HMCL 为 Linux 原生 Minecraft 启动器，中文界面；首次运行登录 Microsoft 账号并安装对应版本后即可游玩。
- 同步更新下载白名单：HMCL 官方 GitHub Release 与 Temurin JRE 官方 Release 均纳入受控来源。

## Renkit 1.5.4 新机初始化不再批量安装精选插件 — 2026-08-14

- 新机初始化移除“Decky 精选官方插件”批量安装步骤，不再自动安装 27 款精选插件；Decky Loader、FreeDeck 与七款常用插件仍按原流程安装。
- 新机初始化计划文案与机器配置提示同步移除“精选官方插件”描述；游戏与插件菜单中的“常用插件加27款精选插件”入口保持不变。
- 同步对齐运行时版本：`VERSION`、`core/env.sh`、README 与自动更新回归夹具统一到 1.5.4。

## Renkit 1.5.3 汉化署名补全 — 2026-08-14

- 工具箱内置的汉化插件统一恢复大号与闲鱼署名：`RenAmamiya`。
- 覆盖小黄鸭、FSR4、掌机功耗控制、Ally Center、CSS Loader 中文前端及五款掌机插件的前端与描述。
- 原作者、许可证和硬件后端保持不变；同时修复常用功能插件组合中 SteamGridDB、CSS Loader、Friendeck、Decky Music 单独安装入口静默失败的问题。

## Renkit 1.5.2 DeckRecall 下载运行时修复 — 2026-08-13

- DeckRecall 固定版本更新到 v0.4.2，修复 Decky Loader 的 PyInstaller 临时 OpenSSL 环境污染系统 `curl`，导致小黄鸭、FSR4 与 GE-Proton 下载后统一显示失败的问题。
- DeckRecall 安装固定使用已验证的 Gitee `zhoukeer-toolbox-mirror-3` 镜像，失败仍回退作者 GitHub Release；版本、大小与 SHA256 校验保持不变。
- 已安装 Renkit 1.5.1 的 DeckRecall v0.4.1 默认配置会安全迁移到 v0.4.2；其他插件、菜单与安装逻辑不变。

## Renkit 1.5.1 多源更新链修复 — 2026-08-13

- `jktool.icu` 现在默认参与版本比较并选择最高可用版本，避免 Gitee 主仓库因历史体积超额停留在旧版本时阻断后续更新；其他更新逻辑保持不变。
- 同步修正运行时显示版本；1.5.0 的 Windows 桌面快捷切换、插件排版、DeckRecall 0.4.1 与汉化署名修正保持不变。

## Renkit 1.5.0 Windows 快捷切换与插件下载修复 — 2026-08-13

- “切换至 Windows”入口改为只创建桌面快捷方式，本次操作绝不设置 BootNext 或重启；用户以后主动打开桌面图标、输入 `WINDOWS` 二次确认后，才会切换并重启。
- 插件第一页收紧布局，FSR4 与 Freedeck 连续显示，不再空一行；DeckRecall 与 SavePulse 仍位于第二页。
- DeckRecall 固定回退更新到 v0.4.1：绕过 SteamOS Python 证书链故障，下载和 API 请求改用严格 TLS 的系统 curl；接入 Gitee 分块镜像、最新版 GE-Proton，并修复 EXE/目录选择无反应。
- Renkit 汉化插件的公开署名统一为 `RenAmamiya`，保留原作者与开源许可证。

## Renkit 1.4.9 DeckRecall EXE 入库与 SavePulse 自动识别 — 2026-08-13

- DeckRecall 固定回退更新到 v0.4.0：可选择 Windows 安装 EXE，借助 Steam Proton 完成安装后识别主程序并入库，也可选择已解压的非 Steam 游戏目录，自动排序候选游戏 EXE、设置 Proton 并创建桌面快捷方式；不自动套用不可信封面。
- SavePulse 更新到 v0.2.0-alpha.1：补接管所有正在运行的 Steam 会话，集成 Ludusavi 社区清单识别 19,000 多款游戏的存档路径，支持非 Steam 游戏稳定身份、加密 WebDAV 换机恢复、删除状态版本和写入重试；14.6 MB 作者包使用 Gitee 分块镜像优先，失败才回退 GitHub Release。
- 自动迁移 Renkit 旧版内置的 DeckRecall v0.3.2 与 SavePulse v0.1 Alpha 固定配置；两项插件仍位于插件第二页，固定 Release 包继续执行 SHA256 与 ZIP 结构校验。

## Renkit 1.4.8 SavePulse 与插件菜单排序 — 2026-08-13

- 新增 SavePulse 安装入口，固定使用作者公开 GitHub Release v0.1.0-alpha.1，并校验 SHA256、ZIP 安全路径与插件目录后原子安装；SteamOS 与 Bazzite 均可使用。
- DeckRecall 与 SavePulse 一起移到插件第二页靠前位置；第一页保留官方插件浏览和常用项目，第二页的启动器入口合并为独立子菜单，保持触控按钮尺寸。
- SavePulse 使用每位用户自己的坚果云或标准 WebDAV，不依赖作者公共账号；云端存档包使用独立恢复口令加密。

## Renkit 1.4.7 FSR4 清单与主题美化安装修复 — 2026-08-13

- 修复 1.4.6 发布包虽然包含 683 款 FSR4 官方兼容游戏清单，但安装器未复制 `data` 目录，导致已更新用户仍提示“清单缺失或条目数异常”的问题。
- 安装器新增 FSR4 清单与 CSS Loader 中文前端运行文件复制，并加入真实安装目录回归测试；更新到 1.4.7 后重新安装或检测到 FSR4 会正常生成桌面清单。

## Renkit 1.4.6 新机初始化、常用插件与 FSR4 清单 — 2026-08-12

- 新机初始化扩展为 18 项客户交付流程：默认安装 Epic、FreeDeck、常用软件、Decky、常用插件、修改器所需 GE-Proton 7-55／8-25／9-27／10-29、虚拟内存与 Steamcommunity 302；战网、Ubisoft Connect、黑盒工坊可在开始前选择。
- 新机初始化彻底移除 ToDesk 安装及相关说明；独立 ToDesk 工具保持原样，不影响已有用户单独使用。
- 常用插件组合新增 SteamGridDB、CSS Loader、Friendeck 与 Decky Music：SteamGridDB 仅显示为“游戏封面更换”；Friendeck、Decky Music 仅显示为“文件传输助手”“音乐播放器”，不改前端、署名或其他文件。
- CSS Loader v2.1.2 显示为“主题美化”并叠加完整中文前端，官方后端保持原包；四款插件全部使用固定版本、SHA256、国内镜像优先、上游回退与原子安装。
- FSR4 安装后生成的桌面兼容清单改用 OptiScaler 官方 Wiki 2026-08-07 快照：记录上游 685 个可工作条目，去重并按既有要求排除《怪物猎人：荒野》后列出 683 款，同时写明 Steam Deck RDNA2、Proton/VKD3D、Mesa、DX11/Vulkan 与反作弊限制。
- Renkit 更新脚本新增只检测模式，供新机初始化真实联网核对版本，不下载或覆盖现有安装。

## Renkit 1.4.5 DeckRecall v0.3.2 下载与错误显示修复 — 2026-08-12

- DeckRecall 固定回退更新到官方 v0.3.2 轻量包，并使用 Release 提供的 SHA256；旧 v0.2.8／v0.3.1 默认配置会在 Renkit 更新时安全迁移。
- 取消 DeckRecall 的过期 Gitee v0.2.8 镜像清单路由，65 KB 插件包直接使用官方 GitHub Release 与既有线路回退，不再先显示“镜像清单校验值不一致”。
- 安装前读取实际插件目录中的版本并进行三段语义版本比较；同版或更高版本跳过重复下载，v0.2.8 会正确更新到 v0.3.1。
- 修复 Decky RPC 嵌套异常被统一显示为“发生了意外错误”；检测更新和虚拟内存现在会显示具体的中英双语失败原因。
- DeckRecall v0.3.1 起已内置新版下载与浏览器处理，Renkit 不再对新版套用只适用于旧前端的兼容补丁。

## Renkit 1.4.4 Decky Gitee 自动镜像修复 — 2026-08-12

- 修复定时任务把 GitHub `main` 直接推送到已分叉的旧 Gitee 仓库，持续触发 `non-fast-forward` 失败邮件的问题。
- Decky 自动镜像改为克隆当前 `zhoukeer-toolbox-v2` 的 Gitee 历史，只同步 `decky-installer-cn` 目录并创建普通提交；不 force push、不覆盖 Gitee 历史。
- 新增工作流静态回归检查，防止镜像地址退回旧仓库或再次直接推送分叉历史；Decky 稳定版与测试版安装逻辑不变。
- 同步修正运行时显示版本，使其与正式发布版本保持一致；自动更新继续兼容历史 `1.3.10` 用户。

## Renkit 1.4.3 启动器横向胶囊图比例修复 — 2026-08-11

- 修复 Epic、战网、育碧、黑盒工坊把 600×900 竖版封面同时写入 Steam `grid_l / Wide Capsule` 横向槽位，导致横屏封面被放大裁切的问题。
- 四张横向胶囊图改为由现有 1920×620 横幅素材无 AI 裁切生成的 920×430 图片；600×900 竖图只写入竖版胶囊槽位，Logo、Hero、背景、桌面图标和启动器入库逻辑均未修改。
- 封面缓存标记升级为 v8，镜像素材升级到 1.1.3；旧用户更新后运行“修复启动器封面”即可强制刷新横图。
- 自动更新验证覆盖 `1.3.10 → 1.4.0` 与 `1.3.10 → 1.4.3`。

## Renkit 1.4.2 DeckRecall Steam 浏览器调用修正 — 2026-08-11

- 纠正 1.4.1 把 DeckRecall 改用系统默认浏览器的错误方向；桌面模式已验证可下载的是 Steam 浏览器，本版改为直接调用与 Renkit 现有兜底链路一致的 `SteamClient.Browser.OpenUrl`。
- 已经执行过 1.4.1 DeckRecall 修复的用户再次安装时，会识别并迁移错误的 `OpenInSystemBrowser` 代码，不需要手动删除插件；官方 v0.2.8 原始调用和 1.4.1 错误调用都只进行一次精确替换。
- `Navigation.NavigateToExternalWeb` 仅在 Steam Browser API 缺失时作为兼容回退，修复完成后自动重载 Decky。
- 自动更新验证覆盖 `1.3.10 → 1.4.0` 与 `1.3.10 → 1.4.2`；游戏启动器入库、Steam 条目、封面代码及素材未改动。

## Renkit 1.4.1 DeckRecall 下载浏览器修复 — 2026-08-11

- DeckRecall 的“打开风灵月影官网”不再固定使用 Steam 游戏模式内置浏览器；安装时会对已核验的唯一调用点做原子兼容修复，优先使用 Decky/Steam 提供的系统默认浏览器接口，避免下载 EXE 或压缩包时一直卡住。
- 系统浏览器接口不可用时才保留原内置浏览器作为兼容回退；重复安装会识别已经修复的前端文件，不会反复改写。
- DeckRecall 首次安装和已有完整安装仍会重载 Decky，解决插件文件已下载但右侧菜单不显示的问题。
- 自动更新回归测试继续覆盖 `1.3.10 → 1.4.0`，并新增 `1.3.10 → 1.4.1` 直接升级，未先启动 1.4.0 的用户也能获取当前修复版。
- 游戏启动器入库、Steam 条目、封面代码及素材未改动。

## Renkit 1.4.0 DeckRecall 显示修复与版本规则 — 2026-08-11

- 修复 DeckRecall 安装完成后安装状态被子 Shell 隔离，外层未重启 Decky Loader，导致插件文件已经下载但右侧插件菜单不显示的问题。
- 已经下载过 DeckRecall 的用户可以再次执行安装；Renkit 会确认插件目录完整并强制重载 Decky，无需先删除插件。若系统服务无法自动重载，会明确提示完全退出再重新进入游戏模式。
- 正式版本补丁位今后严格限制为 0～9，`x.y.9` 的下一版必须进位为 `x.(y+1).0`；保留已发布的 `1.3.10` 作为历史兼容桥，并加入 `1.3.10 → 1.4.0` 自动更新回归测试。
- 游戏启动器入库、Steam 条目、封面代码及素材未改动。

## Renkit 1.3.10 Steam 加速有效性检测与主机加速入口 — 2026-08-11

- Steamcommunity 302 不再把“systemd 进程仍在运行”直接当成加速成功；现在会继续检查官方 `S302.run` 就绪标记，或本地 DNS 53 与代理 80/443 监听，未真正就绪时明确引导打开一次官方配置界面完成证书和 DNS 初始化。
- 安装或更新 302 后会显式重启Renkit托管的后台服务，避免旧进程仍显示 active、实际继续占用已替换程序的问题；重置与状态页也执行相同有效性检查。
- Steam 加速菜单新增奇游、迅游、网易UU主机加速入口。三家目前均无 SteamOS 原生客户端，因此只打开各自官方主机加速安装/配置页面，并说明使用手机 App、路由插件或加速盒；不会下载 Windows 安装包或通过 Wine 伪装安装成功。
- 游戏启动器入库、Steam 条目和封面代码及素材未改动。

## Renkit 1.3.9 微信桌面图标修复 — 2026-08-11

- 修复微信官方 AppImage 安装完成后桌面快捷方式使用不存在的 `wechat` 主题图标，导致 KDE 桌面只显示空白或通用图标的问题。
- Renkit 内置已核验的微信官方默认图标，快捷方式改用随更新包存在的绝对路径；新安装、重复安装和“修复桌面图标”都会补齐，不需要重复下载微信。
- 图标随 GitHub Release 和 Gitee v2 的 Renkit 更新包分发，不新增单独图标镜像；游戏启动器入库和封面代码及素材未改动。

## Renkit 1.3.8 一键安装模拟器与官方图标 — 2026-08-11

- SteamOS、Bazzite 触控菜单和桌面 GUI 新增“一键安装 6 款”，依次安装 Yuzu、Cemu、DuckStation、PCSX2、RPCS3、ShadPS4；已完整安装的项目会跳过，单项失败会汇总并继续后续安装。
- 一键安装继续复用各模拟器原有的 Gitee 分块镜像优先、GitHub 回退、固定 SHA256、ELF 格式校验、桌面入口和 Steam 入库流程；不包含游戏、BIOS、固件或密钥。
- 六张 AI 生成的模拟器图标全部替换为各项目官方默认图标，并固定来源提交与文件 SHA256；PPSSPP、mGBA 继续使用 Flatpak 官方图标，Azahar 继续使用用户本地程序图标。
- 游戏启动器入库、Steam 条目和封面代码及素材未改动。

## Renkit 1.3.7 新密码单次中文输入 — 2026-08-11

- 确认当前用户没有系统密码后，只显示一次中文新密码输入；Renkit通过本地伪终端自动完成系统 `passwd` 的两次确认，不再显示英文 `New password / Retype new password`。
- 密码只经标准输入和伪终端传递，不进入命令参数、环境变量或日志；系统拒绝密码时不生成桌面记录。
- 启动器入库、Steam 条目和封面代码及素材未改动。

## Renkit 1.3.6 管理员密码状态识别 — 2026-08-11

- “我还没有管理员密码”会先只读检查当前用户密码状态；只有确认无密码时才进入新密码设置，已有密码不再误入 `Current password` 英文失败流程。
- 已有密码时引导使用“我已有管理员密码”，密码锁定或忘记旧密码时停止操作并提供现有重置教程；不绕过 SteamOS 强制重置系统密码。
- 启动器入库、Steam 条目和封面写入代码未改动。

## Renkit 1.3.5 启动器封面安全修复 — 2026-08-11

- 启动器封面改为先完整准备六类新素材，再原子替换 Steam grid 文件；下载、素材或写入任一步失败时保留原有封面，不再先删除旧图留下空白。
- Epic、战网、育碧、黑盒工坊的 v2 公网封面包已复核，24 张素材、尺寸、包大小和 SHA256 均与清单一致。

## Renkit 1.3.4 强制刷新启动器封面缓存 — 2026-08-10

- 封面缓存标记升级为 `.covers-ready-v7`，旧安装更新后会自动重新下载已恢复的 v2 封面镜像，不需要手动删除缓存。
- 更新后重新执行“修复启动器封面”或重装战网启动器，桌面图标和 Steam 库封面会恢复。

## Renkit 1.3.3 恢复启动器封面镜像 — 2026-08-10

- 恢复 v2 自动更新仓库中缺失的 `launcher-covers` 镜像（版本 1.1.2），战网、Epic、育碧、黑盒工坊的桌面图标与 Steam 库封面重新可下载；该目录此前已从主仓库和 v2 丢失，本次重新纳入发布包和 v2 快照，避免下次同步再次丢失。
- 已安装用户更新后重新执行“修复启动器封面”或重装战网启动器即可刷新封面与图标。

## Renkit 1.3.2 镜像仓库恢复与 seed 修复 — 2026-08-10

- 修复 Gitee 分块镜像仓库 mirror-2/3/5/6/7 在推送模拟器分块时意外丢失旧插件与 GE-Proton 内容的问题；旧提交中的原文件已完整恢复，模拟器分块同时保留，所有 `latest.txt` 与分块已公网回读。
- `scripts/seed_gitee_local_asset.sh` 在部分克隆后先 `read-tree HEAD` 再添加新 id，后续镜像推送会保留仓库已有分块，不再覆盖其他镜像内容。
- Ally Center 等插件的 Gitee 镜像恢复可用；下载逻辑未改动，GitHub 回退行为保持不变。

## Renkit 1.3.1 模拟器 Gitee 分块镜像 — 2026-08-10

- 修复 ShadPS4（PS4 模拟器）无法从 GitHub Release 下载的问题；Yuzu、Cemu、DuckStation、PCSX2、RPCS3、ShadPS4 六款 AppImage 模拟器全部改为 Gitee 8MiB 分块镜像优先，镜像仓库按模拟器拆分到 mirror-2～mirror-7，SHA256、大小和 ELF 格式校验通过后才回退 GitHub Release。
- 模拟器安装仍只安装模拟器本体，不包含游戏、BIOS、固件或密钥；镜像文件保持上游未修改的固定 AppImage。
- License 清单同步更新六款模拟器的镜像授权说明；DuckStation 仅分发自有 Release 中未修改的固定 AppImage，保留 CC BY-NC-ND 署名与许可要求。

## Renkit 1.3.0 Bazzite 汉化插件与安装结果校验 — 2026-08-10

- Bazzite 的 Decky 菜单新增完整功能插件分页：除小黄鸭、FSR4 与 CheatDeck 外，还可安装 DeckRecall、Freedeck、NewFreedeck、ToMoon、Unifideck，以及现有掌机控制插件和 OneXPlayer Apex Tools；SteamOS 原菜单保持不变。
- DeckRecall 作者已明确授权 Renkit 建立国内镜像；DeckRecall 与 OneXPlayer Apex Tools 均使用 Gitee 镜像优先、固定版本与 SHA256 校验，失败才回退作者 GitHub Release。
- CheatDeck 固定基线更新到 v2.0.0，DeckRecall 固定回退版本更新到 v0.2.8；自动解析最新正式版的逻辑保持不变。
- 修复 Bazzite 菜单安装“掌机功耗控制”汉化版时被旧 SteamOS-only 版本检测误拦截的问题；汉化前端继续复用上游原生后端。
- Bazzite 缺少 Decky Loader 时只调用官方 `ujust setup-decky`；不会执行 SteamOS 的 Decky 服务替换、pacman 或只读系统操作。
- 官方 Decky 插件不再把“请求已排队”显示成安装成功：提交后轮询 Decky 已安装列表并核对目标版本，缺失、商店无版本或超时均明确返回失败，重新执行会跳过已经完成的插件。

## Renkit 1.2.9 Bazzite 旧 SteamOS 引导自动清理 — 2026-08-10

- Bazzite 的“安装/修复 Clover 双系统引导”会识别旧 `steamcl.efi`，先归档到 EFI 内的 Renkit 备份目录，再删除对应的旧 SteamOS NVRAM 项；不增加独立按钮，也不删除任何系统分区。
- Bazzite Clover 配置自动移除失效的 SteamOS 菜单项，只保留 Bazzite 与 Windows；SteamOS 版 Clover 流程保持原样。
- 清理只匹配指向 `steamcl.efi` 的启动项，最多处理 8 项；失败时尝试恢复启动文件与入口，重复安装会继承原备份记录，恢复 Clover 时也会还原被归档的 SteamOS 引导。
- 新增临时 EFI/NVRAM 模拟测试，验证 Windows、Bazzite、Clover 均不会被误删，并覆盖重复执行和恢复流程。

## Renkit 1.2.8 GPD WIN 3 Clover 横屏与默认启动修复 — 2026-08-10

- GPD WIN 3（G1618-03）安装 Clover 时单独请求 `1280x720` 横屏 GOP 模式，其他掌机继续使用自动分辨率。
- Bazzite 的 Clover 开机修复服务改为等待本地文件系统，并通过系统 Bash 启动脚本，规避 SELinux 对 systemd 配置目录脚本直接执行的限制。
- 保留 Windows 官方启动文件与 NVRAM 启动项；升级时自动修复旧版移走的 `bootmgfw.efi`，恢复桌面“切换至 Windows”。
- Clover 主题背景替换为当前 1536×1024 深色 Renkit 图；升级仍整体替换活动主题目录，不会残留旧背景。

## Renkit 1.2.7 Clover FAT32 文件名兼容 — 2026-08-10

- 修复 Linux 临时目录同时包含 `cloverx64.efi` 与 `CLOVERX64.efi`，复制到不区分大小写的 FAT32 EFI 时提示“文件已存在”的问题。
- Clover 启动文件改为通过临时名称安全改名，EFI 中只写入一个标准大写文件名。
- 新增回归测试，禁止准备阶段再次复制仅大小写不同的 Clover EFI 文件。

## Renkit 1.2.6 Clover FAT32 复制兼容 — 2026-08-10

- 修复向 FAT32 EFI 分区复制 Clover 时，`cp -a` 尝试保留 Linux 所有权和权限并连续报“不允许的操作”的问题。
- EFI 写入改为普通递归复制；仍保留临时目录、原 Clover 备份、失败清理和原启动文件不修改的保护流程。
- 模拟测试明确禁止 Clover 安装路径再次使用 `cp -a`。

## Renkit 1.2.5 Clover Linux 解压警告兼容 — 2026-08-10

- 修复 Linux `tar` 输出 macOS 扩展属性警告时，警告文字被误当成 Clover 临时目录并触发“文件名过长”的问题。
- Clover 临时目录改为使用Renkit已知的固定工作路径；解压真正失败时仍显示错误并保证 EFI 未修改。
- 模拟测试加入 `LIBARCHIVE.xattr` 警告，确认不会再污染安装路径。

## Renkit 1.2.4 Bazzite Clover 管理员验证 — 2026-08-10

- 修复 Bazzite 独立菜单未先准备管理员密码记录，导致 1.2.3 无法完成 root-only EFI 复核的问题。
- 安装、状态和恢复 Clover 前统一验证管理员权限；Bazzite 尚未录入或记录失效时，会明确要求输入一次当前账户密码，验证失败不修改 EFI。
- 新增完全模拟的 Bazzite 管理员密码录入测试；SteamOS 原有首次使用流程保持不变。

## Renkit 1.2.3 Bazzite EFI 权限兼容 — 2026-08-10

- 修复 Bazzite 将 `/boot/efi` 设为仅 root 可读取时，Clover 错误提示“挂载位置不含 EFI 目录”的问题；只读探测会通过Renkit现有管理员权限通道复核。
- Clover 安装、状态、Windows 启动文件识别和恢复流程统一兼容受保护的 EFI 目录；磁盘、分区、BootOrder、确认和回滚规则保持不变。
- 新增 root-only EFI 模拟测试；macOS 测试只调用模拟命令，不访问真实 EFI 或磁盘。

## Renkit 1.2.2 Clover 自动分辨率 — 2026-08-09

- SteamOS 与 Bazzite 安装 Clover 时不再把 Steam Deck、ROG Ally、Legion Go 等机型的固定分辨率写入 EFI，改由 Clover 根据当前掌机固件提供的 UEFI GOP 显示模式自动选择。
- 机型识别、专用 EFI 驱动、默认系统、主题、Windows 备份、BootOrder 和恢复流程保持不变；只在写入前生成的临时配置中安全移除固定分辨率字段。
- 新增 SteamOS 与 Bazzite 模拟断言，确保最终 Clover 配置不含 `ScreenResolution`；全部相关测试只操作临时目录和模拟命令。

## Renkit 1.2.1 Bazzite Clover 双系统引导 — 2026-08-09

- Bazzite 独立高级菜单新增 Clover 安装、状态与恢复入口；仍不接入 SteamOS 的 pacman、只读系统、ToDesk、内存调优或其他通用 EFI 功能。
- Clover 支持 Bazzite 的 Fedora shim 启动器，并为未知 Bazzite 掌机/迷你主机提供不加载机型专用驱动的通用配置；默认启动项可选择 Bazzite 或 Windows。
- EFI 分区、磁盘与分区号改为动态识别，不再固定 `/dev/nvme0n1p1`；开机修复只把 Clover 放到首位，保留 Windows、PXE 和其他现有 BootOrder 项。
- 重写 Clover 开机修复服务，移除 `sudo`、`bash -c` 和 EFI 变量删除操作，状态日志迁移到 root 管理的 `/run/renkit`；恢复 Clover 时同步停用并移除修复服务，SteamOS 原菜单与设备配置保持不变。
- 新增完全模拟的 Bazzite Iris Xe 通用设备、EFI 第 7 分区、Windows 文件备份及 BootOrder 保留测试；macOS 测试不会访问真实 EFI、磁盘或 systemd。

## Renkit 1.2.0 Bazzite 用户空间功能扩展 — 2026-08-09

- Bazzite 常用软件由 16 项扩展到 31 项；新增百度网盘、WiliWili、Fcitx5、Xbox 云游戏、音乐、下载、截图、办公、笔记和 Parsec 等官方 Flathub 应用，继续默认走用户级官方 Flathub。
- 新增 Bazzite 分类卸载菜单，可移除常用软件、四款游戏启动器、九款模拟器、当前 GE-Proton 和 Renkit；系统级 Flatpak 明确交给 Bazzite 自带工具，Renkit 不调用 sudo 卸载。
- GE-Proton 增加最新版与修改器常用四版本选择；Yuzu 增加本人合法备份密钥的导入与只读状态页。
- Decky 官方插件支持整组推荐或逐个浏览安装，只向本机 Decky 官方商店提交请求，不接入 SteamOS 专用插件商城模块。
- 检查与维护新增软件状态、桌面图标修复、中文兼容攻略、掌机快捷键、外接设备只读检查和操作记录导出；Bazzite 列表继续排除 ToDesk 与 AnyDesk。

## Renkit 1.1.9 Bazzite Flatpak 下载源隔离 — 2026-08-09

- Bazzite 软件安装默认使用带 GPG 签名验证的官方 Flathub，不再自动配置国内镜像；SteamOS 原有国内源与安装流程保持不变。
- Bazzite 使用准备新增独立的 Flatpak 下载源菜单：明确显示关闭 GPG 验证的风险、远程名称和完整 URL，用户主动确认后才启用上海交大与中科大镜像。
- Bazzite 国内源的启用与恢复只修改用户级 Flatpak 远程，不调用 sudo、不修改系统更新源；恢复官方源时重新启用 GPG 验证。
- 新增 Bazzite 官方安装、手动国内源、恢复官方源、旧系统级远程隔离和普通 Fedora 拒绝执行的模拟测试。

## Renkit 1.1.8 SteamOS / Bazzite 独立双平台版 — 2026-08-09

- 同一条安装命令自动分流：SteamOS 保持原有 `main.sh` 和全部现有功能，其他 Linux 使用独立的 `main-bazzite.sh`，两套菜单互不调用对方的系统功能。
- Bazzite 首期开放常用 Flatpak/AppImage、GE-Proton、Epic/战网/育碧/黑盒工坊、Steam 入库与封面、九款模拟器、网络诊断和安全清理。
- Bazzite 的 Decky Loader 只调用官方 `ujust setup-decky`，不执行 pacman、steamos-readonly、SteamOS 通道选择或服务替换；系统调优、ToDesk、EFI/Clover 等入口暂不开放。
- 新增 SteamOS/Bazzite 平台解析、启动分流、Bazzite Decky 模拟与发布防漏包测试；`/etc/os-release` 改为白名单读取，不作为 Shell 执行。

## Renkit 1.1.7 插件商城系统通道识别修复 — 2026-08-09

- 修复“根据系统版本安装插件商城”只读取 `/etc/os-release`，导致 SteamOS 测试或预览通道也总被识别为 stable 的问题。
- 新版优先读取 `atomupd-manager tracked-branch`，兼容旧系统的 `steamos-select-branch -c`，最后才使用系统版本文件兜底；稳定分支安装稳定版，beta/main/preview/staging 分支安装测试版。
- 只调整通道识别，不改变 Decky 下载、校验、服务切换、插件保留和国内源回退逻辑。

## Renkit 1.1.6 掌机控制插件中文套装 — 2026-08-09

- “掌机控制插件”扩充为七项：新增通用掌机 RGB、Legion Go 控制中心、GPD 控制中心、Legion Go 震动控制和 Legion Go 2 风扇控制，并统一使用中文插件名。
- HueSync 沿用上游完整简体中文；其余四款完成中文前端并加入 RenAmamiya署名，保留原作者信息和官方硬件控制后端。
- 五款插件均使用 Gitee mirror-3 静默分块下载、固定 SHA256 与 GitHub Release 回退；新增 tar.gz 安全解压支持、机型限制和风扇控制风险提示。
- 安装器白名单与发布包校验显式包含全部五套前端组件，并新增官方后端保留、重复安装幂等、ZIP/tar.gz 分支及防漏打包测试。

## Renkit 1.1.5 Ally 控制中心组件随更新安装 — 2026-08-09

- 修复 1.1.4 更新成功后，正式安装目录未复制 Ally 控制中心中文组件、安装插件提示“中文组件不完整”的问题。
- 主安装器只新增 Ally 中文清单、版本、许可证和已构建前端的复制白名单；发布打包增加必需文件检查，其他更新与插件安装逻辑不变。

## Renkit 1.1.4 Ally 控制中心中文名称 — 2026-08-09

- Decky 插件显示名与工具箱菜单统一改为“Ally 控制中心”，保留官方安装目录以兼容旧版升级。
- 中文插件清单名与前端内部身份同步更新，继续校验中文前端 SHA256，避免名称不一致导致插件打开空白；原版硬件控制后端不变。

## Renkit 1.1.3 Ally Center 中文版 — 2026-08-09

- 新增“掌机控制插件”子菜单，保留原有“掌机功耗控制”，并加入适用于 ROG Ally / Ally X 的 Ally Center v1.2.0。
- Ally Center 的 RGB、TDP、风扇、CPU、电池、下载模式和设备信息界面完成中文化，并加入与小黄鸭一致的汉化署名；硬件控制后端保持作者原版。
- 下载保持 Gitee mirror-3 国内源优先、固定 SHA256 校验和 GitHub Release 自动回退；分块细节静默，已安装英文版或旧版再次执行会替换为已校验的中文版。

## Renkit 1.1.2 黑盒工坊兼容手动战网与横向 Logo 再缩小 — 2026-08-09

- 黑盒工坊预装包改为先在独立临时目录中解压并检查，再写入现有战网环境；客户手动安装的战网即使包含正常链接也不会再被误判，压缩包自身的异常链接仍会被拦截。
- Epic、战网、育碧和黑盒工坊的 Steam 横向 Logo 从约 55% 再缩小到约 32%；桌面图标、横幅背景、竖版封面和启动器安装逻辑保持不变，封面缓存标记升级为 v6。
- 战网安装完成后提示用户从右侧手柄图标把右触控板行为改为“用作鼠标”。

## Renkit 1.1.1 启动器横向 Logo 比例修复 — 2026-08-08

- Epic、战网、育碧和黑盒工坊新增独立的 Steam 横向 Logo 素材：保留官方桌面图标不变，仅通过透明留白把详情页 Logo 的显示尺寸统一缩小到原来的约 55%。
- 封面缓存标记升级为 v5；旧用户重新安装启动器或运行“修复启动器封面”即可刷新，不改变启动器安装、Steam 入库或其他封面逻辑。

## Renkit 1.1.0 Freedeck 双版本与功耗控制署名 — 2026-08-08

- Freedeck 改为双版本子菜单：保留 0.6 稳定版，并新增独立的 NewFreedeck v0.1；新版使用 mirror-3 分块镜像、固定 SHA256，并明确提示上游部分功能尚未完成。
- “掌机功耗控制”主界面新增与小黄鸭一致的两行可见署名：汉化与原作者说明，以及金色居中的汉化账号。
- 插件商城仍保持 Gitee 分块镜像优先与原有回退顺序，仅静默分块下载过程提示。

## Renkit 1.0.9 Freedeck 探测提示修复 — 2026-08-08

- Freedeck 固定安全版本可以正常安装时，静默上游最新 Release 资产不兼容的探测提示；真实安装错误仍会正常显示。

## Renkit 1.0.8 启动器旧封面缓存修复 — 2026-08-08

- 修复旧封面缓存绕过版本标记、导致重新安装仍把旧图写回 Steam 的问题；缓存升级为 v4，更新后会强制重新下载并覆盖新版素材。
- 修复 Epic 等启动器从 Steam 删除并手动重新添加后，因名称或路径变化导致“shortcut not found”；封面修复现在会安全识别 Steam 当前保存的唯一条目。

## Renkit 1.0.7 启动器图标与掌机功耗控制修复 — 2026-08-08

- Epic、战网、育碧改用各自官方桌面图标，黑盒工坊改用黑白金属风桌面图标和整套 Steam 封面；封面缓存升级为 v3，旧安装重新点安装或运行“修复启动器封面”即可替换旧素材。
- 修正“掌机功耗控制”前端与 Decky 清单身份名不一致导致的空白界面，并在版本检测中校验汉化前端 SHA，确保同为 v1.0.5 的故障版本也会自动替换。

## Renkit 1.0.6 启动器封面改走 v2 镜像 — 2026-08-08

- 启动器封面素材改为优先从 Gitee v2 镜像拉取并缓存，不再优先使用本地旧素材；镜像缓存版本升级为 v2，更新后会自动重新下载新封面。
- 新版 Epic、战网、育碧、黑盒工坊封面已同步到 `zhoukeer-toolbox-v2` 的 `launcher-covers` 镜像，更新后重装或运行“修复启动器封面”即可生效。

## Renkit 1.0.5 掌机功耗控制汉化版与版本检测 — 2026-08-08

- SimpleDeckyTDP 汉化插件更名为“掌机功耗控制”，菜单、界面和状态检测同步使用短名称。
- 插件菜单改为自动检测版本：检测到原版、旧版或非汉化版时自动替换为最新汉化版；常用功能插件状态新增掌机功耗控制检测行。

## Renkit 1.0.4 SimpleDeckyTDP 系统信息默认展开 — 2026-08-08

- SimpleDeckyTDP 汉化版底部“系统信息”区域改为默认展开，并清除旧折叠缓存，避免打开插件后底部空白。

## Renkit 1.0.3 SimpleDeckyTDP 完整汉化 — 2026-08-08

- SimpleDeckyTDP 插件完整汉化：修复 Steam 中文语言码未命中导致瓦数、滑块等界面回退英文的问题，补齐 GPU 模式、EPP/调频选项、TDP 范围等界面中文。
- 汉化组件内置并带 RenAmamiya署名，安装复用 Gitee 镜像优先、GitHub Release 回退并校验 SHA256。

## Renkit 1.0.2 修复虚拟内存撤销与启动器封面 — 2026-08-08

- 新增“掌机适配 → 飞行家 F1 屏幕方向修复”，通过用户级 gamescope wrapper 与 systemd override 修复 ONEXPLAYER F1 游戏模式画面倒置，不使用 sudo、不修改只读系统。
- 虚拟内存撤销时自动处理独立 swap 的只读保护，避免 `rm` 因“不允许的操作”中断。
- 启动器封面素材解压忽略 macOS Apple 扩展属性警告，SteamOS 不再显示 `LIBARCHIVE.xattr.com.apple.provenance`。
- 更新 Epic、战网、育碧、黑盒工坊的封面、背景和桌面徽标素材。

## Renkit 1.0.1 清理旧版桌面入口并默认窗口启动 — 2026-08-07

- 安装或升级时自动移除旧版“周克儿工具箱”桌面与应用菜单入口，避免桌面出现重复图标。
- 启动器默认不再全屏，改为按屏幕分辨率适配的普通窗口，方便最小化和关闭。
- 需要全屏时仍可通过 `ZHOUKEER_WINDOW_FULLSCREEN=1` 恢复。

## Renkit 1.0 正式更名与旧版本清理 — 2026-08-07

- 产品正式更名为 Renkit，版本定为 1.0；界面、桌面快捷方式、诊断包和网站同步使用新名称。
- 发布包改为 `renkit.tar.gz` 与 `renkit-1.0.tar.gz`，移除 `dist` 中所有旧版发布包。
- 保留 V1.6.4 本地备份，安装、更新和下载链路继续使用原有仓库地址。
- 旧版安装检测到 Renkit 1.0 后会自动升级；仅剩域名源可用时也允许完成迁移。
