#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

grep -Fq 'https://www.mhhf.com/Deck/decky/v.3.2.6/PluginLoader' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '30f017a36a8baeb8c3dbae884f5d64be987a9b351b3859bf33e88615b653cf5e' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'https://www.mhhf.com/Deck/decky/plugin_loader-release.service' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '64d6aa626aa45e1659e3137aa3afd72edd840094199d62bb6ff2e73c5ce738b1' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'download_decky_component' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '勾选 Steam 和 GitHub' "$PROJECT_ROOT/modules/steam_accelerator.sh"
grep -Fq 'render_decky_service' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'rollback_decky_install' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
if grep -Fq 'https://www.mhhf.com/Deck/install.sh' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    grep -Fq 'toolbox_sudo bash "$installer"' "$PROJECT_ROOT/modules/plugin_store.sh"; then
    echo "FAIL: 不应继续下载或执行Decky外层安装脚本"
    exit 1
fi
grep -Fq 'DECKY_LSFG_SHA256="13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_FSR4_SHA256="236dc5aef5c908d905a848d7e448689634479ab61cd9184154ba8a725b3f2089"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_CHEATDECK_SHA256="83d1129939e6417fdface46c3a86fe925785509e78b09757839a9c6ea72029f9"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Decky-Framegen/releases/download/v0.15.6/Decky-Framegen.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'CheatDeck/releases/download/v1.2.1/CheatDeck.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'download_github_file "$url" "$output" "$expected_sha256" "$name"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_tree_atomically' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_PLUGIN_DIR:-$HOME/homebrew/plugins' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Lossless Scaling 的 Steam 正版页面' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'steam://store/993090' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'import_lossless_backup' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'steam://install/993090' "$PROJECT_ROOT/modules/plugin_store.sh"

feature_install="$(sed -n '/^install_feature_plugins()/,/^}/p' "$PROJECT_ROOT/modules/plugin_store.sh")"
for install_call in \
    'install_lsfg_zh_from_gitee 0' \
    'install_fsr4_zh_from_gitee 0' \
    'install_configured_plugin cheatdeck 0 0'; do
    printf '%s\n' "$feature_install" | grep -Fq "$install_call" || {
        echo "FAIL: 三件套缺少下载调用：$install_call" >&2
        exit 1
    }
done
store_line="$(printf '%s\n' "$feature_install" | grep -n 'check_lossless_scaling_installation' | tail -n 1 | cut -d: -f1)"
loop_line="$(printf '%s\n' "$feature_install" | grep -n 'done' | head -n 1 | cut -d: -f1)"
[ -n "$store_line" ] && [ -n "$loop_line" ] && [ "$store_line" -gt "$loop_line" ] || {
    echo "FAIL: 小黄鸭正版页面仍在三件套安装中途打开" >&2
    exit 1
}
grep -Fq 'check_lossless_scaling_installation' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '未检测到 Steam 库中的 Lossless Scaling' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '选择名称以 Linux 开头的可用版本' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Steam Deck 机身右下角“三个点（…）”按钮' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_feature_plugins()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'print_feature_plugin_status()' "$PROJECT_ROOT/modules/plugin_store.sh"
feature_install_function="$(sed -n '/^install_feature_plugins()/,/^}/p' \
    "$PROJECT_ROOT/modules/plugin_store.sh")"
printf '%s\n' "$feature_install_function" | grep -Fq 'ensure_plugin_store_ready || return 1' || {
    echo "FAIL: 常用插件组合未先检查插件商城" >&2
    exit 1
}
printf '%s\n' "$feature_install_function" | grep -Fq '小黄鸭（LSFG-VK）'
printf '%s\n' "$feature_install_function" | grep -Fq 'reload_decky_plugins'
printf '%s\n' "$feature_install_function" | grep -Fq '三款插件会出现在插头菜单中'
grep -Fq 'CheatDeck 安装完成后可在 Decky 右侧栏显示' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_all_plugin_packages()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'decky_plugin_store_is_installed()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '未检测到插件商城，先安装插件商城。' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_lsfg_chinese()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'LSFG_RUNTIME_ARCHIVE="lsfg-vk_noui.zip"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'FSR4_RUNTIME_ARCHIVE="Optiscaler_0.9.2a-final.20260517._Reup.7z"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'FSR4 运行核心缺失' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'cp -a -- "$official_bin_dir" "$staged_source/bin"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'cp -a -- "$official_assets_dir" "$staged_source/assets"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '小黄鸭运行核心缺失' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'cp -a -- "$official_runtime" "$staged_source/bin/$LSFG_RUNTIME_ARCHIVE"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_fsr4_chinese()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'restore_lsfg_official()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'LSFG_ZH_INDEX_SHA256="9ea05e9738191cd0e414b4c4a106a836b65170c1f8b32ccdf2ba792514f122d2"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '中文汉化：闲鱼双叶' \
    "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/src/components/Content.tsx"
grep -Fq '"name": "小黄鸭"' \
    "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/plugin.json"
grep -Fq '"name": "Decky-Framegen(FSR4)"' \
    "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.15.6/plugin.json"
grep -Fq '闲鱼双叶' \
    "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.15.6/plugin.json"
grep -Fq '闲鱼双叶汉化' \
    "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.15.6/src/components/OptiScalerControls.tsx"
fsr4_actual_sha256="$(shasum -a 256 "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.15.6/dist/index.js" | awk '{print $1}')"
[ "$fsr4_actual_sha256" = "67022aebf727bc9929258940ea485dc5b6c697cd76a0f59790477ac390ca35f5" ] || {
    echo "FAIL: FSR4 中文构建文件校验值不匹配" >&2
    exit 1
}
grep -Fq '"version": "0.12.5"' \
    "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/package.json"
zh_actual_sha256="$(shasum -a 256 "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/dist/index.js" | awk '{print $1}')"
[ "$zh_actual_sha256" = "9ea05e9738191cd0e414b4c4a106a836b65170c1f8b32ccdf2ba792514f122d2" ] || {
    echo "FAIL: 小黄鸭中文构建文件校验值不匹配" >&2
    exit 1
}
if grep -Eq '^copy_zhoukeer_localizer$' "$PROJECT_ROOT/install.sh"; then
    echo "FAIL: 已停用的扫描式汉化不应继续随安装器复制" >&2
    exit 1
fi
grep -Fq 'copy_lsfg_chinese' "$PROJECT_ROOT/install.sh"
grep -Fq 'toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '旧版通用扫描式汉化已停用' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'features) show_plugin_download_speed_tip; install_feature_plugins' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'feature-status) print_feature_plugin_status' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'uninstall) uninstall_all_decky_plugins' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '不会删除 Decky Loader 本体' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'all) show_plugin_download_speed_tip; install_all_plugin_packages' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '3. 点击启动服务，再返回工具箱重试' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'GitHub 加速源下载完整汉化包' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '将依次安装：小黄鸭（LSFG-VK）、FSR4（Decky Framegen）、CheatDeck。' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
if grep -Fq 'Lossless Scaling.rar' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    grep -Eq 'https?://[^[:space:]]*Lossless' "$PROJECT_ROOT/modules/plugin_store.sh"; then
    echo "FAIL: 付费软件本体不应配置为客户下载源"
    exit 1
fi
if grep -Fqi '云盘' "$PROJECT_ROOT/modules/plugin_store.sh"; then
    echo "FAIL: 插件下载模块不应保留第三方云盘地址"
    exit 1
fi

output="$(bash "$PROJECT_ROOT/modules/plugin_store.sh" lsfg || true)"
printf '%s\n' "$output" | grep -Fq '仅支持真实 SteamOS 环境'

# 小黄鸭官方 v0.12.5 使用 Decky LSFG-VK，旧汉化包使用“小黄鸭”；
# 状态检查必须同时兼容官方名和旧中文名。
PLUGIN_ROOT="$TMP_ROOT/plugins"
for plugin_dir in "Decky LSFG-VK" Decky-Framegen CheatDeck; do
    mkdir -p "$PLUGIN_ROOT/$plugin_dir/dist"
    printf 'bundle\n' > "$PLUGIN_ROOT/$plugin_dir/dist/index.js"
done
printf '{"name":"Decky LSFG-VK"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/plugin.json"
printf '{"version":"0.12.5"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/package.json"
printf '{ "name": "Decky-Framegen" }\n' > "$PLUGIN_ROOT/Decky-Framegen/plugin.json"
printf '{"name": "CheatDeck"}\n' > "$PLUGIN_ROOT/CheatDeck/plugin.json"
status_output="$(DECKY_PLUGIN_DIR="$PLUGIN_ROOT" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status)"
printf '%s\n' "$status_output" | grep -Fq '✓ 小黄鸭（LSFG-VK）：已写入 Decky'
printf '%s\n' "$status_output" | grep -Fq '✓ FSR4（Decky-Framegen）：已写入 Decky'
printf '%s\n' "$status_output" | grep -Fq '✓ CheatDeck：已写入 Decky'

printf '{"name":"小黄鸭"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/plugin.json"
legacy_status_output="$(DECKY_PLUGIN_DIR="$PLUGIN_ROOT" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status)"
printf '%s\n' "$legacy_status_output" | \
    grep -Fq '✓ 小黄鸭（LSFG-VK）：已写入 Decky'

printf '{"version":"0.12.1"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/package.json"
if stale_status_output="$(DECKY_PLUGIN_DIR="$PLUGIN_ROOT" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status)"; then
    echo "FAIL: 旧版小黄鸭不应被识别为官方 0.12.5" >&2
    exit 1
fi
printf '%s\n' "$stale_status_output" | \
    grep -Fq '检测到版本 0.12.1，请重新安装官方 0.12.5'

echo "PASS: Decky国内源、独立功能插件和完整清单配置检查通过"
