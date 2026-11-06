#!/bin/bash
# Private marker files only. Every installer, network and OS action is mocked.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export ZHOUKEER_TEST_MODE=1 ZHOUKEER_APP_DIR="$TEST_ROOT/apps" DECKY_PLUGIN_DIR="$TEST_ROOT/plugins"
source "$ROOT/modules/plugin_store.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
[ "$(gitee_mirror_id_for_url "$DECKYGCM_URL")" = deckygcm ] || fail 'GCM download bypasses mirror mapping'
[ "$(gitee_mirror_manifest_repo deckygcm)" = zhoukeer-toolbox-mirror-4 ] || fail 'Wrong GCM manifest repository'
download_policy_url_allowed "$DECKYGCM_URL" || fail 'Official GCM fallback refused'
download_policy_url_allowed 'https://gitee.com/zliu9732-hub/zhoukeer-toolbox-mirror-4/raw/main/deckygcm/v1.0.1/part.0001' || fail 'GCM chunk refused'
MODE=steamos FAIL_PACKAGE=''
mkdir -p "$DECKY_PLUGIN_DIR"
detect_platform() { IS_STEAMOS=0; IS_BAZZITE=0; IS_CHIMERAOS=0; IS_DESKTOP_LINUX=0; if [ "$MODE" = steamos ]; then IS_STEAMOS=1; else IS_DESKTOP_LINUX=1; fi; }
require_existing_chimera_plugin_environment() { return 0; }
resolve_plugin_latest() { [ "$1" = cheatdeck ] || fail 'Wrong release lookup'; }
feature_plugin_is_current() { [ -f "$TEST_ROOT/cheatdeck" ]; }
deckygcm_is_current() { [ -f "$TEST_ROOT/gcm" ]; }
refresh_feature_usage_guides() { :; }
write_flingtrainer_desktop_note() { :; }
print_cef_remote_debugging_tip() { :; }
reload_decky_plugins() { echo reload >> "$TEST_ROOT/reloads"; }
log() { :; }
toolbox_sudo() { fail 'Unexpected privileged action'; }
download_github_file() { fail 'Unexpected network'; }
download_gitee_mirror_file() { fail 'Unexpected network'; }
install_decky_zip() {
    printf '%s\n' "$1" >> "$TEST_ROOT/packages"
    PLUGIN_INSTALL_CHANGED=0
    [ "$FAIL_PACKAGE" != "$1" ] || return 1
    case "$1" in
        CheatDeck) [ "$2:$3:$4:$5" = "$DECKY_CHEATDECK_URL:$DECKY_CHEATDECK_SHA256:CheatDeck:0" ] || fail 'CheatDeck metadata changed'; touch "$TEST_ROOT/cheatdeck" ;;
        DeckyGCM) [ "$2:$3:$4:$5" = "$DECKYGCM_URL:$DECKYGCM_SHA256:DeckyGCM:0" ] || fail 'GCM integrity metadata missing'; touch "$TEST_ROOT/gcm" ;;
        *) fail 'Unexpected plugin' ;;
    esac
    PLUGIN_INSTALL_CHANGED=1
}
reset_case() { rm -f -- "$TEST_ROOT/cheatdeck" "$TEST_ROOT/gcm"; : > "$TEST_ROOT/packages"; : > "$TEST_ROOT/reloads"; FAIL_PACKAGE=''; }
for MODE in steamos desktop; do
    reset_case
    install_configured_plugin cheatdeck > "$TEST_ROOT/output" || fail 'Pair installation failed'
    [ "$(cat "$TEST_ROOT/packages")" = $'CheatDeck\nDeckyGCM' ] || fail 'Pair order or membership incorrect'
    [ "$(wc -l < "$TEST_ROOT/reloads")" -eq 1 ] || fail 'Pair should reload once'
    grep -Fq '感谢b站ProSS及时行乐' "$TEST_ROOT/output" || fail 'Thanks missing'
    ! grep -Eq '汉化：RenAmamiya|分块|Gitee' "$TEST_ROOT/output" || fail 'Upstream attribution or download wording incorrect'
    : > "$TEST_ROOT/packages"; : > "$TEST_ROOT/reloads"
    install_configured_plugin cheatdeck >/dev/null || fail 'Repeated pair failed'
    [ ! -s "$TEST_ROOT/packages" ] && [ ! -s "$TEST_ROOT/reloads" ] || fail 'Complete pair unnecessarily reinstalled'
    rm "$TEST_ROOT/gcm"
    install_configured_plugin cheatdeck >/dev/null || fail 'Existing CheatDeck prevented GCM repair'
    [ "$(cat "$TEST_ROOT/packages")" = DeckyGCM ] || fail 'Missing GCM did not install alone'
    : > "$TEST_ROOT/packages"; : > "$TEST_ROOT/reloads"; rm "$TEST_ROOT/cheatdeck"
    install_configured_plugin cheatdeck >/dev/null || fail 'Existing GCM prevented CheatDeck installation'
    [ "$(cat "$TEST_ROOT/packages")" = CheatDeck ] && [ "$PLUGIN_INSTALL_CHANGED" = 1 ] || fail 'Pair lost first installer change flag'
    reset_case; FAIL_PACKAGE=DeckyGCM
    if install_configured_plugin cheatdeck > "$TEST_ROOT/failure"; then fail 'Incomplete pair reported success'; fi
    [ -f "$TEST_ROOT/cheatdeck" ] && [ ! -f "$TEST_ROOT/gcm" ] || fail 'Partial result lost'
    [ "$(wc -l < "$TEST_ROOT/reloads")" -eq 1 ] || fail 'Completed first plugin was not reloaded'
    FAIL_PACKAGE=''; : > "$TEST_ROOT/packages"
    install_configured_plugin cheatdeck >/dev/null || fail 'Partial pair retry failed'
    [ "$(cat "$TEST_ROOT/packages")" = DeckyGCM ] || fail 'Retry should repair missing plugin only'
    reset_case; FAIL_PACKAGE=CheatDeck
    if install_configured_plugin cheatdeck >/dev/null; then fail 'CheatDeck failure masked'; fi
    [ "$(cat "$TEST_ROOT/packages")" = CheatDeck ] && [ ! -s "$TEST_ROOT/reloads" ] || fail 'Failed first plugin continued/reloaded'
done
# The all-installed shortcut and per-plugin loop must both notice a missing GCM.
MODE=steamos
detect_platform
reset_case; touch "$TEST_ROOT/cheatdeck"
refresh_framegen_catalog() { :; }
load_framegen_cached_versions() { :; }
lsfg_v2_is_current() { return 0; }
mako_official_is_current() { return 0; }
feature_plugin_is_current() { return 0; }
feature_plugin_is_present() { return 1; }
calculate_decky_sha256() { case "$1" in *Fantastic*) echo "$DECKY_FANTASTIC_INDEX_SHA256";; *) echo "$CSSLOADER_ZH_INDEX_SHA256";; esac; }
deckymusic_full_is_current() { return 0; }
print_feature_plugin_status() { deckygcm_is_current; }
install_configured_plugin() { [ "$1" != cheatdeck ] || install_cheatdeck_with_gcm; }
install_feature_plugins_selected auto > "$TEST_ROOT/bundle" || fail 'Bundle with missing GCM failed'
[ "$(cat "$TEST_ROOT/packages")" = DeckyGCM ] || fail 'Bundle skipped missing GCM because CheatDeck existed'
: > "$TEST_ROOT/packages"
install_feature_plugins_selected auto > "$TEST_ROOT/repeat" || fail 'Complete bundle failed'
[ ! -s "$TEST_ROOT/packages" ] || fail 'Complete bundle downloaded again'
grep -Fq '十款常用功能插件已全部安装' "$TEST_ROOT/repeat" || fail 'Incorrect bundle count'
echo 'PASS: SteamOS/desktop paired installs, missing companion repair, idempotence, first/second failures, retry, reload aggregation and complete-bundle shortcuts'
