#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/plugin_store.sh"

PLUGIN_ROOT="$TMP_ROOT/plugins"
CALLS="$TMP_ROOT/calls"
mkdir -p "$PLUGIN_ROOT"

detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
require_existing_chimera_plugin_environment() { return 0; }
calculate_decky_sha256() {
    case "$1" in
        *'/小黄鸭2.0/dist/index.js') printf '%s\n' "$LSFG_V2_INDEX_SHA256" ;;
        *) return 1 ;;
    esac
}
install_decky_zip_from_mirror() {
    printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$GITEE_MIRROR_REPO" >> "$CALLS"
    mkdir -p "$DECKY_PLUGIN_DIR/$4/bin" "$DECKY_PLUGIN_DIR/$4/dist"
    printf '{"name":"小黄鸭2.0"}\n' > "$DECKY_PLUGIN_DIR/$4/plugin.json"
    printf '{"version":"0.14.4"}\n' > "$DECKY_PLUGIN_DIR/$4/package.json"
    printf 'license\n' > "$DECKY_PLUGIN_DIR/$4/LICENSE"
    printf 'runtime\n' > "$DECKY_PLUGIN_DIR/$4/bin/lsfg-vk-2.0.0.tar.xz"
    printf 'frontend\n' > "$DECKY_PLUGIN_DIR/$4/dist/index.js"
    return 0
}
reload_decky_plugins() { return 0; }
log() { return 0; }

DECKY_PLUGIN_DIR="$PLUGIN_ROOT"
export DECKY_PLUGIN_DIR
install_lsfg_v2_from_gitee 0 || fail "小黄鸭 2.0 没有完成安装"

[ -f "$PLUGIN_ROOT/小黄鸭2.0/LICENSE" ] || fail "小黄鸭 2.0 没有保留许可证"
[ -f "$PLUGIN_ROOT/小黄鸭2.0/bin/lsfg-vk-2.0.0.tar.xz" ] || \
    fail "小黄鸭 2.0 没有保留运行文件"
lsfg_v2_is_current "$PLUGIN_ROOT" || fail "小黄鸭 2.0 未通过完整性检查"
grep -Fxq "小黄鸭 2.0（LSFG-VK）|$LSFG_V2_MIRROR_ID|$LSFG_V2_PACKAGE_SHA256|$LSFG_V2_DIRECTORY|$DECKY_LSFG_V2_MIRROR_REPO" "$CALLS" || \
    fail "小黄鸭 2.0 没有走固定国内镜像、SHA256 或独立目录"

grep -Fq 'lsfg-v2) install_lsfg_v2_from_gitee' "$PROJECT_ROOT/modules/plugin_store.sh" || \
    fail "小黄鸭 2.0 命令入口缺失"

echo "PASS: 小黄鸭 2.0 使用独立目录、国内镜像、完整性校验且可与其他版本共存"
