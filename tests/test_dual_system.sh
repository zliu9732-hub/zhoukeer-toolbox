#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/dual_system.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local text="$1"
    local expected="$2"
    local label="$3"

    printf '%s\n' "$text" | grep -Fq -- "$expected" || fail "$label"
}

# shellcheck disable=SC1090
source "$MODULE"

BOOT_PATH="$TMP_ROOT/esp"
mkdir -p "$BOOT_PATH/loader"
printf '%s\n' 'default steamos.conf' 'timeout 3' > "$BOOT_PATH/loader/loader.conf"
ZHOUKEER_BOOT_PATH="$BOOT_PATH"
ZHOUKEER_ALLOW_NON_STEAMOS=1
DUAL_BOOT_TIMEOUT=5

bootctl() {
    case "${1:-}" in
        --print-boot-path|--print-esp-path) printf '%s\n' "$BOOT_PATH" ;;
        is-installed) return 1 ;;
        *) return 1 ;;
    esac
}

toolbox_sudo() {
    "$@"
}

output="$(enable_dual_boot_menu)"
assert_contains "$output" "等待 5 秒" "启用双系统菜单未报告等待时间"
grep -Fxq 'timeout 5' "$BOOT_PATH/loader/loader.conf" || fail "启用双系统菜单未写入 timeout 5"
grep -Fq 'default steamos.conf' "$BOOT_PATH/loader/loader.conf" || fail "写入双系统菜单时丢失原配置"
find "$BOOT_PATH/loader" -name 'loader.conf.zhoukeer-backup.*' -type f | grep -q . || \
    fail "修改引导配置前没有创建备份"

output="$(hide_dual_boot_menu)"
assert_contains "$output" "等待时间已设为 0 秒" "隐藏双系统菜单未报告 timeout 0"
grep -Fxq 'timeout 0' "$BOOT_PATH/loader/loader.conf" || fail "隐藏双系统菜单未写入 timeout 0"
if grep -Eq '^(install_refind|remove_refind|refind_mount_esp)\(\)' "$MODULE"; then
    fail "已停用的 rEFInd EFI 写入函数仍留在运行模块中"
fi

MOUNT_PATH="$TMP_ROOT/mount"
SHORTCUT_PATH="$TMP_ROOT/互通盘"
OPTIONS_FILE="$TMP_ROOT/udisks-options"
MOUNTED_STATE="$TMP_ROOT/mounted-state"
mkdir -p "$MOUNT_PATH"
ZHOUKEER_SHARED_DRIVE_LINK="$SHORTCUT_PATH"
SHARED_DRIVE_LINK="$SHORTCUT_PATH"
ZHOUKEER_SHARED_DRIVE_DEVICE="/dev/test-share"

lsblk() {
    case " $* " in
        *' FSTYPE /dev/test-share '*) printf '%s\n' 'ntfs' ;;
        *) printf '%s\n' '/dev/test-share part ntfs' ;;
    esac
}

findmnt() {
    if [ -f "$MOUNTED_STATE" ]; then
        printf '%s\n' "$MOUNT_PATH"
        return 0
    fi
    return 1
}

udisksctl() {
    case "${1:-}" in
        mount)
            printf '%s\n' "$*" >> "$OPTIONS_FILE"
            : > "$MOUNTED_STATE"
            printf 'Mounted /dev/test-share at %s.\n' "$MOUNT_PATH"
            ;;
        unmount) rm -f -- "$MOUNTED_STATE"; return 0 ;;
        *) return 1 ;;
    esac
}

mount_shared_drive
[ -L "$SHORTCUT_PATH" ] || fail "互通盘挂载未创建快捷入口"
mount_calls_before="$(grep -c '^mount ' "$OPTIONS_FILE")"
mount_shared_drive
mount_calls_after="$(grep -c '^mount ' "$OPTIONS_FILE")"
[ "$mount_calls_before" = "$mount_calls_after" ] || fail "已挂载互通盘被重复挂载"

mount_shared_drive_with_protection
[ -L "$SHORTCUT_PATH" ] || fail "互通盘保护未创建快捷入口"
grep -Fq -- '--options ro' "$OPTIONS_FILE" || fail "互通盘保护未使用只读挂载"

restore_shared_drive_write
if [ "$(tail -n 1 "$OPTIONS_FILE")" != 'mount --block-device /dev/test-share' ]; then
    fail "恢复互通盘写入仍带有只读挂载参数"
fi

echo "PASS: 双系统菜单、互通盘挂载和只读保护测试通过"
