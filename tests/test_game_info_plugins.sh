#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

PLUGIN_ROOT="$TEST_ROOT/plugins"
CALL_LOG="$TEST_ROOT/install.log"
RELOAD_LOG="$TEST_ROOT/reload.log"
mkdir -p "$PLUGIN_ROOT"

export DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
export ZHOUKEER_TEST_MODE=1
# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/plugin_store.sh"

detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; }
reload_decky_plugins() { printf '%s\n' "$1" >> "$RELOAD_LOG"; }
calculate_decky_sha256() {
    local path="$1"
    [ -s "$path" ] || return 1
    case "$path" in
        */bin/plugin-dependencies.tar.gz)
            printf '%s\n' "$DECKY_TRANSLATOR_DEPENDENCIES_SHA256"
            ;;
        *)
            shasum -a 256 "$path" | awk '{print $1}'
            ;;
    esac
}
install_decky_zip_from_mirror() {
    local display_name="$1" mirror_id="$2" package_sha="$3" directory="$4"
    local source_dir
    printf '%s|%s|%s|%s|%s\n' \
        "${GITEE_MIRROR_REPO:-}" "$display_name" "$mirror_id" "$package_sha" "$directory" \
        >> "$CALL_LOG"
    [ "${SIMULATE_MIRROR_FAILURE:-0}" != "1" ] || return 1
    case "$directory" in
        SteamDBButton) source_dir="$PROJECT_ROOT/third_party/steamdb-button-zh-v0.0.1" ;;
        decky-translator) source_dir="$PROJECT_ROOT/third_party/decky-translator-zh-v0.8.0" ;;
        *) return 1 ;;
    esac
    rm -rf -- "$PLUGIN_ROOT/$directory"
    mkdir -p "$PLUGIN_ROOT/$directory"
    cp -a -- "$source_dir/package.json" "$source_dir/plugin.json" "$source_dir/main.py" "$source_dir/dist" \
        "$PLUGIN_ROOT/$directory/"
    if [ "$directory" = "decky-translator" ]; then
        mkdir -p "$PLUGIN_ROOT/$directory/bin"
        printf '%s\n' 'mock dependencies' > \
            "$PLUGIN_ROOT/$directory/bin/plugin-dependencies.tar.gz"
    fi
}

install_game_info_plugin_from_gitee steamdb-info
install_game_info_plugin_from_gitee decky-translator

[ "$(wc -l < "$CALL_LOG" | tr -d ' ')" = "2" ] || fail "两款插件未各安装一次"
[ "$(wc -l < "$RELOAD_LOG" | tr -d ' ')" = "2" ] || fail "安装后未各重载一次 Decky"
grep -Fq 'zhoukeer-toolbox-mirror-3|SteamDB 游戏数据|steamdb-game-info-zh|cb072edfbed3e30abec76fc25ce74653380594feecba81e61284d72563b082bf|SteamDBButton' "$CALL_LOG" || \
    fail "SteamDB 未固定使用 mirror-3 分块包"
grep -Fq 'zhoukeer-toolbox-mirror-3|沉浸式翻译|decky-translator-zh|a9e63de07bf01dcf27f8292cd5bb2b6488d08205d94ae323730a070f4b3002cd|decky-translator' "$CALL_LOG" || \
    fail "沉浸式翻译未固定使用 mirror-3 分块包"

# 第二次执行必须通过版本、名称和前端哈希直接跳过。
install_game_info_plugin_from_gitee steamdb-info
install_game_info_plugin_from_gitee decky-translator
[ "$(wc -l < "$CALL_LOG" | tr -d ' ')" = "2" ] || fail "重复执行仍重新下载插件"
[ "$(wc -l < "$RELOAD_LOG" | tr -d ' ')" = "2" ] || fail "重复执行仍重载 Decky"

# 镜像失败时不得触碰现有插件，也不得显示成功或触发重载。
printf '%s\n' 'keep-existing' > "$PLUGIN_ROOT/SteamDBButton/existing.marker"
printf '%s\n' '{"version":"old"}' > "$PLUGIN_ROOT/SteamDBButton/package.json"
SIMULATE_MIRROR_FAILURE=1
export SIMULATE_MIRROR_FAILURE
if install_game_info_plugin_from_gitee steamdb-info; then
    fail "mirror-3 失败仍返回成功"
fi
[ "$(cat "$PLUGIN_ROOT/SteamDBButton/existing.marker")" = "keep-existing" ] || \
    fail "mirror-3 失败后现有插件被改动"
[ "$(wc -l < "$RELOAD_LOG" | tr -d ' ')" = "2" ] || fail "mirror-3 失败仍重载 Decky"

function_text="$(sed -n '/^install_game_info_plugin_from_gitee()/,/^}/p' \
    "$PROJECT_ROOT/modules/plugin_store.sh")"
printf '%s\n' "$function_text" | grep -Fq 'install_decky_zip_from_mirror' || \
    fail "游戏信息插件未调用分块安装器"
if printf '%s\n' "$function_text" | grep -Eq 'github[.]com|plugins[.]deckbrew|cdn[.]'; then
    fail "游戏信息插件函数仍包含非 Gitee 回退来源"
fi

node --check "$PROJECT_ROOT/third_party/steamdb-button-zh-v0.0.1/dist/index.js"
node --check "$PROJECT_ROOT/third_party/decky-translator-zh-v0.8.0/dist/index.js"
grep -Fq '价格史低' "$PROJECT_ROOT/third_party/steamdb-button-zh-v0.0.1/dist/index.js" || \
    fail "SteamDB 构建缺少价格史低入口"
grep -Fq '在线峰值' "$PROJECT_ROOT/third_party/steamdb-button-zh-v0.0.1/dist/index.js" || \
    fail "SteamDB 构建缺少在线峰值入口"
grep -Fq 'import decky_plugin as decky' \
    "$PROJECT_ROOT/third_party/steamdb-button-zh-v0.0.1/main.py" || \
    fail "SteamDB 后端仍使用旧版 decky 模块名"
grep -Fq '汉化：RenAmamiya' "$PROJECT_ROOT/third_party/decky-translator-zh-v0.8.0/dist/index.js" || \
    fail "沉浸式翻译构建缺少汉化署名"
grep -Fq '原文语言' "$PROJECT_ROOT/third_party/decky-translator-zh-v0.8.0/dist/index.js" || \
    fail "沉浸式翻译构建缺少中文界面词条"

# 同版本但缺失后端依赖的坏包必须触发重装，避免 Decky 后端反复崩溃重启。
SIMULATE_MIRROR_FAILURE=0
export SIMULATE_MIRROR_FAILURE
rm -f -- "$PLUGIN_ROOT/decky-translator/bin/plugin-dependencies.tar.gz"
install_game_info_plugin_from_gitee decky-translator
[ "$(wc -l < "$CALL_LOG" | tr -d ' ')" = "4" ] || fail "沉浸式翻译缺少依赖时未触发重装"
[ -s "$PLUGIN_ROOT/decky-translator/bin/plugin-dependencies.tar.gz" ] || fail "沉浸式翻译重装后依赖仍缺失"

echo "PASS: SteamDB 游戏数据与沉浸式翻译分块安装测试"
