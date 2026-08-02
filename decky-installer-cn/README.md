# Decky Installer Gitee Mirror

Decky Loader 安装脚本和二进制的 Gitee 镜像，用于在无法直连 GitHub 时安装 SteamOS 插件商城（Decky Store）。

## 文件说明

- `install_release.sh`：安装稳定版 Decky Loader（v3.2.6）
- `install_prerelease.sh`：安装预发布版 Decky Loader（v3.2.8-pre1，适合 SteamOS 测试版）
- `PluginLoader`：稳定版加载器二进制
- `PluginLoader-pre`：预发布版加载器二进制
- `plugin_loader-release.service` / `plugin_loader-prerelease.service`：systemd 服务文件
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

卸载：

```sh
curl -L https://gitee.com/zliu9732-hub/zhoukeer-toolbox/raw/main/decky-installer-cn/uninstall.sh | sh
```

## 注意

- 版本号是写死的，升级时需要手动替换 `PluginLoader` 二进制并更新脚本中的 `VERSION`。
- Decky 安装完成后的商城列表加载和 Decky 自更新仍然访问 GitHub；如果这些环节也走不通，需要开代理，或者后续把 `decky-plugin-database` 一起镜像过来再配置自定义源。
