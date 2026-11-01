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
