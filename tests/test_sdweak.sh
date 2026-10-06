#!/bin/bash
set -euo pipefail
# All device, download, privilege and installer commands are mocked.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PROJECT_ROOT/modules/sdweak.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
export HOME="$TEST_ROOT/home" TMPDIR="$TEST_ROOT"
mkdir "$HOME" "$TEST_ROOT/dmi"
SDWEAK_DMI="$TEST_ROOT/dmi"
LOG_FILE="$TEST_ROOT/log" CALLS="$TEST_ROOT/calls"
readonly_file="$TEST_ROOT/readonly"
MOCK_VERSION=3.8 MOCK_ID=steamos MOCK_FAIL='' MOCK_MIRROR=success
log() { :; }
fail() { echo "FAIL: $*" >&2; exit 1; }
uname() { case "$1" in -s) echo Linux;; -m) echo x86_64;; esac; }
id() { echo 1000; }
require_steamos() { return 0; }
require_command() { return 0; }
platform_os_release_value() { case "$1" in ID) echo "$MOCK_ID";; VERSION_ID) echo "$MOCK_VERSION";; esac; }
load_config() { :; }
reset() { echo Valve > "$SDWEAK_DMI/sys_vendor"; echo Jupiter > "$SDWEAK_DMI/product_name"; echo Jupiter > "$SDWEAK_DMI/board_name"; echo enabled > "$readonly_file"; : > "$CALLS"; }
download_gitee_mirror_file() {
    echo mirror >> "$CALLS"
    [ "$1" = sdweak ] || fail 'Unexpected mirror'
    [ "$3" = "$SDWEAK_SHA256" ] || fail 'Mirror integrity check missing'
    [ "${GITEE_MIRROR_MIN_SPEED_BYTES:-}" = 1024 ] && \
        [ "${GITEE_MIRROR_MIN_SPEED_TIME:-}" = 90 ] || fail 'Slow mirror tolerance missing'
    DOWNLOAD_LOCAL_IO_FAILED=0
    [ "$MOCK_MIRROR" != io ] || { DOWNLOAD_LOCAL_IO_FAILED=1; return 1; }
    [ "$MOCK_MIRROR" = success ] && [ "$MOCK_FAIL" != download ] || return 1
    echo fixture > "$2"
}
download_github_file() {
    echo download >> "$CALLS"
    [ "$1" = https://github.com/Taskerer/SDWEAK/releases/download/v2.1.0/SDWEAK.zip ] || fail 'Unexpected source'
    [ "$3" = 5e91ca94577e3a999b6a8ea1a3e849bb168fedcc5b12b3cc41a00ca355d00d9e ] || fail 'Integrity check missing'
    [ "${GITHUB_MIN_SPEED_BYTES:-}" = 1024 ] && \
        [ "${GITHUB_MIN_SPEED_TIME:-}" = 90 ] || fail 'Slow fallback tolerance missing'
    [ "$MOCK_FAIL" != download ] || return 1
    echo fixture > "$2"
}
python3() { echo prepare >> "$CALLS"; [ "$MOCK_FAIL" != prepare ]; }
toolbox_sudo() { echo "admin $*" >> "$CALLS"; if [ "$1" != true ]; then "$@"; fi; }
steamos-readonly() {
    case "$1" in status) cat "$readonly_file";; enable) echo enabled > "$readonly_file";; disable) echo disabled > "$readonly_file";; esac
}
sdweak_execute() {
    echo execute >> "$CALLS"
    steamos-readonly disable
    if [ "$MOCK_FAIL" = signal ]; then kill -TERM "$BASHPID"; fi
    [ "$MOCK_FAIL" != execute ]
}
reset
export ZHOUKEER_AUTO_CONFIRM=1
for model in Jupiter Galileo; do
 reset; echo "$model" > "$SDWEAK_DMI/product_name"; echo "$model" > "$SDWEAK_DMI/board_name"
 sdweak_install > "$TEST_ROOT/output" || fail "$model failed"
 [ "$(cat "$readonly_file")" = enabled ] || fail 'Protection not restored'
 grep -Fq '手动重启' "$TEST_ROOT/output" || fail 'Restart advice missing'
 ! grep -q '^download$' "$CALLS" || fail 'Official source used before mirror'
done
reset; MOCK_MIRROR=unavailable
sdweak_install >/dev/null || fail 'Official fallback failed'
[ "$(sed -n '1,2p' "$CALLS")" = $'mirror\ndownload' ] || fail 'Mirror fallback order incorrect'
reset; MOCK_MIRROR=io
if sdweak_install >/dev/null; then fail 'Local write failure accepted'; fi
! grep -Eq 'download|admin|execute' "$CALLS" || fail 'Local write failure retried or installed'
MOCK_MIRROR=success
for stage in download prepare execute signal; do
 reset; MOCK_FAIL="$stage"
 if sdweak_install > "$TEST_ROOT/error" 2>&1; then fail "Failure masked: $stage"; fi
 [ "$(cat "$readonly_file")" = enabled ] || fail "Protection lost: $stage"
 if [ "$stage" = download ]; then
  grep -Fq '尚未开始安装' "$TEST_ROOT/error" || fail 'Download failure mistaken for installation'
  ! grep -Fq '部分设置改变' "$TEST_ROOT/error" || fail 'Download failure falsely reported changes'
 fi
done
MOCK_FAIL=''; reset; echo disabled > "$readonly_file"
sdweak_install >/dev/null || fail 'Original writable state failed'
[ "$(cat "$readonly_file")" = disabled ] || fail 'Original writable state changed'
for item in manufacturer product board version system consent cryo; do
 reset; MOCK_VERSION=3.8 MOCK_ID=steamos ZHOUKEER_AUTO_CONFIRM=1
 case "$item" in
 manufacturer) echo MSI > "$SDWEAK_DMI/sys_vendor";;
 product) echo 'ROG Ally' > "$SDWEAK_DMI/product_name";;
 board) echo 'ROG Ally' > "$SDWEAK_DMI/board_name";;
 version) MOCK_VERSION=3.7.10;; system) MOCK_ID=arch;; consent) ZHOUKEER_AUTO_CONFIRM=0;; cryo) mkdir "$HOME/.cryo_utilities";;
 esac
 if sdweak_install >/dev/null; then fail "Unsupported state accepted: $item"; fi
 ! grep -Eq 'mirror|download|admin|execute' "$CALLS" || fail "Changes before preflight: $item"
done
for path in "$TEST_ROOT"/tmp.*; do [ ! -d "$path" ] || fail 'Workspace leaked'; done
download_policy_url_allowed "$SDWEAK_URL" || fail 'Official package blocked by policy'
if download_policy_url_allowed 'https://github.com/untrusted/SDWEAK/releases/download/v2.1.0/SDWEAK.zip'; then fail 'Untrusted package allowed'; fi
echo 'PASS: Steam Deck gate, verified mirror first, safe fallback, local write failure, failure/signal cleanup and readonly state'
