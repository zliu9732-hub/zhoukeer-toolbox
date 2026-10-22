#!/bin/bash
set -euo pipefail
# All filesystem discovery, allocation and swap operations are mocked. Actual
# writes/moves are tiny fixtures confined to TMP_ROOT; no disk/system changes.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT
export ZHOUKEER_APP_DIR="$TMP_ROOT/apps"
source "$PROJECT_ROOT/modules/memory_tuning.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
log() { printf '%s\n' "$*" >> "$TMP_ROOT/diagnostics"; }
require_command() { return 0; }
df() { printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 99999999 1 99999998 1%% /\n'; }
findmnt() {
    [ "$MODE" != fs-error ] || return 1
    case "$MODE" in btrfs|nocow-fail) echo btrfs ;; unknown) echo unknown ;; *) echo ext4 ;; esac
}
memory_test_mode() {
    if stat -c '%a' "$1" >/dev/null 2>&1; then stat -c '%a' "$1"; else stat -f '%Lp' "$1"; fi
}
memory_swap_is_active() { [ -f "$ACTIVE" ] && [ "$(cat "$ACTIVE")" = "$1" ]; }
toolbox_sudo() {
    local cmd="$1"; shift
    printf '%s %s\n' "$cmd" "$*" >> "$EVENTS"
    case "$cmd" in
        test) test "$@" ;;
        install)
            [ "${@: -1}" = "$NEW" ] || fail '非临时文件写入'
            printf '' > "$NEW"; command chmod 0600 "$NEW"
            ;;
        chattr)
            [ "$1" = +C ] && [ "${@: -1}" = "$NEW" ] || fail '改动了原文件属性'
            [ "$MODE" != nocow-fail ] || return 1
            [ ! -s "$NEW" ] || fail '分配空间后才设置 NOCOW'
            : > "$NOCOW"
            ;;
        fallocate)
            [ "${@: -1}" = "$NEW" ] || fail '改动了原文件'
            [ "$MODE" != btrfs ] || [ -f "$NOCOW" ] || return 1
            [ -f "$NEW" ] && [ "$(memory_test_mode "$NEW")" = 600 ] || fail '分配空间前权限不安全'
            printf 'allocated tiny fixture\n' > "$NEW"
            [ "$MODE" != allocate-fail ]
            ;;
        chmod) command chmod "$@" ;;
        mkswap)
            [ "$MODE" != format-fail ] || return 1
            printf 'new swap\n' > "${@: -1}"
            ;;
        lsattr) printf '%s\n' '---------------- file' ;;
        swapoff)
            [ "$MODE" != swapoff-fail ] || return 1
            command rm -f "$ACTIVE"
            ;;
        swapon)
            local target="${@: -1}"
            if [ "$MODE" = swapon-fail ] && [ "$(cat "$target")" = 'new swap' ]; then return 1; fi
            printf '%s' "$target" > "$ACTIVE"
            ;;
        mv) command mv "$@" ;;
        rm) command rm "$@" ;;
        *) fail "未模拟的管理员命令：$cmd" ;;
    esac
}
for MODE in ext4 btrfs allocate-fail nocow-fail format-fail swapoff-fail swapon-fail unknown fs-error; do
    case_dir="$TMP_ROOT/$MODE"
    mkdir "$case_dir"
    MEMORY_SWAPFILE_PATH="$case_dir/swapfile"
    MEMORY_FALLBACK_SWAPFILE_PATH="$case_dir/fallback"
    NEW="$case_dir/.zhoukeer-swapfile.new.$$"
    ACTIVE="$case_dir/active" NOCOW="$case_dir/nocow" EVENTS="$case_dir/events"
    printf 'original swap\n' > "$MEMORY_SWAPFILE_PATH"
    printf '%s' "$MEMORY_SWAPFILE_PATH" > "$ACTIVE"
    : > "$EVENTS"
    status=0
    memory_create_swapfile 8 > "$case_dir/output" 2>&1 || status=$?
    case "$MODE" in
        ext4|btrfs)
            [ "$status" -eq 0 ] || fail "$MODE 创建失败：$(cat "$case_dir/output")"
            [ "$(cat "$MEMORY_SWAPFILE_PATH")" = 'new swap' ] || fail '没有装入新文件'
            ;;
        *)
            [ "$status" -ne 0 ] || fail "$MODE 失败被吞掉"
            [ "$(cat "$MEMORY_SWAPFILE_PATH")" = 'original swap' ] || fail "$MODE 丢失原文件"
            ;;
    esac
    memory_swap_is_active "$MEMORY_SWAPFILE_PATH" || fail "$MODE 原有或新虚拟内存未启用"
    [ ! -e "$NEW" ] || fail "$MODE 残留临时文件占用空间"
    [ ! -e "$case_dir/.zhoukeer-swapfile.backup.$$" ] || fail "$MODE 残留备份"
    case "$MODE" in
        allocate-fail|nocow-fail|format-fail|unknown|fs-error)
            ! grep -Eq '^(swapoff|mv) ' "$EVENTS" || fail "$MODE 准备失败时已停用或移动原文件"
            ;;
    esac
done
echo 'PASS: ext4/Btrfs 创建顺序、分配失败清理、旧文件保留、停用/启用失败恢复'
