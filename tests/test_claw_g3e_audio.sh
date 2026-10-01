#!/bin/bash
set -euo pipefail

# Only temporary files and mocked system commands; no real Linux install or network.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
source "$PROJECT_ROOT/modules/claw_g3e_audio.sh"
LOG_DIR="$TEST_ROOT/logs" LOG_FILE="$TEST_ROOT/audio.log" APP_DIR="$TEST_ROOT/apps"
CLAW_AUDIO_DMI="$TEST_ROOT/dmi" CLAW_AUDIO_MODULES="$TEST_ROOT/modules"
CLAW_AUDIO_SOUNDWIRE="$TEST_ROOT/rt721"
CALLS="$TEST_ROOT/calls" READONLY_FILE="$TEST_ROOT/readonly"
MOCK_KVER=7.2.0-valve1-1-neptune-72 MOCK_FAIL='' MOCK_DKMS=''
MOCK_HEADERS_VERSION=7.2.0-1 MOCK_ID=1000
export TMPDIR="$TEST_ROOT" ZHOUKEER_AUTO_CONFIRM=1
mkdir -p "$CLAW_AUDIO_DMI" "$CLAW_AUDIO_SOUNDWIRE" "$CLAW_AUDIO_MODULES/$MOCK_KVER/build"
printf '%s\n' 'Claw 8 EX AI+ CG3EM' > "$CLAW_AUDIO_DMI/product_name"
echo MS-1T91 > "$CLAW_AUDIO_DMI/board_name"
echo linux-neptune-72 > "$CLAW_AUDIO_MODULES/$MOCK_KVER/pkgbase"
touch "$CLAW_AUDIO_MODULES/$MOCK_KVER/build/Makefile"
echo enabled > "$READONLY_FILE"
: > "$CALLS"
fail() { echo "FAIL: $*" >&2; exit 1; }
uname() { case "$1" in -s) echo Linux;; -m) echo x86_64;; -r) echo "$MOCK_KVER";; esac; }
require_steamos() { return 0; }
id() { echo "$MOCK_ID"; }
require_command() { return 0; }
toolbox_sudo() { "$@"; }
steamos-readonly() {
    echo "readonly $*" >> "$CALLS"
    case "$1" in
        status) cat "$READONLY_FILE" ;;
        disable) echo disabled > "$READONLY_FILE"; [ "$MOCK_FAIL" != disable ] ;;
        enable) [ "$MOCK_FAIL" != restore ] && echo enabled > "$READONLY_FILE" ;;
    esac
}
pacman() {
    echo "pacman $*" >> "$CALLS"
    case "$1" in
        -Q) echo 'linux-neptune-72 7.2.0-1' ;;
        -Si) printf 'Version : %s\n' "$MOCK_HEADERS_VERSION" ;;
        -S) [ "$MOCK_FAIL" != dependencies ] ;;
        -U) [ "$MOCK_FAIL" != package ] ;;
        *) fail 'Unexpected package action' ;;
    esac
}
make() {
    echo "make $*" >> "$CALLS"
    if [ "$1" = -s ]; then echo "$MOCK_KVER"
    elif [ "$MOCK_FAIL" = signal ]; then kill -TERM "$BASHPID"
    elif [ "$MOCK_FAIL" = hup ]; then kill -HUP "$BASHPID"
    else [ "$MOCK_FAIL" != compile ]; fi
}
makepkg() {
    echo "makepkg $*" >> "$CALLS"
    [ "$MOCK_FAIL" != makepkg ] || return 1
    touch claw-rt721-fix-dkms-0.1.0-1-x86_64.pkg.tar.zst
}
dkms() {
    echo "dkms $*" >> "$CALLS"
    case "$1" in
        status) printf '%s\n' "$MOCK_DKMS" ;;
        build) [ "$MOCK_FAIL" != dkms-build ] ;;
        install) [ "$MOCK_FAIL" != dkms-install ] ;;
        *) fail 'Unexpected module removal' ;;
    esac
}
depmod() { echo "depmod $*" >> "$CALLS"; [ "$MOCK_FAIL" != depmod ]; }
modinfo() { echo "modinfo $*" >> "$CALLS"; [ "$MOCK_FAIL" != modinfo ]; }
systemctl() {
    echo "systemctl $*" >> "$CALLS"
    [ "$MOCK_FAIL" != "systemctl:$*" ]
}
wpctl() { echo "wpctl $*" >> "$CALLS"; [ "$MOCK_FAIL" != wpctl ]; }

before_trap="$(trap -p EXIT)"
claw_audio_install > "$TEST_ROOT/success" || fail 'Installation simulation failed'
[ "$(cat "$READONLY_FILE")" = enabled ] || fail 'Read-only state lost'
[ "$(trap -p EXIT)" = "$before_trap" ] || fail 'Caller cleanup trap overwritten'
grep -Fq 'dkms install -m claw-rt721-fix -v 0.1.0 -k' "$CALLS" || fail 'Module not installed'
grep -Fq 'systemctl restart claw-rt721-fix.service' "$CALLS" || fail 'Audio service not started'
grep -Fq '手动重启' "$TEST_ROOT/success" || fail 'Restart advice missing'

for stage in disable dependencies compile signal hup makepkg package dkms-build dkms-install depmod modinfo \
    'systemctl:daemon-reload' 'systemctl:enable claw-rt721-fix.service' \
    'systemctl:restart claw-rt721-fix.service' 'systemctl:is-active --quiet claw-rt721-fix.service' \
    'systemctl:--user restart pipewire pipewire-pulse wireplumber' wpctl; do
    MOCK_FAIL="$stage"
    : > "$CALLS"
    echo enabled > "$READONLY_FILE"
    if claw_audio_install > "$TEST_ROOT/failure" 2>&1; then fail "Failure masked: $stage"; else status=$?; fi
    [ "$(cat "$READONLY_FILE")" = enabled ] || fail "Read-only state lost after $stage"
    if [ "$stage" = signal ]; then
        [ "$status" -eq 143 ] || fail 'Interrupt status lost'
    elif [ "$stage" = hup ]; then
        [ "$status" -eq 129 ] || fail 'Hangup status lost'
    else
        grep -Fq '音频修复未完成' "$TEST_ROOT/failure" || fail "No failure notice: $stage"
    fi
    [ "$(trap -p EXIT)" = "$before_trap" ] || fail 'Failure overwrote caller trap'
done
MOCK_FAIL=restore
if claw_audio_install > "$TEST_ROOT/restore-failure"; then fail 'Protection restore failure masked'; fi
grep -Fq '恢复系统只读保护失败' "$TEST_ROOT/restore-failure" || fail 'No protection failure warning'
MOCK_FAIL=''
echo disabled > "$READONLY_FILE"
claw_audio_install > /dev/null || fail 'Originally writable state failed'
[ "$(cat "$READONLY_FILE")" = disabled ] || fail 'Originally writable state changed'

# Already installed DKMS is idempotent; no forced removal or ignored compilation failure.
MOCK_DKMS='claw-rt721-fix/0.1.0, kernel, x86_64: installed'
: > "$CALLS"
claw_audio_install >/dev/null || fail 'Already installed module failed'
! grep -Eq '^dkms (build|install|remove)' "$CALLS" || fail 'Installed module rebuilt or removed unnecessarily'
MOCK_DKMS=''

# Exact model, board, hardware, kernel, root user, source and consent gates precede writes.
assert_rejected_before_write() {
    : > "$CALLS"
    if claw_audio_install > "$TEST_ROOT/rejected" 2>&1; then fail 'Invalid target accepted'; fi
    ! grep -Eq '^(readonly disable|pacman -[SU]( |$)|dkms (build|install)|makepkg|systemctl)' "$CALLS" || fail 'Rejected target changed system'
}
ZHOUKEER_AUTO_CONFIRM=0; assert_rejected_before_write; ZHOUKEER_AUTO_CONFIRM=1
MOCK_ID=0; assert_rejected_before_write; MOCK_ID=1000
MOCK_HEADERS_VERSION=7.2.1-1; assert_rejected_before_write; MOCK_HEADERS_VERSION=7.2.0-1
echo 'Claw 8 AI+ A2VM' > "$CLAW_AUDIO_DMI/product_name"; assert_rejected_before_write
echo 'Claw 8 EX AI+ CG3EM Launch Pack' > "$CLAW_AUDIO_DMI/product_name"
claw_audio_check >/dev/null || fail 'Launch Pack model rejected'
echo 'MS-other' > "$CLAW_AUDIO_DMI/board_name"; assert_rejected_before_write
echo MS-1T91 > "$CLAW_AUDIO_DMI/board_name"
MOCK_KVER=6.11.0; assert_rejected_before_write
MOCK_KVER=7.2.0-valve1-1-neptune-72
rm -d "$CLAW_AUDIO_SOUNDWIRE"; assert_rejected_before_write; mkdir "$CLAW_AUDIO_SOUNDWIRE"
CLAW_AUDIO_SOURCE_ORIGINAL="$CLAW_AUDIO_SOURCE"
CLAW_AUDIO_SOURCE="$TEST_ROOT/tampered"
cp -R "$CLAW_AUDIO_SOURCE_ORIGINAL" "$CLAW_AUDIO_SOURCE"
echo tamper >> "$CLAW_AUDIO_SOURCE/Makefile"; assert_rejected_before_write
CLAW_AUDIO_SOURCE="$CLAW_AUDIO_SOURCE_ORIGINAL"

python3 "$PROJECT_ROOT/scripts/prepare_claw_audio.py" "$CLAW_AUDIO_SOURCE" "$TEST_ROOT/patched"
! grep -Fq 'LLVM=1' "$TEST_ROOT/patched/Makefile" || fail 'LLVM override remains'
grep -Fq 'Claw 8 EX AI+ CG3EM Launch Pack' "$TEST_ROOT/patched/claw_rt721_amp.c" || fail 'Launch Pack DMI patch missing'
grep -Fq '!strcmp(board, "MS-1T91")' "$TEST_ROOT/patched/claw_rt721_amp.c" || fail 'Board restriction removed'
python3 - "$TEST_ROOT/patched" <<'PY'
from pathlib import Path
import hashlib, re, sys
p = Path(sys.argv[1])
text = (p / 'PKGBUILD').read_text()
hashes = re.findall(r"'[0-9a-f]{64}'", text)
names = ['claw_rt721_amp.c', 'Makefile', 'dkms.conf', 'README.md',
         'claw-rt721-fix.service', 'claw-rt721-fix-sleep']
assert hashes == ["'" + hashlib.sha256((p / n).read_bytes()).hexdigest() + "'" for n in names]
assert 'skipinteg' not in text and "depends=('dkms' 'gcc')" in text
PY

# Every invocation workspace is removed after success or failure.
for path in "$TEST_ROOT"/tmp.*; do [ ! -d "$path" ] || fail 'Temporary workspace leaked'; done
echo 'PASS: G3E exact target/consent gates, verified patches, build/service failures, read-only restoration and cleanup'
