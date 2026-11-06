# DeckyGCM 与 CheatDeck

Renkit 的“CheatDeck 与 DeckyGCM”会一起处理两款插件。SteamOS 新机初始化、常用插件组合、全部插件、桌面版菜单、图形菜单和独立 `scripts/install-decky-plugin.sh cheatdeck` 入口共用安装函数。CheatDeck 已安装也检查 DeckyGCM；整组只有全部插件均完整时才能跳过。两款分别使用原有同目录原子替换，第二款失败会报告未完成，保留已装好的第一款，重试补装缺失项。安装前后不删除修改器库或插件设置。

DeckyGCM 使用 Qiming-Liu 发布的 **v1.0.1 完整原包**，原包自带简体/繁体中文并跟随 Steam 语言。保留原作者、GPL-3.0、GCM 许可证和运行文件，Renkit 不改显示名称、接口名称、Python 字节码或下载数据源，也不添加 RenAmamiya 汉化署名。在安装确认、安装提示与状态中标注“感谢b站ProSS及时行乐”。

- 上游与对应源码：<https://github.com/Qiming-Liu/Decky-Game-Cheats-Manager/tree/f386dec948c62ecee82c5eca4a8112516bedbb4e>
- 正式发布：<https://github.com/Qiming-Liu/Decky-Game-Cheats-Manager/releases/tag/v1.0.1>
- 介绍视频：<https://www.bilibili.com/video/BV1J64k6WEoN/>
- 原包 SHA256：`fc989a509847000f195dd64d62d7d41a0cdca4fefb2ee9cceb77bdd14573b013`，5,644,586 字节。

下载沿用 Gitee 分块清单、大小限制、HTTPS、SHA256 和官方同哈希回退；`deckygcm` 位于 mirror-4，44 个 128 KiB 分块（末块 8,490 字节）。面向用户的下载进度不展示平台或分块细节。维护脚本固定已审核版本，避免自动替换未经检查的新包。更新版本时须重新核对完整原包与文件清单。

`data/deckygcm_files.json` 记录原包全部 354 个文件的哈希，`scripts/deckygcm_package.py` 只读取文件，不导入插件；替换前暂存检查和最终状态检查覆盖后端、全部依赖、数据库和许可证，拒绝缺失、损坏和符号链接，输出失败文件及日志。上游发布包使用 Decky 的 CPython 3.14 格式和 Linux x86_64 依赖，需使用相应新版插件商城，不使用系统 Python 版本判断 Decky 的内置运行环境。

模拟测试覆盖 SteamOS/桌面入口、成对安装、重复安装、缺少任一插件、下载失败、再次补装、重载次数、整组跳过和独立入口的原密码授权适配。公开地址取回全部分块后重新组装，核对总大小、SHA256 与全部 354 个文件。未在 macOS 导入插件、运行 Linux 二进制或执行实际系统安装，游戏模式中的真实搜索、下载与随游戏启动仍需实机验证。

3.4.6 补测真实 `unzip`、`cp -a` 与组合最终检查。已复现旧安装器在新目录完整时，仍因最后 `rm` 无法清理旧目录而返回失败；Decky 会调整插件目录归属，父目录可写不代表旧插件内部可删除。新暂存和备份位于 `plugins` 的同级私有临时目录，沿用原授权按需清理；无法清理的旧副本留在扫描范围之外，显示提示并保留新安装。识别 3.4.5 及此前遗留的常用插件 `.名称.backup.数字` / `.名称.new.数字`：仅在正式目录和临时目录均完整、清单名称相同时移出保存，不处理无正式副本、名称不符、链接或无关隐藏目录。

`tests/test_plugin_atomic_install.sh` 覆盖复制、切换、恢复、管理员清理和保留副本；`tests/test_feature_bundle_integration.sh [已核验的上游ZIP]` 执行实际组合、真实安装函数和状态检查，网络、服务、管理员权限失败仍为模拟。无参数使用私有合成包，发布验证须另外传入上游完整包。插件原包及下载清单没有变化。
