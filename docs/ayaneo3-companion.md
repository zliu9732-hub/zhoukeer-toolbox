# AYANEO3 Companion 中文版维护

固定官方 1.2.0（tag commit `c8266e6e3de55f4d879852438e4aacf4905642b7`），发布文件及全部 40 个文件的校验值见 `data/ayaneo3_files.json`。来源为 Rayekkk/Ayaneo3Companion，BSD-3-Clause；原作者、许可证和第三方源码/声明随完整原包保留。

## 汉化范围

`data/ayaneo3_zh.json` 与 `assets/ayaneo3/zh-runtime.js` 只转换 JSX 显示属性、下拉选项标签和通知文字。原始值、回调、后端方法、root 标志、插件注册名、版本和设置位置不变。标题增加黄色 `RenAmamiya汉化`，显示内容名为 AYANEO3 控制中心；Decky 注册名仍是 `AYANEO 3 Companion`，目录仍是 `Ayaneo3Companion`。

`scripts/localize_ayaneo3.py` 在临时目录检查完整 ZIP、全部文件 SHA256 和安全路径，只有前端文件发生变化，其余 39 个文件完全保留。中文前端也有固定 SHA256，校验后才原子替换原插件。完整当前中文版跳过下载；故障、缺件或仍是英文版会重新准备。设置位于插件外的原有 Decky 目录，不删除。

`scripts/verify_ayaneo3_ui.mjs` 静态解析完整官方前端和中文前端，去除本项目显示包装后，整个语法树必须相同，并检查 API 注册名仍与清单一致。不执行下载的硬件控制代码。

## 下载和菜单

使用现有 Gitee 下载器，mirror-4 下的 `ayaneo3-companion/1.2.0/part.0001` 与 `part.0002` 保存官方原包；`latest.txt` 固定版本、大小和 SHA256。同步命令为 `scripts/sync_gitee_mirrors.sh --only-ayaneo3`；常规定时同步也会维护这一资产。

安装后自动提供中文，无需用户另装翻译组件。界面不显示来源、分块或地址。触控入口为“游戏与插件 → 掌机控制插件 → 下一页”，GUI 掌机控制菜单也有同一动作；机型提示按用户要求仅为“仅适用于 AYANEO3”。安装器仍在下载前核对 AYANEO / AYANEO 3，非 SteamOS 主线或其他机型停止。

## 验证边界

开发机只做完整文件校验、静态结构比较和使用临时目录/模拟命令的测试。风扇、功耗、EFI 音频校准、按键与屏幕设置不在 macOS 上实际执行。不能把这些检查描述成 AYANEO3 实机测试。
