#!/bin/bash
# No network, privileges, services or hardware access; all mutations stay in TMP_ROOT.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
source "$ROOT/modules/plugin_store.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
export DECKY_PLUGIN_DIR="$TMP_ROOT/plugins"
mkdir -p "$DECKY_PLUGIN_DIR" "$TMP_ROOT/source/dist" "$TMP_ROOT/settings"
printf 'official backend\n' > "$TMP_ROOT/source/main.py"
printf '{"name":"AYANEO 3 Companion","flags":["root"]}\n' > "$TMP_ROOT/source/plugin.json"
printf '{"version":"1.2.0"}\n' > "$TMP_ROOT/source/package.json"
printf 'original notice\n' > "$TMP_ROOT/source/NOTICE"
printf 'official UI\n' > "$TMP_ROOT/source/dist/index.js"
printf 'user setting\n' > "$TMP_ROOT/settings/keep"
DEVICE=correct;MODE=ok;PLATFORM=steamos
detect_platform() { IS_STEAMOS=1;IS_BAZZITE=0;IS_CHIMERAOS=0;[ "$PLATFORM" = steamos ] || IS_STEAMOS=0; }
ayaneo3_is_supported_device() { [ "$DEVICE" = correct ]; }
require_existing_chimera_plugin_environment() { return 0; }
ensure_plugin_store_ready() { echo ready >> "$TMP_ROOT/ready.calls"; }
prepare_plugin_root() { PLUGIN_NEEDS_SUDO=0;mkdir -p "$1"; }
log() { return 0; }
reload_decky_plugins() { echo reload >> "$TMP_ROOT/reload.calls"; }
download_gitee_mirror_file() {
    [ "$1" = ayaneo3-companion ] && [ "$3" = "$AYANEO3_PACKAGE_SHA256" ] || fail '下载未使用固定包与完整校验值'
    [ "$GITEE_MIRROR_REPO" = zhoukeer-toolbox-mirror-4 ] || fail '使用了错误的下载仓库'
    echo download >> "$TMP_ROOT/download.calls"
    [ "$MODE" != download-fail ] || return 1
    printf 'verified archive fixture' > "$2"
}
python3() {
    [ "$1" = "$ROOT/scripts/localize_ayaneo3.py" ] || fail '执行了非模拟 Python'
    case "$2" in
        check) [ -f "$3/dist/index.js" ] && grep -Fxq '中文界面' "$3/dist/index.js" ;;
        prepare)
            [ "$MODE" != prepare-fail ] || return 1
            cp -a "$TMP_ROOT/source" "$3"
            printf '中文界面\n' > "$3/dist/index.js"
            ;;
        *) fail '未知汉化操作' ;;
    esac
}
DEVICE=wrong
if install_configured_plugin ayaneo3 0 > "$TMP_ROOT/wrong.out"; then fail '其他机型仍安装'; fi
[ ! -e "$TMP_ROOT/ready.calls" ] && [ ! -e "$TMP_ROOT/download.calls" ] || fail '机型检查前已开始安装'
grep -Fxq '仅适用于 AYANEO3。' "$TMP_ROOT/wrong.out" || fail '机型提示不明确'
DEVICE=correct
install_configured_plugin ayaneo3 > "$TMP_ROOT/ok.out" || fail '中文插件安装失败'
[ "$PLUGIN_INSTALL_CHANGED" = 1 ] || fail '没有标记安装成功'
cmp "$TMP_ROOT/source/main.py" "$DECKY_PLUGIN_DIR/Ayaneo3Companion/main.py" || fail '修改了后端'
cmp "$TMP_ROOT/source/plugin.json" "$DECKY_PLUGIN_DIR/Ayaneo3Companion/plugin.json" || fail '修改了内部标识或权限'
cmp "$TMP_ROOT/source/NOTICE" "$DECKY_PLUGIN_DIR/Ayaneo3Companion/NOTICE" || fail '丢失第三方声明'
[ "$(wc -l < "$TMP_ROOT/reload.calls" | tr -d ' ')" = 1 ] || fail '安装完成没有重新加载插件'
install_configured_plugin ayaneo3 > "$TMP_ROOT/repeat.out" || fail '重复安装失败'
[ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail '完整中文版没有跳过'
[ "$(wc -l < "$TMP_ROOT/download.calls" | tr -d ' ')" = 1 ] || fail '完整中文版重复下载'
[ "$(wc -l < "$TMP_ROOT/reload.calls" | tr -d ' ')" = 1 ] || fail '重复安装仍重启服务'
printf 'previous\n' > "$DECKY_PLUGIN_DIR/Ayaneo3Companion/dist/index.js"
MODE=download-fail
if install_configured_plugin ayaneo3 > "$TMP_ROOT/fail.out"; then fail '下载失败仍成功'; fi
grep -Fxq previous "$DECKY_PLUGIN_DIR/Ayaneo3Companion/dist/index.js" || fail '下载失败破坏原版'
MODE=prepare-fail
if install_configured_plugin ayaneo3 > "$TMP_ROOT/fail.out"; then fail '汉化检查失败仍成功'; fi
grep -Fxq previous "$DECKY_PLUGIN_DIR/Ayaneo3Companion/dist/index.js" || fail '汉化失败破坏原版'
MODE=ok
install_tree_atomically() { return 1; }
if install_configured_plugin ayaneo3 > "$TMP_ROOT/fail.out"; then fail '替换失败仍成功'; fi
[ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail '失败标记成功'
grep -Fxq previous "$DECKY_PLUGIN_DIR/Ayaneo3Companion/dist/index.js" || fail '替换失败没有保留旧版'
grep -Fxq 'user setting' "$TMP_ROOT/settings/keep" || fail '修改了用户设置'
PLATFORM=other
if install_configured_plugin ayaneo3 > "$TMP_ROOT/platform.out"; then fail '其他平台执行了安装'; fi
if grep -Eiq 'gitee|镜像|分块|https://' "$TMP_ROOT/ok.out"; then fail '安装界面显示内部来源'; fi
echo 'PASS: AYANEO3 机型限制、中文安装、内部名称、重复跳过、重载及失败保留模拟通过'
