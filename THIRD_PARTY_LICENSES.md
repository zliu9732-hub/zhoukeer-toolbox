# 第三方依赖 License 清单

周克儿工具箱自身代码使用仓库根目录 `LICENSE`（个人免费使用，禁止商业使用、销售、转卖或二次盈利发布）；下列第三方组件仍遵循各自原始许可证。

本清单记录周克儿工具箱会下载、安装或镜像的第三方项目。进入 Gitee 公开镜像
的项目必须具有明确的再分发许可；没有明确再分发授权的项目只保留官方源或
代理回退，不进入 `mirrors/`。

| 项目 | 用途 | 上游地址 | 许可证 | 进入 Gitee 镜像 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Decky Loader | Decky 插件商城加载器 | https://github.com/SteamDeckHomebrew/decky-loader | GPL-2.0 | 是 | 稳定版与测试版均来自同一上游 |
| Decky LSFG-VK | 小黄鸭插件 | https://github.com/xXJSONDeruloXx/decky-lsfg-vk | BSD-3-Clause | 是 | 上游 License 明确允许再分发 |
| Decky-Framegen | FSR4 插件 | https://github.com/xXJSONDeruloXx/Decky-Framegen | BSD-3-Clause | 是 | 基于 Decky 模板并保留 BSD-3 声明 |
| CheatDeck | CheatDeck 插件 | https://github.com/SheffeyG/CheatDeck | GPL-3.0 | 是 | |
| ToMoon | ToMoon 插件 | https://github.com/YukiCoco/ToMoon | BSD-3-Clause | 是 | |
| DeckRecall | DeckRecall 插件 | https://github.com/Ren-Amamiya-pixle/DeckRecall | 未提供 LICENSE | 否 | 无明确再分发授权，仅保留 GitHub 官方源 |
| Unifideck | Unifideck 插件 | https://github.com/mubaraknumann/unifideck | GPL-3.0 | 是 | |
| Freedeck | Freedeck 插件 | https://github.com/panyiwei-home/Freedeck | BSD-3-Clause | 是 | LICENSE 文件为 BSD-3 文本 |
| SimpleDeckyTDP | SimpleDeckyTDP 插件 | https://github.com/aarron-lee/SimpleDeckyTDP | BSD-3-Clause | 是 | |
| 小黄鸭汉化完整包 | LSFG 汉化包 | https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/tag/v6.0.9 | 同 Decky LSFG-VK（BSD-3-Clause） | 否（既有仓库归档） | 汉化包已在 Gitee 仓库归档中，不重复分块镜像 |
| FSR4 汉化完整包 | FSR4 汉化包 | https://github.com/zliu9732-hub/zhoukeer-toolbox/releases/tag/v1.2.2 | 同 Decky-Framegen（BSD-3-Clause） | 否（既有仓库归档） | 汉化包已在 Gitee 仓库归档中，不重复分块镜像 |
| RustDesk | RustDesk AppImage | https://github.com/rustdesk/rustdesk | AGPL-3.0 | 否（官方源） | AppImage 走作者 GitHub Release，用户可另行提供安装包 |
| GE-Proton | Steam 兼容层 | https://github.com/GloriousEggroll/proton-ge-custom | Proton 顶层 BSD-3-Clause，组件各自许可 | 是 | 镜像包含上游 LICENSE.proton 说明 |
| ToDesk | ToDesk 官方安装包 | https://www.todesk.com/ | 专有软件 | 是 | 维护者确认仅用于非商业装机工具，保持官方包原样并保留官网回退 |
| Epic Games 启动器 | Epic 官方 Windows 安装器 | https://www.epicgames.com/ | 专有软件 | 是 | 维护者要求镜像以解决官方下载失败，保持官方包原样并保留官方源回退 |
| Steamcommunity 302 | Steam/GitHub 加速 | https://www.dogfight360.com/blog/ | 作者公开免费发布，仓库未附带 LICENSE | 是 | 工具箱只从自有 Gitee 镜像下载，镜像由维护者从官方源更新 |
| Yuzu | Switch 模拟器 | https://github.com/yuzu-emu/yuzu | 上游仓库已下线 | 否 | 不镜像，仅保留现有 GitHub Release 回退 |
| Cemu | Wii U 模拟器 | https://github.com/cemu-project/Cemu | MPL-2.0 | 否（官方源） | AppImage 走既有 GitHub Release 回退 |
| DuckStation | PS1 模拟器 | https://github.com/stenzek/duckstation | CC BY-NC-ND 4.0 | 否 | 非商业且禁止演绎，不进入公开镜像 |
| PCSX2 | PS2 模拟器 | https://github.com/PCSX2/pcsx2 | GPL-3.0 | 否（官方源） | AppImage 走既有 GitHub Release 回退 |
| RPCS3 | PS3 模拟器 | https://github.com/RPCS3/rpcs3 | GPL-2.0 | 否（官方源） | AppImage 走既有 GitHub Release 回退 |
| ShadPS4 | PS4 模拟器 | https://github.com/shadps4-emu/shadPS4 | GPL-2.0 | 否（官方源） | AppImage 走既有 GitHub Release 回退 |

## 说明

- “进入 Gitee 镜像”表示该项目的文件会出现在 `mirrors/` 目录并通过
  `latest.txt` 分块清单下载；未进入镜像的项目仍可在工具箱内使用官方源或
  既有代理回退。
- Flatpak 应用依赖（LibreOffice、Firefox、LocalSend 等）由 Flathub 及
  上海交大/中科大镜像提供，不进入本仓库 `mirrors/`。
- 镜像中的压缩包均为上游发布的原始文件，工具箱不在镜像阶段修改内容；
  下载后仍会校验固定 SHA256。
