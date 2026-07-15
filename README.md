# 周克儿工具箱 V4

周克儿工具箱是面向 Steam Deck / SteamOS 的 Bash 工具箱，提供一键新机初始化、常用软件、远程协助、插件商城、系统维护和安全更新入口。

远程协助中提供 RustDesk、AnyDesk 和 ToDesk。RustDesk 与 AnyDesk 通过用户级 Flatpak 安装并自动创建桌面图标，不会修改 SteamOS 只读系统分区；RustDesk 不会被工具箱自动写入任何服务器配置。

## 使用说明与免责声明

本脚本由“闲鱼：超级妹宝双叶”制作，支持所有人免费使用。禁止商业使用、销售、转卖，或以本工具箱直接或间接盈利。工具箱内收录的下载内容均为官方免费发布或开源内容，不包含付费软件本体、破解内容或商业授权；第三方软件和插件仍以各自许可证及使用条款为准。部分国内下载分流由作者本人的123云盘提供；喜欢本工具，欢迎来闲鱼支持作者。若有侵权，请及时联系作者删除。启动工具箱后须点击“知悉并开始使用”方可进入首页。

## 功能

- 一键新机初始化：一次确认后依次检查SteamOS和网络，并自动执行当前清单中的新机常用项目。
- 插件商城：下载并校验Decky国内镜像安装器后启动安装；小黄鸭、FSR4和CheatDeck使用123云盘国内分流一键安装。小黄鸭安装完成后可打开Lossless Scaling的Steam正版页面；已经合法取得本地备份的用户也可自行选择压缩包导入，随后由Steam验证授权和文件。
- 常用软件：微信、QQ和Chrome浏览器优先通过中科大Flathub缓存进行用户级安装，失败后切换官方源；安装成功后自动创建桌面快捷方式，不修改SteamOS只读分区。
- ToDesk：使用固定的第三方SteamOS适配包并校验SHA256，安装完成后恢复只读保护。
- Steam Deck 优化：清理 Steam 下载缓存、着色器缓存，并提供性能模式提示。
- 国内下载源：添加用户级Flathub国内缓存，同时保留官方Flathub作为备用，不修改SteamOS只读系统分区。
- Steam加速器：使用Steamcommunity 302官方Linux AMD64固定安装包；工具箱只负责安装，不会自动启用加速服务。
- 系统密码：支持设置或修改当前SteamOS用户密码，并可启用用户明确选择的明文密码便利模式。
- 安全清理：清理前必须确认，避免误删。
- 一键修复模式：执行网络检测、Steam 下载缓存清理建议和 DNS 处理提示。
- 更新日志：可在工具箱内用触屏查看当前版本的主要改动。
- 更新工具箱：优先从Gitee获取固定更新包和SHA256，失败后切换GitHub；缺少有效校验时拒绝执行。
- 纯触控界面：大按钮支持触屏和触控板，菜单忽略键盘数字和字母输入。
- 专用视觉主题：安装时自动配置大字体、深色遮罩和工具箱背景图，不修改其他 Konsole 会话。

## 主菜单

Steam Deck桌面快捷方式会通过兼容启动器打开约 `1220×740` 的双栏 Konsole 界面，并使用 17 号字体和最多 20 行的紧凑布局。直接运行 `main.sh` 也会自动转入专用主题窗口。启动器会先检查当前 Konsole 是否支持工具箱主题，不支持时自动回退到基础启动方式。免责声明使用独立页面，确认按钮始终保留在可见区域；左侧分类、右侧功能和确认按钮都是两行高的大点击区，只响应触屏或触控板，不显示也不接受数字/字母菜单输入。管理员验证可使用下文说明的密码便利模式；记录缺失、失效或系统拒绝自动验证时，仍会显示SteamOS原生密码提示。

## 一行命令安装

在 Steam Deck 桌面模式打开 Konsole，推荐使用更短的 Gitee 国内入口：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/i|sh
```

完整入口：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/bootstrap.sh | bash
```

GitHub 备用源：

```bash
curl -fsSL https://raw.githubusercontent.com/zliu9732-hub/zhoukeer-toolbox/main/bootstrap.sh | bash
```

未来绑定域名后，目标形式是：

```bash
curl -fsSL https://我的域名/i | bash
```

默认安装目录：

```bash
${HOME}/.local/share/zhoukeer-toolbox
```

安装前预演，不修改文件：

```bash
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/bootstrap.sh | bash -s -- --dry-run
```

安装完成后会创建：

- 桌面快捷方式：`~/Desktop/周克儿工具箱.desktop`
- 应用菜单入口：`~/.local/share/applications/zhoukeer-toolbox.desktop`

桌面快捷方式会使用项目中的 `assets/icon.png`。

如果桌面快捷方式提示不受信任，请右键选择允许启动。

## 运行

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/main.sh"
```

## ToDesk说明

用户提供的 `curl -L todesk.lanbai.top | sh` 会继续下载可变脚本、关闭SteamOS只读保护并使用pacman安装第三方软件包。本工具不会直接执行这条管道命令，而是固定已审查的 `mclanbai/archtodesk` 提交和ToDesk 4.7.2.0软件包SHA256。安装前会明确提示风险并要求管理员验证，完成后尝试恢复只读保护。

ToDesk并非SteamOS原生软件，SteamOS系统更新可能移除通过pacman安装的内容。工具不会删除已有ToDesk用户配置，也不会使用 `chmod 777`。

首次使用ToDesk前，必须先在Steam Deck游戏模式中完成：按 `Steam` 键进入“设置 → 系统”，开启“启用开发者模式”；随后从设置侧栏进入“开发者”，在“杂项”中开启“使用旧版X11桌面模式”，再重新进入桌面模式。工具箱会把这套步骤做成安装前的强制触控说明页，顾客确认两项开关均已开启后才能继续安装。

## Steam加速器说明

工具箱安装的是Steamcommunity 302官方提供的Linux AMD64固定安装包，不使用来源不明的二次打包。安装过程可能需要root权限；实际启用加速时，Steamcommunity 302可能修改本机hosts或DNS、安装自签根证书，并通过本机HTTPS代理处理请求。使用前请阅读官方界面中的说明，退出或卸载前也应按官方方式恢复相关设置。

工具箱本身只完成安装，不会自动开启加速服务，也不会替用户确认上述系统改动。需要自动运行时，请在Steamcommunity 302官方GUI中自行选择“开机运行—后台服务(无界面)”。

## SteamOS密码便利模式

“设置系统密码”和“修改系统密码”会更新当前SteamOS用户的密码，并将新密码以明文写入：

```text
$HOME/Desktop/密码.txt
```

该文件权限固定为 `600`，只有当前用户可以直接读取。工具箱会读取它，并且仅在工具箱自身需要管理员权限时用于sudo自动验证；密码不会写入工具箱日志、不会上传、不会加入安装包或Git仓库，也不会用于其他程序。

这是用户明确选择的便利模式，不是加密密码管理。任何已经取得当前SteamOS用户访问权限的人，都可能读取该文件；分享设备、远程协助或发送诊断资料前请注意保护。若密码被再次手动修改，应同步更新该文件，否则自动验证会失败并回到系统原生密码提示。

## 更新

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/update.sh"
```

更新脚本会下载发布包，完成 SHA256 校验后调用安装器。安装器先在同级暂存目录准备完整新版本，再切换安装目录；准备或切换失败时保留、恢复旧版本。安装器会保留已有非空配置，并在更新时清除已经退役的 RustDesk 服务器字段。

预演更新：

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/update.sh" --dry-run
```

## 卸载

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/uninstall.sh"
```

卸载脚本会先确认，删除前可选择保留用户配置和日志。

预演卸载：

```bash
bash "${HOME}/.local/share/zhoukeer-toolbox/uninstall.sh" --dry-run
```

## 发布 GitHub Release

建议发布流程：

1. 确认 `bash -n` 检查通过。
2. 确认 `config/settings.conf` 不包含私人配置。
3. 执行 `bash scripts/package_release.sh` 生成发布包、`.sha256` 和 `SHA256SUMS` 校验文件。
4. 提交代码并打 tag，例如 `v4.0.0`。
5. 在 GitHub Release 中上传发布包和 `.sha256` 校验文件。
6. 在 Release 中写明安装、更新、卸载命令。
7. 不要在 Release 包中包含密码、Token、邮箱或个人路径；桌面的 `密码.txt` 仅在用户设备本地生成。

`bootstrap.sh` 和 `update.sh` 支持通过环境变量指定正式发布包：

```bash
ZHOUKEER_GITEE_PACKAGE_URL="https://example.com/zhoukeer-toolbox.tar.gz" \
ZHOUKEER_GITEE_CHECKSUM_URL="https://example.com/SHA256SUMS" \
ZHOUKEER_SHA256="发布包sha256" \
bash bootstrap.sh
```

默认下载顺序：

1. Gitee项目内固定包：`dist/zhoukeer-toolbox.tar.gz`
2. GitHub项目内相同固定包：`dist/zhoukeer-toolbox.tar.gz`

安装包必须与同一来源的 `dist/SHA256SUMS` 匹配，否则安装或更新会停止。

## 需要在真实 Steam Deck 上测试

- 桌面快捷方式是否能通过 Konsole 打开工具箱。
- SteamOS 是否能正确识别。
- Steam 下载缓存和着色器缓存路径是否符合当前 SteamOS 版本。
- ToDesk安装后是否恢复SteamOS只读保护、服务是否启动、桌面入口是否存在。
- Decky、微信、QQ和Chrome浏览器在当前SteamOS版本是否能正常安装、创建桌面快捷方式并启动。
- 用户级Flathub国内缓存是否可用，官方Flathub备用源是否仍然保留。
- Steamcommunity 302官方Linux AMD64包是否能正常安装；用户在官方GUI启用“开机运行—后台服务(无界面)”后是否按预期启动，以及退出/卸载后hosts、DNS、证书和本机代理是否正确恢复。
- 设置/修改SteamOS密码后，桌面 `密码.txt` 是否为明文新密码且权限为 `600`；工具箱sudo自动验证失败时是否安全回退到系统原生提示。
- 更新菜单能否从Gitee下载并验证固定更新包，Gitee失败时能否切换GitHub。
- 游戏模式/桌面模式之间的菜单显示和中文字体是否正常。
