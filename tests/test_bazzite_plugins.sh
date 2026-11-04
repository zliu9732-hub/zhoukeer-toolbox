#!/bin/bash
# Dispatcher/platform checks only. Network, services, installers and hardware are mocked.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_APP_DIR="$TEST_ROOT/apps" DECKY_PLUGIN_DIR="$TEST_ROOT/plugins"
source "$ROOT/modules/plugin_store.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
MODE=bazzite DEVICE=deck PRESENT=0
# No platform metadata, device files or services are read.
detect_platform() {
 IS_STEAMOS=0;IS_BAZZITE=0;IS_CHIMERAOS=0;IS_DESKTOP_LINUX=0
 case "$MODE" in bazzite) IS_BAZZITE=1;IS_DESKTOP_LINUX=1 ;; anatase) IS_DESKTOP_LINUX=1 ;; steamos) IS_STEAMOS=1 ;; isolated) IS_CHIMERAOS=1 ;; esac
}
require_existing_chimera_plugin_environment() { return 0; }
toolbox_sudo() { fail 'Unexpected privileged action'; }
ensure_plugin_store_ready() { fail 'Unexpected Loader install'; }
download_github_file() { fail 'Unexpected network'; }
download_gitee_mirror_file() { fail 'Unexpected network'; }
reload_decky_plugins() { echo reload >> "$TEST_ROOT/reloads"; }
ensure_deckhomethemes_chinese_current() { echo themehub >> "$TEST_ROOT/routes";PLUGIN_INSTALL_CHANGED=1; }
install_game_info_plugin_from_gitee() { echo "$1" >> "$TEST_ROOT/routes";PLUGIN_INSTALL_CHANGED=1; }
gfg_extreme_is_steam_deck() { [ "$DEVICE" = deck ]; }
feature_plugin_is_current() { [ "$PRESENT" = 1 ]; }
calculate_decky_sha256() { echo "$DECKY_FANTASTIC_INDEX_SHA256"; }
install_decky_zip() {
 [ "$1" = 'Fantastic 风扇控制（汉化：RenAmamiya）' ] || fail 'Wrong package'
 [ "$2" = "$DECKY_FANTASTIC_URL" ] && [ "$3" = "$DECKY_FANTASTIC_SHA256" ] && [ "$4" = "$DECKY_FANTASTIC_DIRECTORY" ] || fail 'Download route/checksum changed'
 echo fantastic >> "$TEST_ROOT/routes";PRESENT=1;PLUGIN_INSTALL_CHANGED=1
}
for MODE in bazzite anatase; do
 install_configured_plugin deckhomethemes >/dev/null || fail 'ThemeHub desktop route blocked'
 install_configured_plugin steamdb-info >/dev/null || fail 'SteamDB desktop route blocked'
 install_configured_plugin decky-translator >/dev/null || fail 'Translator desktop route blocked'
 PRESENT=0
 install_configured_plugin fantastic >/dev/null || fail 'Steam Deck desktop fan plugin blocked'
 install_configured_plugin fantastic >/dev/null || fail 'Repeated install failed'
 [ "$PLUGIN_INSTALL_CHANGED" = 0 ] || fail 'Repeated install marked changed'
 DEVICE=other
 if install_configured_plugin fantastic >/dev/null; then fail 'Wrong fan hardware accepted'; fi
 DEVICE=deck
done
for MODE in unsupported isolated; do
 if install_configured_plugin deckhomethemes >/dev/null; then fail 'Unsupported platform accepted'; fi
done
[ "$(wc -l < "$TEST_ROOT/routes" | tr -d ' ')" = 8 ] || fail 'Missing or duplicate installer route'
echo 'PASS: Bazzite/Anatase plugin dispatcher, ThemeHub, SteamDB, translator, device-specific fan control, exact existing package/checksum, repeat install and platform isolation'
