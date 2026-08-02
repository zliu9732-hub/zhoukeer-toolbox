# Decky Installer Gitee Mirror

Decky Loader 安装脚本和二进制的 Gitee 镜像，用于在无法直连 GitHub 时安装 SteamOS 插件商城（Decky Store）。

## 文件说明

- `install_release.sh`：安装稳定版 Decky Loader（v3.2.6）
- `install_prerelease.sh`：安装预发布版 Decky Loader（v3.2.8-pre1，适合 SteamOS 测试版）
- `install_latest.sh`：读取 `latest.txt` 自动安装最新版，Decky 更新后无需改命令
- `latest.txt`：稳定版/预发布版版本、分块 SHA256 和服务模板 SHA256 清单
- `PluginLoader.part.*`：稳定版加载器二进制分块（Gitee raw 对匿名大文件有限制，脚本会自动下载并拼接）
- `PluginLoader-pre.part.*`：预发布版加载器二进制分块
- `plugin_loader-release.service` / `plugin_loader-prerelease.service`：systemd 服务文件
- `SHA256SUMS`：加载器二进制校验值
- `uninstall.sh`：卸载脚本

## Steam Deck 安装

桌面模式打开 Konsole，执行：

```sh
curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/install_release.sh | sh
```

3.9 测试版上稳定版不生效时，改用预发布版：

```sh
curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/install_prerelease.sh | sh
```

自动安装最新版（Decky 更新后命令保持不变）：

```sh
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/install_latest.sh | sh -s -- prerelease
```

稳定版把参数换成 `release`：

```sh
curl -fsSL https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/install_latest.sh | sh -s -- release
```

卸载：

```sh
curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/uninstall.sh | sh
```

## 注意

- `install_release.sh` / `install_prerelease.sh` 的版本号是写死的；`install_latest.sh` 会读取 `latest.txt`，升级时只需替换分块文件并同步更新 `latest.txt`，命令不用改。
- Decky 安装完成后的商城列表加载和 Decky 自更新仍然访问 GitHub；如果这些环节也走不通，需要开代理，或者后续把 `decky-plugin-database` 一起镜像过来再配置自定义源。
