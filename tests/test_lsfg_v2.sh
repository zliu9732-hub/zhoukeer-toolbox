#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
source "$PROJECT_ROOT/modules/plugin_store.sh"
export DECKY_PLUGIN_DIR="$TMP_ROOT/plugins"
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
require_existing_chimera_plugin_environment() { return 0; }
prepare_plugin_root() { mkdir -p "$1"; PLUGIN_NEEDS_SUDO=0; }
reload_decky_plugins() { return 0; }
log() { return 0; }

# Exercise real extraction and atomic replacement with a local archive.
SOURCE="$TMP_ROOT/archive/$LSFG_V2_ARCHIVE_DIRECTORY"
mkdir -p "$SOURCE/bin" "$SOURCE/dist" "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY" \
    "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY" "$DECKY_PLUGIN_DIR/Mako"
printf '{"name":"小黄鸭2.0"}\n' > "$SOURCE/plugin.json"
printf '{"version":"0.14.4"}\n' > "$SOURCE/package.json"
printf 'license\n' > "$SOURCE/LICENSE"
printf 'runtime\n' > "$SOURCE/bin/lsfg-vk-2.0.0.tar.xz"
printf 'frontend\n' > "$SOURCE/dist/index.js"
(cd "$TMP_ROOT/archive" && zip -qry "$TMP_ROOT/v2.zip" "$LSFG_V2_ARCHIVE_DIRECTORY")
LSFG_V2_PACKAGE_SHA256="$(shasum -a 256 "$TMP_ROOT/v2.zip" | awk '{print $1}')"
LSFG_V2_INDEX_SHA256="$(shasum -a 256 "$SOURCE/dist/index.js" | awk '{print $1}')"
printf 'old-version\n' > "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY/old-file"
printf '{"name":"小黄鸭2.0"}\n' > "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY/plugin.json"
printf 'mako-user-file\n' > "$DECKY_PLUGIN_DIR/Mako/keep"
DOWNLOAD_FAIL=1
download_gitee_mirror_file() {
    [ "$DOWNLOAD_FAIL" = 0 ] || return 1
    [ "$1" = "$LSFG_V2_MIRROR_ID" ] && [ "$3" = "$LSFG_V2_PACKAGE_SHA256" ] || return 1
    [ "$GITEE_MIRROR_REPO" = "$DECKY_LSFG_V2_MIRROR_REPO" ] || return 1
    cp "$TMP_ROOT/v2.zip" "$2"
}
if install_lsfg_v2_from_gitee 0; then fail "下载失败仍报告成功"; fi
[ -f "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY/old-file" ] || fail "失败删除了 1.0"
[ -f "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY/plugin.json" ] || fail "失败删除了旧 2.0"
DOWNLOAD_FAIL=0
install_lsfg_v2_from_gitee 0 || fail "小黄鸭 2.0 安装失败"
[ "$LSFG_V2_DIRECTORY" = "$LSFG_OFFICIAL_DIRECTORY" ] || fail "1.0 和 2.0 目录不同"
[ ! -e "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY/old-file" ] || fail "1.0 文件仍残留"
[ ! -e "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY" ] || fail "重复 2.0 目录仍残留"
[ -f "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY/LICENSE" ] || fail "许可证丢失"
[ -f "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY/bin/lsfg-vk-2.0.0.tar.xz" ] || fail "运行文件丢失"
grep -Fxq 'mako-user-file' "$DECKY_PLUGIN_DIR/Mako/keep" || fail "MAKO 被改动"
lsfg_v2_is_current "$DECKY_PLUGIN_DIR" || fail "共享目录的 2.0 未通过检查"

# Reinstall cleans only recognised duplicates, without downloading a current version.
mkdir -p "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY"
cp "$SOURCE/plugin.json" "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY/plugin.json"
DOWNLOAD_FAIL=1
install_lsfg_v2_from_gitee 0 || fail "已安装 2.0 仍尝试下载"
[ ! -e "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY" ] || fail "已有版本没有清理重复目录"
mkdir -p "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY"
printf '{"name":"OtherPlugin"}\n' > "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY/plugin.json"
install_lsfg_v2_from_gitee 0 || fail "无关目录影响已安装判断"
[ -f "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY/plugin.json" ] || fail "删除了无关插件"
rm -rf "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY"
ln -s "$DECKY_PLUGIN_DIR/Mako" "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY"
install_lsfg_v2_from_gitee 0 || fail "符号链接影响已安装判断"
[ -L "$DECKY_PLUGIN_DIR/$LSFG_V2_ARCHIVE_DIRECTORY" ] || fail "符号链接被自动删除"

# Filling other missing plugins must keep the chosen 2.0 rather than downgrade to 1.0.
ensure_plugin_store_ready() { return 0; }
feature_plugin_is_current() { [ "$2" != "$FSR4_OFFICIAL_DIRECTORY" ]; }
install_lsfg_zh_from_gitee() { fail "常用组合把 2.0 降回 1.0"; }
install_fsr4_zh_from_gitee() { return 0; }
install_configured_plugin() { return 0; }
mako_official_is_current() { return 0; }
deckymusic_full_is_current() { return 0; }
refresh_feature_usage_guides() { return 0; }
print_feature_plugin_status() { return 0; }
check_lossless_scaling_installation() { return 0; }
print_cef_remote_debugging_tip() { return 0; }
install_feature_plugins || fail "常用插件补装失败"
echo "PASS: 小黄鸭 2.0 覆盖 1.0、失败保留原插件、清理重复目录、保留 MAKO 和所选版本"
