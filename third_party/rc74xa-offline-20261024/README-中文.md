# RC74XA SteamOS 3.9 离线兼容性修复包

整理日期：2026-10-24。可作为独立模块手动加入 Renkit。本包没有在当前电脑执行安装；自制打包与安装流程做了静态/模拟检查，尚未在你的掌机运行。硬件有效性依据来自下述社区实机记录。

## 先看适用范围

**不是所有 3.9 都能安装。** 本包严格要求：ASUS RC74XA、音频 PCI `1022:15e2` / 子系统 `1043:1954`、Valve SteamOS **3.9.3**、BIOS `RC74XA.301` 或 `RC74XA.303`，以及下面完全相同的内核：

```text
7.2.7-valve2-1-neptune-72-g31504582a073
```

原始作者报告的系统为 3.9.3 Preview、build 20261015.100；后续项目在 Beta 同内核、BIOS .303 实测。固件通过 `SPEAKER_ID` 自动区分 JGX(0) / LS(1)，不猜测或混用调音。

3.9.4、其他 3.9 构建/内核、3.8 Stable、其他 Linux 发行版和其他 Ally 型号均不会被本包当成已验证环境。预检查不通过时停止，不降级系统、不编译未知内核、不强制加载模块。

## 能处理什么

| 项目 | 收录内容与限制 |
| --- | --- |
| 内置立体声扬声器、内置麦克风、3.5mm 耳机及耳麦麦克风 | 收录 TAS2783 / RT721 音频修复。原项目报告这些接口恢复；后续独立确认主要集中于扬声器，仍需你在设备上逐项复测。不会提供 Dolby Atmos 音效或更换整套音频驱动。 |
| 右侧快捷菜单 QAM | 收录 X20 专用 `0xa0` HID 报告处理，调用 Steam 菜单 API；依赖 Decky 与游戏模式。 |
| 唤醒后声音消失或延迟恢复 | 收录重新打开 SoundWire 输出流的社区规避方案。 |
| 唤醒后 Xbox 键、菜单键异常 | 收录重新发送控制器当前 `gamepad_mode` 的规避方案，不改为固定模式。 |
| 一般手柄识别、Steam Input 重映射、背键 | 没有收录能全面解决这些问题的已验证 RC74XA 驱动。菜单规避不等同于完整原生识别。 |
| 振动失效、强度异常、扳机独立振动 | 跳过。Ally Vibe Control 的 RC74XA 支持尚未得到确认；旧 Xbox Ally 的成功记录不能代替 X20 实测。 |
| OLED 亮度、HDR | 跳过。找到 X20 SteamOS HDR 不可用报告，但没有确认可用的 SteamOS 修复；未找到亮度故障与可靠专用补丁的证据。其他发行版的“能用”报告不作为补丁。 |

TDP、风扇、RGB 未收录，也不会调整。

## 安装（在目标 RC74XA 上操作）

1. 将整个 ZIP 解压到掌机普通用户的主目录中；不要只复制入口脚本，也不要放在 `/tmp`。先完成 SteamOS 和 Steam 的初始配置。
2. 进入桌面模式，在解压目录打开 Konsole。若未设置 sudo 密码，先自行运行 `passwd`。
3. 只检测，不修改系统：

```bash
sudo bash install.sh check
```

4. 预检查通过后，一条命令部署音频、X20 Fixes 插件和缺失的 Decky：

```bash
sudo bash install.sh install
```

5. 手动重启掌机。回到游戏模式，先用 Xbox + A 打开 QAM，进入 Decky 查看 **X20 Fixes**。右侧快捷键应恢复；插件默认开启唤醒声音和按键修复。保留“自动重应用”关闭。

已有标准路径 Decky 时复用它，不替换版本和其他插件；没有时用已下载的官方 x86_64 **Decky v3.3.0** 二进制和官方 service 模板离线部署。遇到非标准路径或已有 X20 Fixes 时停止，避免覆盖。Decky 与 Steam 客户端版本之间仍可能有兼容性限制；这不是音频模块能解决的。

若你只要音频、不希望安装插件或 Decky：

```bash
sudo bash install.sh install --audio-only
```

这种模式不提供自动唤醒恢复和 QAM；可以手动运行音频唤醒规避命令：

```bash
pactl suspend-sink @DEFAULT_SINK@ 1
sleep 2
pactl suspend-sink @DEFAULT_SINK@ 0
```

这条手动命令重开当前默认输出；蓝牙/USB 输出为默认时不要用它诊断内置扬声器。

## 离线文件与依赖

已下载：精确内核的 `.ko`、UCM 配置、JGX/LS 两组共四份 TI 固件、已构建插件前端与 Python 后端、Decky x86_64 自包含运行程序及 service 模板、上游源代码 ZIP、许可证、版本与哈希记录。目标机不需要 npm、pip、Git、Podman 或编译工具链。

依赖目标 SteamOS 原本自带的 Python、ALSA/PipeWire、pactl、pciutils、kmod、GRUB、bsdcpio、coreutils、systemd 等基础命令。安装器会检查它们；若精简系统缺少命令则停止。本包不包含完整 SteamOS/Steam 客户端，不离线升级系统，也不为未知系统混入 Arch 软件包。部署路径没有下载步骤；音频缓存缺失或损坏会停止，不联网补文件。上游 Decky 自身仍有商店/更新等联网功能，它们不属于离线安装依赖。

`payload/` 是实际部署内容；`upstream/` 是保持原样的原始发布包和源代码归档，仅供溯源，**不要绕过本包入口直接安装其中未经离线限制的原包**。`manifest.json` / `SHA256SUMS` 用于校验文件完整性，不代表独立的代码签名或硬件测试。

## 状态、验证和卸载

状态：`sudo bash install.sh status`。检查输出是否有 `spk:tas2783`。在游戏模式分别测试左右声道、内置录音、耳机插拔和耳麦录音，游戏运行中至少做一次休眠/唤醒，再确认 Xbox / Steam 菜单 / QAM。

卸载本包并恢复安装前文件：

```bash
sudo bash install.sh uninstall
```

随后手动重启。完整模式下，本包新装的 Decky 服务也会撤销；原来已有的 Decky 和音频状态按安装前备份恢复。备份在 `/var/lib/rc74xa-offline/`，正常卸载完成后删除。不要在卸载前删除该目录。

安装器会修改当前 SteamOS 槽的 `/efi/EFI/steamos/grub.cfg`，生成本机 ACPI 表覆盖，设置 `/var/lib/ally-audio-fix/` 及两个 `/etc` 配置，并部署用户 homebrew 目录。它不是 BIOS 更新。加载重建模块会标记内核 tainted。安装失败时尝试恢复本次更改；如恢复报错，保留备份目录再排查。

**系统或 BIOS 更新前应先卸载本包，再更新。** SteamOS A/B 更新会换槽；精确内核变化后旧模块和本包插件功能会停止适用。不要把内核目录改名继续用。没有打包新版本的工具链，不承诺未来版本离线可用。

如果更新后才卸载，安装器检测到 GRUB 变化会拒绝还原旧备份。此时不要覆盖新系统的 grub.cfg。可以在目标掌机用本包携带的上游卸载逻辑移除当前槽音频覆盖：

```bash
sudo sh payload/x20-fixes/fix/ally-audio-fix.sh uninstall
```

然后在 Decky 中卸载 X20 Fixes，重启。这个恢复路径只清理当前槽，不能保证删除未启动槽中的旧更改；保留 `/var/lib/rc74xa-offline/` 备份用于核对。若原先已有音频改动，这条命令也会移除同名音频修复，不能代替安装前备份恢复。

## 来源

详细来源、排除理由和版本记录见 [SOURCES-中文.md](SOURCES-中文.md)。
