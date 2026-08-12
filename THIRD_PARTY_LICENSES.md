# 第三方依赖 License 清单

Renkit自身代码使用仓库根目录 `LICENSE`（个人免费使用，禁止商业使用、销售、转卖或二次盈利发布）；下列第三方组件仍遵循各自原始许可证。

本清单记录Renkit会下载、安装或镜像的第三方项目。进入 Gitee 公开镜像
的项目必须具有明确的再分发许可；没有明确再分发授权的项目只保留官方源或
代理回退，不进入 `mirrors/`。

| 项目 | 用途 | 上游地址 | 许可证 | 进入 Gitee 镜像 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Decky Loader | Decky 插件商城加载器 | https://github.com/SteamDeckHomebrew/decky-loader | GPL-2.0 | 是 | 稳定版与测试版均来自同一上游 |
| Decky LSFG-VK | 小黄鸭插件 | https://github.com/xXJSONDeruloXx/decky-lsfg-vk | BSD-3-Clause | 是 | 上游 License 明确允许再分发 |
| Decky-Framegen | FSR4 插件 | https://github.com/xXJSONDeruloXx/Decky-Framegen | BSD-3-Clause | 是 | 基于 Decky 模板并保留 BSD-3 声明 |
| CheatDeck | CheatDeck 插件 | https://github.com/SheffeyG/CheatDeck | GPL-3.0 | 是 | |
| SteamGridDB | Steam 游戏封面管理插件 | https://github.com/SteamGridDB/decky-steamgriddb | GPL-3.0-or-later | 是 | 使用 Decky 官方商店 v1.7.1 原包；安装后仅改 `plugin.json` 显示名称 |
| CSS Loader | Steam CSS 主题插件 | https://github.com/DeckThemes/SDH-CssLoader | GPL-2.0-or-later | 是 | 使用 Decky 官方商店 v2.1.2 原包并叠加中文前端；后端保持原包 |
| Friendeck | 局域网文件传输插件 | https://github.com/panyiwei-home/Friendeck | GPL-3.0 | 是 | Release 0.7.7 原包；安装后仅改 `plugin.json` 显示名称 |
| Decky Music | QQ 音乐与网易云音乐插件 | https://github.com/jinzhongjia/decky-music | MIT | 是 | v1.0.0 原包；安装后仅改 `plugin.json` 显示名称 |
| ToMoon | ToMoon 插件 | https://github.com/YukiCoco/ToMoon | BSD-3-Clause | 是 | |
| DeckRecall | DeckRecall 插件 | https://github.com/Ren-Amamiya-pixle/DeckRecall | 作者授权 Renkit 镜像分发 | 是 | DeckRecall 作者于 2026-08-10 在 Renkit 开发会话中明确授权国内镜像分发 |
| Unifideck | Unifideck 插件 | https://github.com/mubaraknumann/unifideck | GPL-3.0 | 是 | |
| Freedeck | Freedeck 插件 | https://github.com/panyiwei-home/Freedeck | BSD-3-Clause | 是 | LICENSE 文件为 BSD-3 文本 |
| Ally Center | ROG Ally / Ally X 硬件控制插件 | https://github.com/PixelAddictUnlocked/allycenter | MIT | 是 | 上游 Release 原包，支持 RGB、TDP、风扇与充电上限 |
| HueSync | 多品牌掌机 RGB 控制插件 | https://github.com/honjow/HueSync | BSD-3-Clause | 是 | 上游已内置简体中文，保留作者原版 |
| LegionGoRemapper | 初代 Legion Go 按键、RGB、充电与风扇控制 | https://github.com/aarron-lee/LegionGoRemapper | BSD-3-Clause | 是 | 上游 Release 原包；不支持 Legion Go S |
| GpdControl | GPD Win 系列 RGB 控制 | https://github.com/aarron-lee/GpdControl | GPL-3.0 | 是 | 上游 Release 原包 |
| LeGo Vibe Control | Legion Go / Go 2 震动与触控板控制 | https://github.com/Rayekkk/LeGo-Vibe-Control | BSD-3-Clause | 是 | 需要 hid-lenovo-go；不支持 Legion Go S |
| LeGo2 Fan Control | Legion Go 2 风扇曲线控制 | https://github.com/Rodpad/LeGo2-Fan-Control | GPL-3.0 | 是 | 仅适用于 Legion Go 2；提供不受限风扇控制 |
| OneXPlayer Apex Tools | OneXPlayer Apex 的 HHD、睡眠、风扇和按键修复 | https://github.com/srsholmes/onexplayer-apex-bazzite-fixes | MIT | 是 | 仅适用于 OneXPlayer Apex（Strix Halo），包含机型专用内核模块和系统修复 |
| SimpleDeckyTDP | SimpleDeckyTDP 插件 | https://github.com/aarron-lee/SimpleDeckyTDP | BSD-3-Clause | 是 | |
| 小黄鸭汉化完整包 | LSFG 汉化包 | https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/tag/v6.0.9 | 同 Decky LSFG-VK（BSD-3-Clause） | 否（既有仓库归档） | 汉化包已在 Gitee 仓库归档中，不重复分块镜像 |
| FSR4 汉化完整包 | FSR4 汉化包 | https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/tag/v1.2.2 | 同 Decky-Framegen（BSD-3-Clause） | 否（既有仓库归档） | 汉化包已在 Gitee 仓库归档中，不重复分块镜像 |
| SimpleDeckyTDP 汉化完整包 | SimpleDeckyTDP 汉化包 | https://github.com/aarron-lee/SimpleDeckyTDP | 同 SimpleDeckyTDP（BSD-3-Clause） | 否（Renkit 内置组件） | 中文组件随 Renkit 内置，下载复用官方 simpledeckytdp 镜像 |
| 掌机插件中文前端组件 | 上述五款掌机插件的中文名称与汉化前端 | https://github.com/zliu9732-hub/zhoukeer-toolbox | 分别沿用各上游许可证 | 否（Renkit 内置组件） | 仅覆盖 plugin.json 与 dist/index.js；HueSync 自带简中，其余四款由 Renkit 汉化并保留原作者署名 |
| CSS Loader 中文前端组件 | CSS Loader v2.1.2 中文界面 | https://github.com/DeckThemes/SDH-CssLoader/tree/v2.1.2 | GPL-2.0-or-later | 否（Renkit 内置组件） | 随附对应源码、上游 LICENSE 与构建产物；安装时仅覆盖前端和 plugin.json |
| RustDesk | RustDesk AppImage | https://github.com/rustdesk/rustdesk | AGPL-3.0 | 否（官方源） | AppImage 走作者 GitHub Release，用户可另行提供安装包 |
| GE-Proton | Steam 兼容层 | https://github.com/GloriousEggroll/proton-ge-custom | Proton 顶层 BSD-3-Clause，组件各自许可 | 是 | 镜像包含上游 LICENSE.proton 说明 |
| ToDesk | ToDesk 官方安装包 | https://www.todesk.com/ | 专有软件 | 是 | 维护者确认仅用于非商业装机工具，保持官方包原样并保留官网回退 |
| Epic Games 启动器 | Epic 官方 Windows 安装器 | https://www.epicgames.com/ | 专有软件 | 是 | 维护者要求镜像以解决官方下载失败，保持官方包原样并保留官方源回退 |
| Steamcommunity 302 | Steam/GitHub 加速 | https://www.dogfight360.com/blog/ | 作者公开免费发布，仓库未附带 LICENSE | 是 | Renkit只从自有 Gitee 镜像下载，镜像由维护者从官方源更新 |
| Greenlight | Xbox 云游戏客户端 | https://github.com/unknownskl/greenlight | MIT | 否（Flathub 官方源） | 通过 Flathub 安装，不进入仓库 mirrors |
| Yuzu | Switch 模拟器 | https://github.com/yuzu-emu/yuzu | 上游仓库已下线 | 是（自有 Release 固定包） | Gitee 分块镜像优先，GitHub Release 回退；仅分发自有 Release 中未修改的固定 AppImage |
| Cemu | Wii U 模拟器 | https://github.com/cemu-project/Cemu | MPL-2.0 | 是 | Gitee 分块镜像优先，GitHub Release 回退；镜像为上游未修改的固定 AppImage |
| DuckStation | PS1 模拟器 | https://github.com/stenzek/duckstation | CC BY-NC-ND 4.0 | 是（自有非商业镜像） | 仅分发自有 Release 中未修改的固定 AppImage，保留署名与许可要求；Gitee 分块镜像优先，GitHub Release 回退 |
| PCSX2 | PS2 模拟器 | https://github.com/PCSX2/pcsx2 | GPL-3.0 | 是 | Gitee 分块镜像优先，GitHub Release 回退；镜像为上游未修改的固定 AppImage |
| RPCS3 | PS3 模拟器 | https://github.com/RPCS3/rpcs3 | GPL-2.0 | 是 | Gitee 分块镜像优先，GitHub Release 回退；镜像为上游未修改的固定 AppImage |
| ShadPS4 | PS4 模拟器 | https://github.com/shadps4-emu/shadPS4 | GPL-2.0 | 是 | Gitee 分块镜像优先，GitHub Release 回退；镜像为上游未修改的固定 AppImage |
| 微信 Linux | 微信官方 AppImage 与桌面图标 | https://linux.weixin.qq.com/ / https://github.com/flathub/com.tencent.WeChat | 专有软件；图标为腾讯商标 | 否（Renkit 内置图标） | AppImage 从腾讯官方 CDN 下载；默认图标取自 `flathub/com.tencent.WeChat@f1ca9e7` 的应用清单并随 Renkit 更新包分发 |

### 内置模拟器图标来源

`assets/emulators/` 不使用 AI 生成图。Yuzu 图标取自其已归档的 Flathub
应用清单 `flathub/org.yuzu_emu.yuzu@4abf1d2`；Cemu、DuckStation、PCSX2、
RPCS3、ShadPS4 图标分别取自各自上游官方仓库的应用图标，固定提交为
`daacdda`、`5ee1d25`、`2cf8dab`、`2f40345`、`c5ae3c6`。SVG 来源仅做
PNG 格式转换，不改变图形内容；各图标沿用对应上游项目的许可与商标要求。

## 说明

- “进入 Gitee 镜像”表示该项目的文件会出现在 `mirrors/` 目录并通过
  `latest.txt` 分块清单下载；未进入镜像的项目仍可在Renkit内使用官方源或
  既有代理回退。
- Flatpak 应用依赖（LibreOffice、Firefox、LocalSend 等）由 Flathub 及
  上海交大/中科大镜像提供，不进入本仓库 `mirrors/`。
- 镜像中的压缩包均为上游发布的原始文件，Renkit不在镜像阶段修改内容；
  下载后仍会校验固定 SHA256。
