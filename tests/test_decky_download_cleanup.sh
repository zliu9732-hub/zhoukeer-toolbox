#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
source "$PROJECT_ROOT/modules/plugin_store.sh"
export ZHOUKEER_TEST_MODE=1
export DECKY_PLUGIN_DIR="$TMP_ROOT/plugins"
prepare_plugin_root() { mkdir -p "$1"; PLUGIN_NEEDS_SUDO=0; }
log() { return 0; }
CALLS="$TMP_ROOT/download-dir"
OUTER_TRAP="$(trap -p EXIT)"
download_verified_package() {
    dirname "$4" > "$CALLS"
    printf 'partial-data' > "$4"
    DOWNLOAD_LOCAL_IO_FAILED=1
    return 1
}
if install_decky_zip "测试下载" "https://example.invalid/a.zip" ignored TestPlugin 0; then
    fail "本地文件错误仍报告成功"
fi
[ ! -e "$(cat "$CALLS")" ] || fail "失败后临时文件仍占用空间"
[ "$(trap -p EXIT)" = "$OUTER_TRAP" ] || fail "安装覆盖了调用方的清理动作"
mkdir -p "$TMP_ROOT/fixture/TestPlugin/dist"
printf '{"name":"TestPlugin"}\n' > "$TMP_ROOT/fixture/TestPlugin/plugin.json"
printf 'bundle' > "$TMP_ROOT/fixture/TestPlugin/dist/index.js"
(cd "$TMP_ROOT/fixture" && zip -qry "$TMP_ROOT/plugin.zip" TestPlugin)
download_verified_package() {
    dirname "$4" > "$CALLS"
    cp "$TMP_ROOT/plugin.zip" "$4"
}
install_decky_zip "测试下载" "https://example.invalid/a.zip" ignored TestPlugin 0 || fail "失败后不能重新安装"
[ -f "$DECKY_PLUGIN_DIR/TestPlugin/plugin.json" ] || fail "成功包没有安装"
[ ! -e "$(cat "$CALLS")" ] || fail "成功后临时文件未清理"
[ "$PLUGIN_INSTALL_CHANGED" = 1 ] || fail "成功安装状态没有传回调用方"
[ "$(trap -p EXIT)" = "$OUTER_TRAP" ] || fail "成功安装覆盖了调用方清理动作"
echo "PASS: ZIP 下载失败与成功都会清理临时目录，并保留调用方状态和清理动作"
