# Anatase 与共用桌面 Linux 菜单

3.4.0 按用户要求解除 Bazzite 公共功能仅按系统名称放行的限制。Anatase 及其他非 SteamOS 桌面 Linux 继续复用 main-bazzite.sh，安装或更新后重新打开即可；保留原文件名和 Bazzite 桌面入口兼容性。Anatase 的安装入口和首页显示 Anatase，其他系统显示 Linux。

## 系统识别

平台层保留真实 PLATFORM_ID / PLATFORM_FAMILY 与 IS_STEAMOS / IS_BAZZITE；Anatase 不冒充 Bazzite。IS_DESKTOP_LINUX 标记可进入共用菜单的其他 Linux。应用及普通插件使用共用条件，具体功能继续核对命令、存储位置、Steam、插件商城文件、机型与下载校验。Mac 与其他非 Linux 仍拒绝安装功能。

Anatase 上游说明其为独立的不可变系统，虽然继承了 Bazzite 开发经验，不能把 Bazzite 专用系统管理操作直接当作 Anatase 支持。来源：https://github.com/anatase-org/anatase 和 https://docs.anatase.org/ 。本次没有新增 Anatase 的系统重刷、驱动或启动修复。

## 公共功能

常用软件、游戏启动器、GE / Proton 兼容层、模拟器、用户级 Flatpak 下载设置和已有插件环境中的插件安装不再因发行版名称被拒绝。Flatpak 仍优先使用该桌面入口的官方设置；国内下载源必须确认远程地址及关闭签名检查的风险，可恢复官方签名校验。不自动修改系统镜像、系统更新源或系统级 Flatpak。

插件商城检查先复用已安装环境。Bazzite 沿用 ujust setup-decky；其他系统必须真实提供同名安装任务（列表查询成功且任务名称准确匹配）才调用。未提供安装任务时说明需先通过系统支持的方式准备 Decky Loader；禁止落入 SteamOS 的商城/服务安装流程。

## 系统专用边界

SteamOS 的只读保护、系统驱动、内存与系统调优保持原条件。Clover 的条件单独保留为 SteamOS / Bazzite，不能因为公共应用支持更多 Linux 而解锁未知系统的启动文件操作。各插件自身的机型和引擎要求保留。ChimeraOS 的独立功能范围不变。

## 验证范围

测试仅使用临时 HOME、模拟系统信息/命令、用户空间文件与私有伪终端。覆盖 Anatase/Fedora 的实际启动器、平台标志、插件动作路由、已有商城、缺失/失败安装任务、重复安装、用户级 Flatpak 安装/卸载及下载源恢复；另检查实际发布包安装后的平台模块和桌面入口。未启动真实系统管理命令或 Linux 二进制，不能将模拟通过当作 Anatase 的全面实机验证。


## 3.4.4 插件入口恢复

Bazzite/Anatase 桌面版的“其余常用插件”分两页，补齐 ThemeHub 主页主题、屏幕色彩、SteamDB 游戏数据、游戏翻译、GFG Extreme、Fantastic，以及三个 CSS Loader 主题。AYANEO3 Companion 位于更多掌机插件。已有封面、CSS Loader、音乐、传输、小黄鸭、FSR4、MAKO、CheatDeck、存档、入库和掌机控制入口保留。

ThemeHub 与小黄鸭 2.0 / FSR4 使用同一批已审核完整中文成品与 48 小时更新清单；不复制旧前端、不改包内容或另开下载逻辑。保留哈希与全文件清单校验、缓存、禁止降级、同目录替换、失败恢复和设置保留。Bazzite 的小黄鸭 2.0 也先停用并清理已识别的旧副本，再安装验证后的新目录；停止失败则不清理，安装失败恢复原插件，MAKO 等其他插件不删除。

GFG/Fantastic 在桌面 Linux 仍需 Steam Deck，AYANEO3 仍校验机型。GFG 引擎、上游插件和系统组件的运行检查保持原样；本次未运行上游后台、未在 macOS 操作系统或安装 Linux 软件。OneXPlayer 的系统修复和启动文件功能继续按其原系统条件检查。本次模拟验证安装通路、保留下载校验、重载、失败恢复、全中文包完整性，以及 21 行矮窗口的真实菜单翻页和所有新增按钮。

交付 ThemeHub 1.10.9 完整中文 ZIP：根目录 DeckHomeThemes，69 个运行/声明/汉化报告文件，SHA256 `97fdf3fbf4341e5e7efada4cb7a0e7457a5b7b6b1340d3b22cd2d04c7ee17bbe`；与已发布清单一致，可在 Decky 开发者设置直接选 ZIP 安装。以原始 1.10.9 包重建，重新验证显示文案清单、后端与功能 AST、原作者与黄色 RenAmamiya 汉化署名。
