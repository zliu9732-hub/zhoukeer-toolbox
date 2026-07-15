#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

grep -Fq 'https://www.mhhf.com/Deck/decky/v.3.2.6/PluginLoader' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'https://www.mhhf.com/Deck/decky/plugin_loader-release.service' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'download_decky_component' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'render_decky_service' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'rollback_decky_install' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
if grep -Fq 'https://www.mhhf.com/Deck/install.sh' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    grep -Fq 'toolbox_sudo bash "$installer"' "$PROJECT_ROOT/modules/plugin_store.sh"; then
    echo "FAIL: 不应继续下载或执行Decky外层安装脚本"
    exit 1
fi
grep -Fq 'DECKY_LSFG_SHA256="5355c6df656775fa467445c7787604bc159b8d8b97e5364bedb02a5d2e0ab677"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_FSR4_SHA256="236dc5aef5c908d905a848d7e448689634479ab61cd9184154ba8a725b3f2089"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_CHEATDECK_SHA256="83d1129939e6417fdface46c3a86fe925785509e78b09757839a9c6ea72029f9"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'install_tree_atomically' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Lossless Scaling 的 Steam 正版页面' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'steam://store/993090' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'import_lossless_backup' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'steam://install/993090' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'check_lossless_scaling_installation' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '未检测到 Steam 库中的 Lossless Scaling' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '选择名称以 Linux 开头的可用版本' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Steam Deck 机身右下角“三个点（…）”按钮' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_feature_plugins()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'print_feature_plugin_status()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'CheatDeck 的入口在游戏库中选中游戏后的齿轮/右键菜单内' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_all_plugin_packages()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_zhoukeer_localizer()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'copy_zhoukeer_localizer' "$PROJECT_ROOT/install.sh"
grep -Fq '"$source_dir/dist/index.js"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'localizer) install_zhoukeer_localizer' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'features) install_feature_plugins' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'feature-status) print_feature_plugin_status' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'all) install_all_plugin_packages' "$PROJECT_ROOT/modules/plugin_store.sh"
if grep -Fq 'Lossless Scaling.rar' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    grep -Fq '1846467258.cdn.123clouddisk.com/1846467258/工具箱/Lossless' \
        "$PROJECT_ROOT/modules/plugin_store.sh"; then
    echo "FAIL: 付费软件本体不应配置为客户下载源"
    exit 1
fi

output="$(bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg || true)"
printf '%s\n' "$output" | grep -Fq '仅支持真实 SteamOS 环境'

echo "PASS: Decky国内源、独立功能插件和完整清单配置检查通过"
