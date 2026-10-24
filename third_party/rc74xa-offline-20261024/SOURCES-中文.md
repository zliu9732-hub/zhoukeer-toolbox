# 来源与筛选记录（2026-10-24）

1. 原始 RC74XA 音频修复：<https://github.com/hungarianhc/rog-ally-x20-steamos-speakers>，固定提交 `528d4da0eeba35ee9b0ff6851db1e12dc5a178bc`。作者明确报告 X20、BIOS .301、SteamOS 3.9.3 Preview build 20261015.100 和精确 7.2.7 Valve 内核，涵盖扬声器、内置麦克风、耳机和耳麦。它与老款 HDA/TAS2781 音频硬件不同。
2. X20 QAM / 唤醒方案：<https://github.com/ovenham/rog-ally-x20-steamos-speaker-qam-fix>，固定发布 **v1.0.3**。原发布 ZIP SHA-256 `878872ef7738a2ade468d1e7679f57fa5acb743ceaa302e36a3ed4522f3674e2`。该作者报告 BIOS .303 和同一精确内核实机有效，6.18 Stable 实机无效；未来内核重建未测试。本包不提供该重建功能。
3. 作者本人在社区发布实机方案：<https://www.reddit.com/r/XboxAlly/comments/1xb6vkd/ally_x20_steamos_fixes_speakers_and_qam_button/>。帖子描述 QAM、唤醒音频和 Xbox 键恢复；这属于作者实测声明，不是独立实验室验证。
4. 独立用户 RC74XA.303 的音频唤醒规避：<https://github.com/hungarianhc/rog-ally-x20-steamos-speakers/issues/1#issuecomment-6294971783>。报告在游戏运行中 suspend/resume 输出可恢复。内核字符串有手工抄写笔误，不能将那个不同字符串也列入可加载模块清单。原 issue/评论 JSON 已归档。
5. Linux 音频上游补丁系列：<https://lists.openwall.net/linux-kernel/2026/10/16/3092>。报告 RC74XA 上双扬声器、耳机/插孔、两种麦克风及 suspend 测试；这不是已发布的 SteamOS 二进制。本包不将整套新补丁编成未经验证模块。补丁还涉及反馈 capture 和耳麦录音起始噪声；本包不能承诺修好这些额外问题。
6. TI 固件官方上游：<https://gitlab.com/kernel-firmware/linux-firmware>，固定提交 `a2dcb924f0897368b0b4f305cbf9808cdda90ce0`，路径 `ti/audio/tas2783/1954-{0,1}-0-0x{8,B}.bin`。四个 SHA-256 均与修复项目硬编码一致，详见 manifest。kernel.org plain 下载在本次返回防机器人 HTML，已放弃那些无效文件，改用同提交官方 GitLab 原始文件；没有把 HTML 当成固件打包。随包保留 WHENCE 与 TI 许可。
7. UCM：原包 `ucm/tas2783.conf`，来自 ALSA 上游 <https://github.com/alsa-project/alsa-ucm-conf>，BSD-3-Clause；保留原包许可。
8. Decky：<https://github.com/SteamDeckHomebrew/decky-loader/releases/tag/v3.3.0>。x86_64 PluginLoader SHA-256 `e80d03e641d1766a33a817cb27ab8d2e0a4633685e5d27e4de948a6687526181`，与 GitHub release digest 一致。service 模板来自同标签。官方安装流程参考 <https://github.com/SteamDeckHomebrew/decky-installer/blob/main/cli/install_release.sh>；本包将其中的下载替换为本地复制，复用已有标准安装。本包的自制部署逻辑没有 RC74XA 实机验证，不能与上游修复的实测混淆。

## 排除或限制

- 原始音频项目 [issue #2](https://github.com/hungarianhc/rog-ally-x20-steamos-speakers/issues/2) 追问预编译 `.ko` 的精确源代码/工具链/配置；截至检索时未见回复。本包保留项目源代码和补丁，但没有独立重建这个模块，也不声称已完成可复现构建证明。二进制哈希相符只证明文件与项目提供的一致。
- [issue #3](https://github.com/hungarianhc/rog-ally-x20-steamos-speakers/issues/3) 有更新后安装报错；没有据此扩大可用版本清单。
- [Ally Vibe Control](https://github.com/piyush-tyagi-13/ally-vibe-control) 支持说明及其他 Ally 的记录不足以确认 RC74XA。[X20 询问](https://www.reddit.com/r/XboxAlly/comments/1t8fdvp/i_built_a_decky_plugin_to_fix_the_missing/) 中作者仅建议试用、未确认成功，因此未下载为可安装修复。
- [SteamOS #2824](https://github.com/ValveSoftware/SteamOS/issues/2824) 的振动回归后续定位到 Steam Beta 客户端，9 月 22 日客户端修复后原报告者确认恢复，早于 X20 发售；不是 X20 驱动修复证据，不套用旧内核或其他机型模块。
- [X20 初体验实机报告](https://www.reddit.com/r/XboxAlly/comments/1x6jwck/steamos_on_rog_ally_x20_first_impressions/) 说明通用 XInput、QAM 和 HDR 不可用。未找到 SteamOS 的可靠 HDR/亮度补丁；[Anatase 官方 20261019.3 发布记录](https://docs.anatase.org/updates/20261019.3) 确实列出 X20 HDR/控制器支持，但使用其内核、libdisplay-info、HHD 等组合，不能当作可直接安装到 SteamOS 的文件。
- 搜索还覆盖 RC74XA hid-asus、controller、brightness、HDR、vibration、suspend 以及 X20 SteamOS GitHub/社区组合。检索结论是“没有找到满足本次条件的修复”，不等于证明没有任何未知方案。

## 本地验证边界

本次只在 Windows 工作目录下载、校验、修改文本和打包。没有对当前电脑执行 Linux 安装、写驱动、变更服务或修改 BIOS。`VALIDATION-中文.md` 记录实际完成的包验证，不能代替目标机听音、录音、按键和休眠测试。
