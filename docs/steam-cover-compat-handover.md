# Steam 库封面与兼容层问题交接文档

## 现象

Epic、战网、育碧、黑盒工坊四个启动器通过工具箱写入 Steam 库后，库内封面/背景图没有按预期更换，Proton 兼容层也没有生效；用户点击“开始游戏”后可能没有反应。

## 已定位并修复的根因（V1.6.1 起）

1. shortcuts.vdf 条目缺少 Steam 认可的 `appid` 字段
   - Steam 在读取条目时会自行计算/重写该 ID，工具箱按自己计算的 ID 写封面和兼容层，两边对不上。
   - 修复：添加或更新条目时写入 `appid` 字段，并保证字段值等于 Steam 的 CRC 计算值。

2. 同名条目换路径时 appid 没有同步重算
   - 战网/黑盒从“安装条目”转为“正式启动器条目”，或从旧隐藏路径迁移到可见路径时，条目 exe 变了，但 appid 字段仍是旧值，封面和兼容层全部写到旧 ID 下。
   - 修复：`steam_shortcut.py` 在条目 exe、名称或启动目录变化时同步重算并回写 `appid`。

3. Decky 应用封面/兼容层前没有确认 Steam 实际使用的 AppID
   - 修复：调用 Decky 前先通过 `GetAppOverviewByAppID` 探测 Steam 实际识别的 AppID；探测不到时仍覆盖全部候选 ID（带引号、不带引号、gameid、有符号变体）。

4. 主封面源图尺寸错误
   - 旧主封面源图是 920x430 横图，Steam 主封面槽是 600x900 竖版，写入后变形或显示异常。
   - 修复：写入前校验 600x900，误用横图时自动改用竖版图；新四套封面均为 600x900。

5. 封面素材不再打进发布包
   - 新封面体积超过发布包 9MiB 上限，改为安装启动器时按需下载并缓存到 `$APP_DIR/game-launchers/covers/<目标>/`。
   - 下载源顺序：GitHub raw → 旧 Gitee raw；本地开发目录有图时直接使用本地文件。

## 设备端排查步骤

1. 确认工具箱已更新到 V1.6.1 或更高版本。
2. 安装或重新点击启动器入口，让 Steam 条目、封面和兼容层全部重写一次。
3. 让 Steam 完全退出后再启动（或直接进入游戏模式），再打开库查看封面/背景。
4. 运行诊断命令：
   ```bash
   bash scripts/apply_steam_artwork.sh verify epic
   bash scripts/apply_steam_artwork.sh verify battlenet
   bash scripts/apply_steam_artwork.sh verify ubisoft
   bash scripts/apply_steam_artwork.sh verify heihe
   ```
   - 确认输出的 appid 与 `shortcuts.vdf` 条目一致。
   - 确认 grid 目录下 `{appid}.png`、`{appid}p.png`、`{appid}_hero.png`、`{appid}_logo.png`、`{appid}_icon.png`、`{appid}_background.*` 都存在。
   - 确认 Decky Loader 状态：只有在游戏模式且 Decky 运行时才会即时刷新封面。
5. 检查 `~/.local/share/Steam/config/config.vdf`：
   - `CompatToolMapping` 下应存在对应 appid 的 `proton_10` 映射。
   - 若 Steam 实际使用的兼容层工具名不是 `proton_10`（例如 Proton Experimental 或 Proton 10.0.1），映射不会生效，需在库中手动选择。
6. 若 grid 目录本身是符号链接，工具箱会拒绝写入封面，需要先解除软链接。
7. 若安装时出现“下载封面素材失败”，说明网络无法访问 raw 地址，需要检查网络或代理。

## 用户提示

四个启动器下载/安装完成后，工具箱会提示：若点击开始游戏没反应，请点启动器右侧的齿轮 → 属性 → 兼容性，勾选“强制使用兼容性工具”，选择 Proton Experimental 或 Proton 10.0.1 后重试。

## 尚未确认的项

- Steam 当前版本计算非 Steam 游戏 AppID 时使用的确切字符串（Exe 是否带引号、路径是否被 Steam 改写）仍需在真实设备上核对。
- `proton_10` 映射名与设备实际 Proton 版本名称是否一致尚未在设备上确认；如不一致，兼容层仍需用户手动选择。
- Decky 只在游戏模式可用；桌面模式下封面写入依赖 grid 文件，需 Steam 重启后生效。

## 后续方向

- 拿到设备日志后，先对比 `shortcuts.vdf` 中条目 exe 与工具箱写入时的 exe 是否一致。
- 若封面仍不生效，优先检查 grid 文件命名与实际 appid 是否匹配、Steam 是否读取缓存。
- 若兼容层仍不生效，优先核对 `config.vdf` 中 `CompatToolMapping` 的工具名与 Steam 版本匹配。
