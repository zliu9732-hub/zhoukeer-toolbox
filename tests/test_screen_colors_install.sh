#!/bin/bash
# All commands are simulated; no network, services, privilege or device access.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_APP_DIR="$TMP/apps" DECKY_PLUGIN_DIR="$TMP/plugins"
source "$ROOT/modules/plugin_store.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
mkdir -p "$DECKY_PLUGIN_DIR/Screen Colors" "$TMP/settings"
echo 'old backend' > "$DECKY_PLUGIN_DIR/Screen Colors/main.py"
echo settings > "$TMP/settings/color.json"
MODE=ok
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; IS_CHIMERAOS=0; }
require_existing_chimera_plugin_environment() { return 0; }
ensure_plugin_store_ready() { return 0; }
prepare_plugin_root() { PLUGIN_NEEDS_SUDO=0; }
reload_decky_plugins() { echo reload >> "$TMP/reloads"; }
log() { return 0; }
download_gitee_mirror_file() {
    [ "$1" = screen-colors ] && [ "$3" = "$SCREEN_COLORS_PACKAGE_SHA256" ] || fail 'wrong package'
    [ "$GITEE_MIRROR_REPO" = zhoukeer-toolbox-mirror-4 ] || fail 'wrong repository'
    echo download >> "$TMP/downloads"
    [ "$MODE" != download-fail ] || return 1
    echo fixture > "$2"
}
python3() {
    [ "$1" = "$ROOT/scripts/localize_screen_colors.py" ] || fail 'unmocked Python command'
    case "$2" in
        check) [ -f "$3/dist/index.js" ] && grep -Fxq '完整中文' "$3/dist/index.js" ;;
        prepare)
            [ "$MODE" != prepare-fail ] || return 1
            mkdir -p "$3/dist"
            echo '完整中文' > "$3/dist/index.js"
            echo 'upstream backend' > "$3/main.py"
            printf '{"name":"屏幕色彩（Screen Colors）"}\n' > "$3/plugin.json"
            echo '{"version":"1.0.0"}' > "$3/package.json"
            echo original-license > "$3/LICENSE"
            ;;
        *) fail 'unknown localization operation' ;;
    esac
}
install_configured_plugin screen-colors > "$TMP/output" || fail 'installation failed'
[ "$PLUGIN_INSTALL_CHANGED" = 1 ] || fail 'success marker missing'
grep -Fxq 'upstream backend' "$DECKY_PLUGIN_DIR/Screen Colors/main.py" || fail 'wrong install directory'
[ "$(wc -l < "$TMP/reloads" | tr -d ' ')" = 1 ] || fail 'missing plugin reload'
install_configured_plugin screen-colors > "$TMP/repeat" || fail 'idempotent install failed'
[ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail 'reinstalled complete package'
[ "$(wc -l < "$TMP/downloads" | tr -d ' ')" = 1 ] || fail 're-downloaded complete package'
echo partial > "$DECKY_PLUGIN_DIR/Screen Colors/dist/index.js"
for MODE in download-fail prepare-fail; do
    if install_configured_plugin screen-colors > "$TMP/failure"; then fail 'failed download/verification accepted'; fi
    grep -Fxq partial "$DECKY_PLUGIN_DIR/Screen Colors/dist/index.js" || fail 'previous files lost'
    [ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail 'failure marked successful'
done
grep -Fxq settings "$TMP/settings/color.json" || fail 'customer settings removed'
if grep -Eiq 'gitee|镜像|分块|https://' "$TMP/output"; then fail 'implementation details shown in UI'; fi
echo 'PASS: Screen Colors atomic replacement, repeated install, reload, failure preservation and settings'
