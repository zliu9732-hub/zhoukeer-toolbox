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
grep -Fq 'releases/download/v3.2.8-pre1/PluginLoader' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '9df160a81df3fc49c96e5665a1d1b3ba5c79de5bf271adc266d6bfedfda399d8' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'v3.2.8-pre1/dist/plugin_loader-prerelease.service' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'store-test) show_plugin_download_speed_tip; install_plugin_store prerelease' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'download_decky_gitee_loader' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 测试版未接入 Gitee 国内镜像加载流程" >&2
    exit 1
}
grep -Fq 'download_decky_gitee_service' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 测试版未接入 Gitee 国内镜像服务模板" >&2
    exit 1
}
grep -Fq 'load_decky_gitee_mirror_meta' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 测试版未读取 Gitee 镜像版本清单" >&2
    exit 1
}
grep -Fq 'DECKY_GITEE_MIRROR_META' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 测试版缺少 Gitee 镜像清单地址" >&2
    exit 1
}
grep -Fq 'download_decky_prerelease_component' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 测试版 Gitee 失败后缺少官方 Release 回退" >&2
    exit 1
}
grep -Fq 'ensure_steam302_for_download' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 测试版下载缺少 Steam302 加速重试" >&2
    exit 1
}
grep -Fq 'systemctl --user disable --now "$DECKY_SERVICE_NAME"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'download_decky_component' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '下载较慢，正在启用加速，请耐心等待' "$PROJECT_ROOT/modules/steam_accelerator.sh"
grep -Fq 'render_decky_service' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'rollback_decky_install' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'systemctl stop "$DECKY_SERVICE_NAME"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'toolbox_sudo systemctl restart "$DECKY_SERVICE_NAME"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
decky_component_download="$(sed -n '/^download_decky_component()/,/^}/p' \
    "$PROJECT_ROOT/modules/plugin_store.sh")"
if printf '%s\n' "$decky_component_download" | grep -Fq -- '--retry-all-errors'; then
    echo "FAIL: Decky 组件下载仍会重复重试确定的 404/403 错误" >&2
    exit 1
fi
grep -Fq 'download_progress_filter "$name"' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 组件下载未使用实时速度过滤" >&2
    exit 1
}
printf '%s\n' "$decky_component_download" | grep -Fq -- '--speed-limit 65536' || {
    echo "FAIL: Decky 组件下载缺少低速中断保护" >&2
    exit 1
}
printf '%s\n' "$decky_component_download" | grep -Fq -- '--speed-time 60' || {
    echo "FAIL: Decky 组件下载缺少低速中断时长" >&2
    exit 1
}
printf '%s\n' "$decky_component_download" | grep -Fq -- '--progress-meter' || {
    echo "FAIL: Decky 组件下载缺少实时速度显示" >&2
    exit 1
}
grep -Fq '下载失败，切换备用源。' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: Decky 插件下载缺少原有备用源提示" >&2
    exit 1
}
grep -Fq 'modules/steam_accelerator.sh" ensure' "$PROJECT_ROOT/modules/plugin_store.sh" || {
    echo "FAIL: 插件下载失败后没有自动启用加速重试" >&2
    exit 1
}
if grep -Fq 'https://www.mhhf.com/Deck/install.sh' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    grep -Fq 'toolbox_sudo bash "$installer"' "$PROJECT_ROOT/modules/plugin_store.sh"; then
    echo "FAIL: 不应继续下载或执行Decky外层安装脚本"
    exit 1
fi
grep -Fq 'DECKY_LSFG_SHA256="13b8c8de5744a4fcf300e85971cb0c110f0734cb2db508c8de6309bbf8298a07"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_FSR4_SHA256="3300b617e3d979b483d03f995c75c829d6d54beaa4ac8dfae300c2560e4fc60f"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_CHEATDECK_SHA256="83d1129939e6417fdface46c3a86fe925785509e78b09757839a9c6ea72029f9"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'DECKY_TOMOON_SHA256="5500e6ed2d110b0e077b9eba3f1908eb50593483e51158b9351978d9a03191a6"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'decky-lsfg-vk/releases/download/v0.12.5/Decky.LSFG-VK.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Decky-Framegen/releases/download/v0.17/Decky-Framegen.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'CheatDeck/releases/download/v1.2.1/CheatDeck.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'YukiCoco/ToMoon/releases/download/v0.2.8/tomoon-v0.2.8.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Ren-Amamiya-pixle/DeckRecall/releases/download/v0.2.3/DeckRecall.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '9171a8a656f0900014cafddeb8c81806de5fbe376bf66ec78f595bebe85d96d0' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_DECKRECALL_SHA256="9171a8a656f0900014cafddeb8c81806de5fbe376bf66ec78f595bebe85d96d0"' \
    "$PROJECT_ROOT/config/settings.example.conf"
grep -Fq 'resolve_deckrecall_latest' "$PROJECT_ROOT/modules/plugin_store.sh"
deckrecall_install="$(sed -n '/^[[:space:]]*deckrecall)/,/^[[:space:]]*;;/p' "$PROJECT_ROOT/modules/plugin_store.sh")"
printf '%s\n' "$deckrecall_install" | grep -Fq '"DeckRecall"' || {
    echo "FAIL: DeckRecall 未校验发布包插件目录" >&2
    exit 1
}
grep -Fq 'mubaraknumann/unifideck/releases/download/Release-0.7.2/unifideck.prod.v0.7.2.zip' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'a313be924cabe15255d222742a402cd98cb510a35dfe4b2d06cf1e59366936de' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
unifideck_install="$(sed -n '/^[[:space:]]*unifideck)/,/^[[:space:]]*;;/p' \
    "$PROJECT_ROOT/modules/plugin_store.sh" | head -n 16)"
printf '%s\n' "$unifideck_install" | grep -Fq 'resolve_plugin_latest unifideck' || {
    echo "FAIL: Unifideck 安装前未自动检测最新 Release" >&2
    exit 1
}
printf '%s\n' "$unifideck_install" | grep -Fq 'ensure_steam302_for_download' || {
    echo "FAIL: Unifideck 大包下载前未先检查 Steam302 加速" >&2
    exit 1
}
printf '%s\n' "$unifideck_install" | grep -Fq 'GITHUB_MIN_SPEED_TIME=20' || {
    echo "FAIL: Unifideck 下载仍会长时间等待低速来源" >&2
    exit 1
}
printf '%s\n' "$unifideck_install" | grep -Fq '"Unifideck"' || {
    echo "FAIL: Unifideck 未使用官方压缩包中的大写目录" >&2
    exit 1
}
grep -Fq 'Freedeck/releases/download/0.6/freedeck.v.0.6.zip' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '04329d07761c42cc481e97ddd4fc180fa51eb1d0388761424a8c90a18a822c62' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '"freedeck-plugin"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'releases/download/v6.0.9/Decky-LSFG-VK-XiaoHuangYa-v0.12.5.zip' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'releases/download/v1.2.2/Decky-Framegen-FSR4-v0.17.zip' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_LSFG_ZH_SHA256="11e3c13673e19662364cd86d77d6df7bf636c026ccaa2842421c37b982f73277"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'DECKY_FSR4_ZH_SHA256="dde3fe2d77f3021f2841d9dba31b5fa6a741fc08ba9639508787b20054268608"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'download_github_file "$url" "$output" "$expected_sha256" "$name"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox/repository/archive/v6.0.4.zip' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'cbe50c9dcd64bba1433713c1945ec73de2fa1cc51f8a8327ef0f9cdd0ace147a' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_decky_zip_from_gitee_archive' "$PROJECT_ROOT/modules/plugin_store.sh"
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
grep -Fq '风灵月影，小黄鸭，FSR4使用教程.txt' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'FSR4支持游戏名单.txt' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'BV1ew411J7ab' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '败家君的游戏屋' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '找到“LSFG-VK”开关并打开' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '找到“OptiScaler”开关并打开' "$PROJECT_ROOT/modules/plugin_store.sh"
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
grep -Fq '风灵月影网址.txt' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '若返回游戏模式后没有看到 Decky 的插头图标' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'Steam 键 → 设置 → 启用开发者模式' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '设置左侧出现“开发者”后 → 开发者 → 杂项' "$PROJECT_ROOT/modules/plugin_store.sh"
NOTE_DESKTOP="$TMP_ROOT/note-desktop"
PROJECT_ROOT="$PROJECT_ROOT" ZHOUKEER_DESKTOP_DIR="$NOTE_DESKTOP" bash -c '
    source "$PROJECT_ROOT/modules/plugin_store.sh"
    write_flingtrainer_desktop_note
' || {
    echo "FAIL: 无法生成风灵月影网址桌面文件" >&2
    exit 1
}
grep -Fxq 'flingtrainer.com' "$NOTE_DESKTOP/风灵月影网址.txt" || {
    echo "FAIL: 风灵月影网址桌面文件内容错误" >&2
    exit 1
}
grep -Fq '英文搜索并下载对应游戏的最新修改器' "$NOTE_DESKTOP/风灵月影网址.txt" || {
    echo "FAIL: 风灵月影网址桌面文件缺少使用说明" >&2
    exit 1
}
grep -Fq 'install_all_plugin_packages()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'decky_plugin_store_is_installed()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '未检测到插件商城，先安装插件商城。' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_lsfg_chinese()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'LSFG_RUNTIME_ARCHIVE="lsfg-vk_noui.zip"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'FSR4_RUNTIME_ARCHIVE="Optiscaler_0.9.4-final.20260718._MM.7z"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'FSR4 运行核心缺失' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'cp -a -- "$official_bin_dir" "$staged_source/bin"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'cp -a -- "$official_assets_dir" "$staged_source/assets"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '小黄鸭运行核心缺失' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'cp -a -- "$official_runtime" "$staged_source/bin/$LSFG_RUNTIME_ARCHIVE"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'install_fsr4_chinese()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'restore_lsfg_official()' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'LSFG_ZH_INDEX_SHA256="947c3aa91eec580ad10b69174b87cd4e97ac86e320e40bc8d2e78712b298b220"' \
    "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '中文汉化：Ren-Amamiya-pixie / zliu9732-hub（闲鱼RenAmamiya）' \
    "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/src/components/Content.tsx"
[ "$(grep -Fc 'Ren-Amamiya-pixie / zliu9732-hub（闲鱼RenAmamiya）汉化' "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/src/components/Content.tsx")" -ge 1 ] || {
    echo "FAIL: 小黄鸭插件打开后缺少可见汉化署名" >&2
    exit 1
}
grep -Fq '"name": "小黄鸭"' \
    "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/plugin.json"
grep -Fq '"name": "Decky-Framegen(FSR4)"' \
    "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.17/plugin.json"
grep -Fq 'Ren-Amamiya-pixie / zliu9732-hub（闲鱼RenAmamiya）' \
    "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.17/plugin.json"
grep -Fq 'Ren-Amamiya-pixie / zliu9732-hub（闲鱼RenAmamiya）汉化' \
    "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.17/src/components/OptiScalerControls.tsx"
[ "$(grep -Fc 'Ren-Amamiya-pixie / zliu9732-hub（闲鱼RenAmamiya）汉化' "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.17/src/components/OptiScalerControls.tsx")" -ge 2 ] || {
    echo "FAIL: FSR4 插件打开后缺少单独可见的汉化署名" >&2
    exit 1
}
fsr4_actual_sha256="$(shasum -a 256 "$PROJECT_ROOT/third_party/decky-framegen-zh-v0.17/dist/index.js" | awk '{print $1}')"
[ "$fsr4_actual_sha256" = "b1e2820aeb31fdb6f63a3ae622c04a49951b582e44b3225781ea2211bddb7814" ] || {
    echo "FAIL: FSR4 中文构建文件校验值不匹配" >&2
    exit 1
}
grep -Fq '"version": "0.12.5"' \
    "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/package.json"
zh_actual_sha256="$(shasum -a 256 "$PROJECT_ROOT/third_party/decky-lsfg-vk-zh-v0.12.5/dist/index.js" | awk '{print $1}')"
[ "$zh_actual_sha256" = "947c3aa91eec580ad10b69174b87cd4e97ac86e320e40bc8d2e78712b298b220" ] || {
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
grep -Fq 'tomoon) show_plugin_download_speed_tip; install_configured_plugin tomoon' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'deckrecall) show_plugin_download_speed_tip; install_configured_plugin deckrecall' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '"tomoon"' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'feature-status) print_feature_plugin_status' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'uninstall) uninstall_all_decky_plugins' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '不会删除 Decky Loader 本体' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq 'all) show_plugin_download_speed_tip; install_all_plugin_packages' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '正在安装小黄鸭' "$PROJECT_ROOT/modules/plugin_store.sh"
grep -Fq '正在安装 FSR4' "$PROJECT_ROOT/modules/plugin_store.sh"
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
printf '{"version":"0.17.0"}\n' > "$PLUGIN_ROOT/Decky-Framegen/package.json"
printf '{"name": "CheatDeck"}\n' > "$PLUGIN_ROOT/CheatDeck/plugin.json"
status_output="$(DECKY_PLUGIN_DIR="$PLUGIN_ROOT" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status)"
printf '%s\n' "$status_output" | grep -Fq '✓ 小黄鸭（LSFG-VK）：已写入 Decky'
printf '%s\n' "$status_output" | grep -Fq '✓ FSR4（Decky-Framegen）：已写入 Decky，官方版本 0.17.0'
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
    grep -Fq '检测到版本 0.12.1，请更新到 0.12.5'

printf '{"version":"0.12.5"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/package.json"
printf '{"version":"0.16.9"}\n' > "$PLUGIN_ROOT/Decky-Framegen/package.json"
if stale_fsr4_status_output="$(DECKY_PLUGIN_DIR="$PLUGIN_ROOT" \
    bash "$PROJECT_ROOT/modules/plugin_store.sh" feature-status)"; then
    echo "FAIL: 旧版 FSR4 不应被识别为官方 0.17.0" >&2
    exit 1
fi
printf '%s\n' "$stale_fsr4_status_output" | \
    grep -Fq '检测到版本 0.16.9，请更新到 0.17.0'

# 整组安装必须把同名旧版送入更新流程，不能只凭名称和目录跳过。
printf '{"version":"0.12.1"}\n' > "$PLUGIN_ROOT/Decky LSFG-VK/package.json"
update_output="$(
    DECKY_PLUGIN_DIR="$PLUGIN_ROOT" PROJECT_ROOT="$PROJECT_ROOT" bash -c '
        source "$PROJECT_ROOT/modules/plugin_store.sh"
        detect_platform() { IS_STEAMOS=1; }
        ensure_plugin_store_ready() { return 0; }
        install_lsfg_zh_from_gitee() {
            printf '\''{"version":"%s"}\n'\'' "$LSFG_OFFICIAL_VERSION" > \
                "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY/package.json"
            echo "TEST_UPDATE: LSFG"
        }
        install_fsr4_zh_from_gitee() {
            printf '\''{"version":"%s"}\n'\'' "$FSR4_OFFICIAL_VERSION" > \
                "$DECKY_PLUGIN_DIR/$FSR4_OFFICIAL_DIRECTORY/package.json"
            echo "TEST_UPDATE: FSR4"
        }
        refresh_feature_usage_guides() { return 0; }
        reload_decky_plugins() { return 0; }
        check_lossless_scaling_installation() { return 0; }
        write_flingtrainer_desktop_note() { return 0; }
        print_cef_remote_debugging_tip() { return 0; }
        install_feature_plugins
    '
)"
printf '%s\n' "$update_output" | grep -Fq 'TEST_UPDATE: LSFG'
printf '%s\n' "$update_output" | grep -Fq 'TEST_UPDATE: FSR4'
printf '%s\n' "$update_output" | grep -Fq '官方版本 0.12.5'
printf '%s\n' "$update_output" | grep -Fq '官方版本 0.17.0'

echo "PASS: Decky国内源、独立功能插件和完整清单配置检查通过"
