# 夸克网盘

SteamOS 入口：常用软件 → 更多常用软件 → 夸克网盘（第一页，百度网盘下方）。图形菜单也有同名入口，用于上传、下载和管理夸克网盘文件。安装后从桌面或应用菜单打开并登录夸克账号。

官网目前提供 Windows 和 macOS 图形客户端。这里安装官方 Windows 完整包，复用 Epic 等启动器的国内下载、备用官方请求、安装位置选择和 Proton 准备；不把命令行工具或网页入口当作桌面客户端。

## 固定来源

- 官方下载页面：<https://pan.quark.cn/>，下载信息来自页面实际使用的 <https://pan.quark.cn/api/client_version>。
- 已核对版本：7.4.2.820，官网发布名 7.4.2。官方 `winInstallerUrl` 指向 `umcdn.quark.cn` 的完整包，包内版本资源标识为“夸克网盘”，安装器为 Inno Setup 6.1。
- 原包大小：324871184 字节；SHA256：`a2e1d6a095d938addc1da8e43faacea6a088023e7075cb694e1b6547b2934fd9`。安装包保持原字节，不修改客户端、不添加汉化署名。
- 国内分发复用 Gitee 清单与分块下载器，`quark` 路由位于自有 `zhoukeer-toolbox-mirror-6`。原包按 8 MiB 拆成 39 块，重组后仍须匹配上述 SHA256。
- 国内线路失败回退同版本固定官方地址。两条线路均检查文件类型、大小与相同 SHA256；失败保留原有安装器，不执行下载错误页或不匹配的文件。
- 图标为官网 favicon 原图：`https://image.quark.cn/s/uae/g/3o/broccoli/resource/202602/f6439020-13b4-11f1-9342-3944993de2f6.png`，未修改。

## 安装与维护

先确认下载完整，再准备运行环境并打开官方安装窗口；指定虚拟目录，确认主程序存在后才生成入口。已有程序会跳过下载和安装，只修复 Renkit 管理的入口。部分安装保留原目录继续处理；原外接存储不可用时停止，避免丢失账号数据位置。同名非 Renkit 入口及异常链接不覆盖。

程序和账号数据沿用启动器的用户目录布局，安装过程不切换 SteamOS 只读状态，不使用管理员权限安装客户端，不重启 Steam。Proton 缺失时沿用现有 Steam 安装流程。

再次点击安装可以恢复入口。维护命令 `bash modules/quark.sh remove-shortcuts` 仅移除 Renkit 创建的桌面和应用菜单入口，保留程序、账号及下载文件。

更新固定包时，应从官网重新核对完整安装包、版本、类型和 SHA256，修改 `launcher_details quark` 中的固定来源与校验值。使用现有 `scripts/mirror_gitee_assets.sh --local` 生成 `quark` 清单与分块，再以正常新增提交同步到 mirror-6；从公开地址取回全部分块并重组校验通过后才能发布 Renkit。不把二进制放入 Renkit 主仓库或 v2 更新源。

`tests/test_quark.sh` 使用临时文件和模拟 Proton，覆盖安装、安装失败、重复安装、入口修复、版本目录、下载回退、损坏包拒绝、数据保留和异常路径；不执行官方 Windows 安装器。实际 SteamOS 运行仍需要实机验证。
