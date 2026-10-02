#!/bin/bash
set -euo pipefail
# Every Linux/system/download operation is mocked; only temporary files are real.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
source "$PROJECT_ROOT/modules/inputplumber_update.sh"
source "$PROJECT_ROOT/modules/inputplumber_manual.sh"
export TMPDIR="$TEST_ROOT" ZHOUKEER_AUTO_CONFIRM=1
LOG_FILE="$TEST_ROOT/log" CALLS="$TEST_ROOT/calls" STATE="$TEST_ROOT/state"
mkdir "$STATE"
log() { :; }
fail() { echo "FAIL: $*" >&2; exit 1; }
uname() { case "$1" in -s) echo Linux;; -m) echo x86_64;; esac; }
require_steamos() { return 0; }
require_command() { return 0; }
toolbox_sudo() { "$@"; }
load_config() { :; }
MOCK_FAIL='' MOCK_UPGRADE=0 MOCK_HHD=0
reset_state() {
    echo enabled > "$STATE/readonly"
    echo 0.70.0 > "$STATE/version"
    for name in active enabled suspend-enabled; do echo 0 > "$STATE/$name"; done
    : > "$CALLS"
}
steamos-readonly() {
    echo "readonly $*" >> "$CALLS"
    case "$1" in
        status) cat "$STATE/readonly" ;;
        disable) echo disabled > "$STATE/readonly" ;;
        enable) echo enabled > "$STATE/readonly" ;;
    esac
}
systemctl() {
    echo "systemctl $*" >> "$CALLS"
    [ "$MOCK_FAIL" != "systemctl:$*" ] || return 1
    case "$1" in
        is-active)
            case "$*" in
                *hhd.service) [ "$MOCK_HHD" = 1 ] ;;
                *) [ "$(cat "$STATE/active")" = 1 ] ;;
            esac ;;
        is-enabled)
            case "$*" in
                *suspend*) file=suspend-enabled ;;
                *) file=enabled ;;
            esac
            if [ "$(cat "$STATE/$file")" = 1 ]; then echo enabled; else echo disabled; return 1; fi ;;
        enable|disable)
            case "$*" in *suspend*) file=suspend-enabled;; *) file=enabled;; esac
            if [ "$1" = enable ]; then echo 1 > "$STATE/$file"; else echo 0 > "$STATE/$file"; fi ;;
        stop) echo 0 > "$STATE/active" ;;
        restart) echo 1 > "$STATE/active" ;;
        daemon-reload) : ;;
        *) fail 'Unexpected service operation' ;;
    esac
}
udevadm() {
    echo "udev $*" >> "$CALLS"
    if [ "$MOCK_FAIL" = signal ]; then MOCK_FAIL=''; kill -TERM "$BASHPID"; fi
    [ "$MOCK_FAIL" != udev ]
}
systemd-hwdb() { echo "hwdb $*" >> "$CALLS"; return 0; }
ipu_check() { IPU_CHECK_STATE=skip; [ "$MOCK_UPGRADE" = 0 ] || IPU_CHECK_STATE=upgrade; IPU_CANDIDATE=0.79.0; }
ipu_upgrade_package() { echo package-update >> "$CALLS"; echo 0.79.0 > "$STATE/version"; }
ipu_runtime_version() { cat "$STATE/version"; }
vercmp() {
    local a="${1%%-*}" b="${2%%-*}" first
    [ "$a" != "$b" ] || { echo 0; return; }
    first="$(printf '%s\n' "$a" "$b" | LC_ALL=C sort -n -t . -k1,1 -k2,2 -k3,3 | head -1)"
    if [ "$first" = "$a" ]; then echo -1; else echo 1; fi
}
download_github_file() {
    echo download >> "$CALLS"
    [ "$1:$3" = "$IPU_OFFICIAL_URL:$IPU_OFFICIAL_SHA256" ] || fail 'Unpinned download'
    [ "$MOCK_FAIL" != download ] || return 1
    echo fixture > "$2"
}
python3() {
    [ "$1" = "$PROJECT_ROOT/scripts/inputplumber_overlay.py" ] || fail 'Unexpected program'
    echo "overlay $2" >> "$CALLS"
    [ "$MOCK_FAIL" != "$2" ] || return 1
    case "$2" in
        verify) : ;;
        install) echo 0.81.0 > "$STATE/version"; echo '/var/lib/renkit/inputplumber-backups/v0.81.0-test' ;;
        restore) echo 0.70.0 > "$STATE/version" ;;
    esac
}

reset_state
ipu_manual_update > "$TEST_ROOT/success" || fail 'Stopped-service fallback failed'
[ "$(cat "$STATE/version")" = 0.81.0 ] || fail 'Official fallback not installed'
[ "$(cat "$STATE/active")$(cat "$STATE/enabled")$(cat "$STATE/suspend-enabled")" = 111 ] || fail 'Controller and suspend support not enabled'
[ "$(cat "$STATE/readonly")" = enabled ] || fail 'Protection not restored'
grep -Fq '完整关机后再开机' "$TEST_ROOT/success" || fail 'Power-cycle advice missing'
! grep -Eq 'action=(remove|add)' "$CALLS" || fail 'Global device removal used'
grep -Fq 'udev trigger --action=change --subsystem-match=input' "$CALLS" || fail 'Scoped input reload missing'

for stage in download verify install udev signal 'systemctl:enable inputplumber.service' \
    'systemctl:enable inputplumber-suspend.service' 'systemctl:restart inputplumber.service'; do
    reset_state; MOCK_FAIL="$stage"
    if ipu_manual_update > "$TEST_ROOT/error" 2>&1; then fail "Failure masked: $stage"; fi
    [ "$(cat "$STATE/readonly")" = enabled ] || fail "Protection lost after $stage"
    [ "$(cat "$STATE/enabled")$(cat "$STATE/suspend-enabled")" = 00 ] || fail "Service state lost: $stage"
    [ "$(cat "$STATE/version")" = 0.70.0 ] || fail "Files not rolled back: $stage"
done
MOCK_FAIL=''
reset_state
echo 1 > "$STATE/active"; echo 1 > "$STATE/enabled"; echo 1 > "$STATE/suspend-enabled"
MOCK_FAIL='systemctl:enable inputplumber.service'
if ipu_manual_update >/dev/null; then fail 'Enabled-service failure masked'; fi
[ "$(cat "$STATE/active")$(cat "$STATE/enabled")$(cat "$STATE/suspend-enabled")" = 111 ] || fail 'Original active state lost'
MOCK_FAIL=''
reset_state; MOCK_UPGRADE=1
ipu_manual_update >/dev/null || fail 'System package route failed'
[ "$(cat "$STATE/version")" = 0.79.0 ] || fail 'System package version missing'
! grep -Fq download "$CALLS" || fail 'Sufficient system package unnecessarily replaced'
reset_state; echo 0.90.0 > "$STATE/version"
ipu_manual_update >/dev/null || fail 'Newer version failed'
[ "$(cat "$STATE/version")" = 0.90.0 ] || fail 'Newer binary downgraded'
! grep -Eq 'download|package-update' "$CALLS" || fail 'Newer version replaced'
reset_state; ZHOUKEER_AUTO_CONFIRM=0
if ipu_manual_update >/dev/null; then fail 'Missing consent accepted'; fi
! grep -Fq 'readonly disable' "$CALLS" || fail 'Changed system before consent'
ZHOUKEER_AUTO_CONFIRM=1 MOCK_HHD=1
if ipu_manual_update >/dev/null; then fail 'Conflicting input manager accepted'; fi
! grep -Fq 'readonly disable' "$CALLS" || fail 'Changed system with conflicting manager'
for path in "$TEST_ROOT"/tmp.*; do [ ! -d "$path" ] || fail 'Temporary download leaked'; done
echo 'PASS: manual package/fallback routes, exact hash, disabled services, activation, rollback and scoped input reload'
