#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" ZHOUKEER_TEST_MODE=1
export DECKY_PLUGIN_DIR="$HOME/homebrew/plugins"
mkdir -p "$DECKY_PLUGIN_DIR"
source "$PROJECT_ROOT/modules/plugin_store.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
detect_platform() { IS_STEAMOS=1; IS_CHIMERAOS=0; IS_BAZZITE=0; }
curl() { fail "Unexpected network"; }
sudo() { fail "Unexpected sudo"; }
systemctl() { fail "Unexpected service operation"; }
ensure_steam302_for_download() { :; }
prepare_plugin_root() { PLUGIN_NEEDS_SUDO=0; }
resolve_plugin_latest() { :; }
log() { :; }
download_verified_package() { printf '%s\n' "$2" >> "$tmp/requests"; cp "$tmp/artifact.zip" "$4"; }
make_plugin() {
    mkdir -p "$1/dist"
    printf '{"name":"%s"}\n' "${3:-Fixture}" > "$1/plugin.json"
    printf '{"version":"%s"}\n' "$2" > "$1/package.json"
    printf '%s\n' "$2" > "$1/dist/index.js"
}
make_artifact() {
    rm -rf -- "$tmp/build" "$tmp/artifact.zip"
    make_plugin "$tmp/build/$1" "$2"
    (cd "$tmp/build" && zip -qr "$tmp/artifact.zip" "$1")
}
for row in 'tomoon tomoon 0.2.8' 'freedeck freedeck-plugin 0.6' 'unifideck Unifideck 0.8.0'; do
    read -r action directory target_version <<< "$row"
    plugin="$DECKY_PLUGIN_DIR/$directory"
    make_plugin "$plugin" 0.1.0
    make_artifact "$directory" 0.1.0
    if install_configured_plugin "$action" 0 > "$tmp/output"; then fail "$action accepted a mismatched ZIP"; fi
    [[ "$(decky_plugin_version "$plugin")" == 0.1.0 ]] || fail "$action altered the installed plugin on mismatch"
    ! grep -Fq '安装成功' "$tmp/output" || fail "$action showed false success"
    make_artifact "$directory" "$target_version"
    install_configured_plugin "$action" 0 >/dev/null
    [[ "$(decky_plugin_version "$plugin")" == "$target_version" ]] || fail "$action skipped a valid upgrade"
    : > "$tmp/requests"
    install_configured_plugin "$action" 0 >/dev/null
    [[ ! -s "$tmp/requests" ]] || fail "$action downloaded an existing version again"
    make_plugin "$plugin" 9.9.9
    install_configured_plugin "$action" 0 >/dev/null
    [[ "$(decky_plugin_version "$plugin")" == 9.9.9 && ! -s "$tmp/requests" ]] || fail "$action downgraded a newer installation"
done
make_plugin "$tmp/stale" 0.8.0
if install_tree_atomically "$tmp/stale" "$DECKY_PLUGIN_DIR" Unifideck >/dev/null; then fail 'shared installer allowed a downgrade'; fi
[[ "$(decky_plugin_version "$DECKY_PLUGIN_DIR/Unifideck")" == 9.9.9 ]] || fail 'shared installer moved the current plugin'
# The user's explicit switch from 2.0 to 1.0 remains supported.
make_plugin "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY" 0.14.4
make_plugin "$tmp/legacy" 0.12.8
allow_legacy_lsfg_switch=1 install_tree_atomically "$tmp/legacy" "$DECKY_PLUGIN_DIR" "$LSFG_OFFICIAL_DIRECTORY"
[[ "$(decky_plugin_version "$DECKY_PLUGIN_DIR/$LSFG_OFFICIAL_DIRECTORY")" == 0.12.8 ]] || fail 'explicit LSFG switch failed'
echo 'PASS: Plugin updates reject mismatched archives, retain newer versions, and permit an explicit LSFG 1.0 switch'
