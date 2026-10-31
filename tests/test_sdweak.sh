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
MOCK_VERSION=3.9 MOCK_ID=steamos MOCK_FAIL=''
CORE_PACKAGE="$SDWEAK_CORE_PACKAGE"
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
    fail 'Verified bundled SDWEAK attempted a network request'
}
download_github_file() {
    fail 'Bundled SDWEAK attempted an official network request'
}
python3() {
    [ "$1" = "$PROJECT_ROOT/scripts/prepare_sdweak.py" ] && [ "$2" = "$CORE_PACKAGE" ] || fail 'Wrong preparation source'
    echo prepare >> "$CALLS"; [ "$MOCK_FAIL" != prepare ]
}
toolbox_sudo() {
    echo "admin $*" >> "$CALLS"
    [ "$MOCK_FAIL" != auth ] || return 1
    local MOCK_ADMIN=1
    "$@"
}
steamos-readonly() {
    case "$1" in status)
        [ "${MOCK_ADMIN:-0}" = 1 ] || { echo 'needs administrator access'; return 1; }
        case "$MOCK_FAIL" in
            status-empty) return 1 ;;
            status-error) echo 'read failed' >&2; return 2 ;;
            status-unknown) echo unknown; return 0 ;;
            status-mismatch) echo enabled; return 1 ;;
            status-false-disabled) echo disabled; return 2 ;;
            status-sysext) printf '%s\n' 'disabled, but loaded sysexts may result in' 'some parts of the filesystem being read-only'; return 1 ;;
        esac
        cat "$readonly_file"
        [ "$(cat "$readonly_file")" = enabled ]
        ;; enable) echo enabled > "$readonly_file";; disable) echo disabled > "$readonly_file";; esac
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
 grep -Fq '检查 SDWEAK 安装文件' "$TEST_ROOT/output" || fail 'Package checking step missing'
done
for stage in missing prepare execute signal; do
 reset; MOCK_FAIL="$stage"
 SDWEAK_CORE_PACKAGE="$CORE_PACKAGE"
 [ "$stage" != missing ] || SDWEAK_CORE_PACKAGE="$TEST_ROOT/missing.zip"
 if sdweak_install > "$TEST_ROOT/error" 2>&1; then fail "Failure masked: $stage"; fi
 [ "$(cat "$readonly_file")" = enabled ] || fail "Protection lost: $stage"
 ! grep -Fq '下载失败' "$TEST_ROOT/error" || fail 'Non-download failure mislabeled as download'
 if [ "$stage" = missing ] || [ "$stage" = prepare ]; then
  grep -Fq '尚未开始安装' "$TEST_ROOT/error" || fail 'Package failure mistaken for installation'
  ! grep -Eq 'admin|execute' "$CALLS" || fail 'Changed system before package validation'
  ! grep -Fq '部分设置改变' "$TEST_ROOT/error" || fail 'Package failure falsely reported changes'
 fi
done
SDWEAK_CORE_PACKAGE="$CORE_PACKAGE"
MOCK_FAIL=''; reset; echo disabled > "$readonly_file"
sdweak_install >/dev/null || fail 'Original writable state failed'
[ "$(cat "$readonly_file")" = disabled ] || fail 'Original writable state changed'
for stage in status-empty status-error status-unknown status-mismatch status-false-disabled status-sysext auth; do
 reset; MOCK_FAIL="$stage"
 if sdweak_install > "$TEST_ROOT/error" 2>&1; then fail "Invalid status accepted: $stage"; fi
 ! grep -Fxq execute "$CALLS" || fail "Started installation without known protection state: $stage"
 ! grep -Eq 'admin steamos-readonly (enable|disable)' "$CALLS" || fail "Changed protection after failed status: $stage"
 grep -Fq '尚未开始安装' "$TEST_ROOT/error" || fail "Unclear status failure: $stage"
done
MOCK_FAIL=''
for item in manufacturer product board version old-system system consent cryo; do
 reset; MOCK_VERSION=3.9 MOCK_ID=steamos ZHOUKEER_AUTO_CONFIRM=1
 case "$item" in
 manufacturer) echo MSI > "$SDWEAK_DMI/sys_vendor";;
 product) echo 'ROG Ally' > "$SDWEAK_DMI/product_name";;
 board) echo 'ROG Ally' > "$SDWEAK_DMI/board_name";;
 version) MOCK_VERSION=3.7.10;; old-system) MOCK_VERSION=3.8;; system) MOCK_ID=arch;; consent) ZHOUKEER_AUTO_CONFIRM=0;; cryo) mkdir "$HOME/.cryo_utilities";;
 esac
 if sdweak_install >/dev/null; then fail "Unsupported state accepted: $item"; fi
 ! grep -Eq 'mirror|download|admin|execute' "$CALLS" || fail "Changes before preflight: $item"
done
for path in "$TEST_ROOT"/tmp.*; do [ ! -d "$path" ] || fail 'Workspace leaked'; done
download_policy_url_allowed "$SDWEAK_URL" || fail 'Official package blocked by policy'
if download_policy_url_allowed 'https://github.com/untrusted/SDWEAK/releases/download/v2.1.0/SDWEAK.zip'; then fail 'Untrusted package allowed'; fi
echo 'PASS: Steam Deck gate, bundled install without network, clear pre-install failures, failure/signal cleanup, privileged status, disabled exit=1 and unknown/error rejection'
