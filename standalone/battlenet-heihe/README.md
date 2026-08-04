# 战网 + 黑盒工坊 独立安装工具

在 Steam Deck 桌面模式下使用，不依赖整个周克儿工具箱。

## 使用方法

一行安装/更新（推荐）：

`curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/standalone/battlenet-heihe/bootstrap.sh | bash`

带目标直接安装：

`curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/standalone/battlenet-heihe/bootstrap.sh | bash -s -- battlenet`

也可以手动下载解压：

1. 解压本包：
   `tar -xzf zhoukeer-battlenet-heihe-*.tar.gz -C ~/`
2. 进入解压目录后运行：
   `bash install.sh`
3. 按菜单选择“战网启动器”或“黑盒工坊”，确认后开始安装。

也可以直接指定目标跳过菜单：

`bash install.sh battlenet`
`bash install.sh heihe`

## 功能

- 战网启动器：自动下载固定分卷的预装客户端，逐卷校验大小与 SHA256，重组后解压到独立 C 盘环境，写入 Steam 库并绑定 Proton 10.0-4，同时创建桌面入口。
- 黑盒工坊：自动从 Gitee 镜像下载固定版本预装客户端并校验 SHA256，解压到战网同一 C 盘环境后自动入库；需要先安装战网启动器。
- 安装过程会校验下载来源、文件格式和完整性；失败时保留旧版本，不会覆盖已安装内容。

## 数据目录

默认优先使用工具箱数据目录 `~/.local/share/zhoukeer-toolbox/apps`，便于复用已安装的战网环境；没有工具箱时使用 `~/.local/share/zhoukeer-battlenet-heihe`。可通过环境变量覆盖：

`ZHOUKEER_APP_DIR=/自定义路径 bash install.sh`

## 注意

- 仅支持 SteamOS/Steam Deck；安装需要联网下载。
- 黑盒工坊需要先安装战网启动器。
