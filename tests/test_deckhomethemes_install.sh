#!/bin/bash
# 全部网络、平台检查、汉化执行和服务动作使用本地模拟，真实操作只有临时目录内文件复制。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
export ZHOUKEER_TEST_MODE=1
export ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
source "$ROOT/modules/plugin_store.sh"
LOG_DIR="$TMP_ROOT/logs"; LOG_FILE="$LOG_DIR/toolbox.log"
mkdir -p "$LOG_DIR" "$TMP_ROOT/source/DeckHomeThemes/dist" "$TMP_ROOT/plugins"
export DECKY_PLUGIN_DIR="$TMP_ROOT/plugins"
printf '%s\n' 'official backend fixture' > "$TMP_ROOT/source/DeckHomeThemes/main.py"
printf '%s\n' '{"name":"ThemeHub"}' > "$TMP_ROOT/source/DeckHomeThemes/plugin.json"
printf '%s\n' '{"version":"1.10.7"}' > "$TMP_ROOT/source/DeckHomeThemes/package.json"
printf '%s\n' 'official frontend fixture' > "$TMP_ROOT/source/DeckHomeThemes/dist/index.js"
printf '%s\n' 'original notice fixture' > "$TMP_ROOT/source/DeckHomeThemes/notice.txt"
(cd "$TMP_ROOT/source" && zip -q -r "$TMP_ROOT/fixture.zip" DeckHomeThemes)

detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
DOWNLOAD_MODE=success
LOCALIZE_FAIL=0
python3() {
    [ "$1" = "$ROOT/scripts/localize_deckhomethemes.py" ] || fail '尝试执行非模拟 Python'
    if [ "${2:-}" = --check ]; then
        [ -f "$3/dist/index.js" ] && grep -Fq '中文前端 fixture' "$3/dist/index.js"
        return
    fi
    [ "$LOCALIZE_FAIL" = 0 ] || return 1
    [ -f "$2/main.py" ] || return 1
    printf '%s\n' '中文前端 fixture' > "$2/dist/index.js"
}
bash() {
    [ "$1" = "$ROOT/modules/steam_accelerator.sh" ] && [ "$2" = ensure ] || fail '尝试执行真实系统脚本'
    printf '%s\n' '模拟加速' >> "$TMP_ROOT/accelerator.calls"
}
download_verified_package() {
    [ "$2" = "$DECKHOMETHEMES_URL" ] && [ "$3" = "$DECKHOMETHEMES_SHA256" ] || fail '下载没有固定版本及 SHA256'
    [ "${GITHUB_ACCELERATION_FIRST:-0}" = 1 ] || fail '主页主题没有加速优先'
    [ "$GITHUB_CONNECT_TIMEOUT" = 5 ] && [ "$GITHUB_MIN_SPEED_TIME" = 15 ] || fail '没有缩短慢线路等待'
    printf '%s\n' download >> "$TMP_ROOT/download.calls"
    DOWNLOAD_LOCAL_IO_FAILED=0
    case "$DOWNLOAD_MODE" in
        local-io) DOWNLOAD_LOCAL_IO_FAILED=1; return 1 ;;
        retry) [ "$(wc -l < "$TMP_ROOT/download.calls" | tr -d ' ')" -gt 1 ] || return 1 ;;
        fail) return 1 ;;
    esac
    cp "$TMP_ROOT/fixture.zip" "$4"
}
reload_decky_plugins() { fail '本测试不允许执行服务操作'; }

ensure_deckhomethemes_chinese_current > "$TMP_ROOT/success.out"
[ "$PLUGIN_INSTALL_CHANGED" = 1 ] || fail '成功后没有标记变更'
cmp "$TMP_ROOT/source/DeckHomeThemes/main.py" "$DECKY_PLUGIN_DIR/DeckHomeThemes/main.py" || fail '后端被改动'
cmp "$TMP_ROOT/source/DeckHomeThemes/notice.txt" "$DECKY_PLUGIN_DIR/DeckHomeThemes/notice.txt" || fail '原作者声明丢失'
grep -Fq '汉化作者：RenAmamiya' "$TMP_ROOT/success.out" || fail '安装结果缺少汉化署名'
ensure_deckhomethemes_chinese_current > "$TMP_ROOT/repeat.out"
[ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail '重复安装没有跳过'
[ "$(wc -l < "$TMP_ROOT/download.calls" | tr -d ' ')" = 1 ] || fail '完整中文版仍重复下载'

printf '%s\n' 'previous version' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js"
cp "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js" "$TMP_ROOT/previous"
LOCALIZE_FAIL=1
if ensure_deckhomethemes_chinese_current > "$TMP_ROOT/localize-fail.out" 2>&1; then fail '汉化失败返回成功'; fi
cmp "$TMP_ROOT/previous" "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js" || fail '汉化失败改动旧版'
LOCALIZE_FAIL=0
rm -f "$TMP_ROOT/download.calls"
DOWNLOAD_MODE=local-io
if ensure_deckhomethemes_chinese_current > "$TMP_ROOT/io-fail.out" 2>&1; then fail '本地写入失败返回成功'; fi
[ ! -f "$TMP_ROOT/accelerator.calls" ] || fail '本地写入失败仍启用加速'
[ "$(wc -l < "$TMP_ROOT/download.calls" | tr -d ' ')" = 1 ] || fail '本地写入失败仍重复下载'
cmp "$TMP_ROOT/previous" "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js" || fail '下载失败改动旧版'

rm -f "$TMP_ROOT/download.calls"
DOWNLOAD_MODE=retry
ensure_deckhomethemes_chinese_current > "$TMP_ROOT/retry.out"
[ "$(wc -l < "$TMP_ROOT/download.calls" | tr -d ' ')" = 2 ] || fail '没有沿用加速重试'
[ -f "$TMP_ROOT/accelerator.calls" ] || fail '网络失败没有尝试加速'

# 安装原子替换失败也必须返回非零并保留旧目录。
printf '%s\n' 'previous version' > "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js"
DOWNLOAD_MODE=success
install_tree_atomically() { return 1; }
if ensure_deckhomethemes_chinese_current > "$TMP_ROOT/install-fail.out" 2>&1; then fail '写入失败返回成功'; fi
cmp "$TMP_ROOT/previous" "$DECKY_PLUGIN_DIR/DeckHomeThemes/dist/index.js" || fail '写入失败改动旧版'
[ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail '失败仍标记成功'
[ "${GITHUB_ACCELERATION_FIRST:-0}" != 1 ] || fail '专用下载选项泄漏到其他程序'
printf '%s\n' 'PASS: 主页主题安装、署名、完整版跳过、加速回退与失败保留旧版'
