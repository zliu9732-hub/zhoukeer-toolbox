#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/clover_boot.sh"
TMP_ROOT="$(mktemp -d)"
ESP="$TMP_ROOT/mounted-esp"
CALLS="$TMP_ROOT/udisks.calls"
GUID="11111111-2222-3333-4444-555555555555"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$ESP/EFI/CLOVER"
printf 'clover\n' > "$ESP/EFI/CLOVER/CLOVERX64.efi"

# shellcheck disable=SC1090
source "$MODULE"

efibootmgr() {
    printf 'Boot0007* Existing Clover HD(1,GPT,%s,0x800,0x100000)/File(\\EFI\\CLOVER\\CLOVERX64.efi)\n' "$GUID"
}

lsblk() {
    case " $* " in
        *' NAME,PARTUUID,FSTYPE '*) printf '/dev/fakeesp %s vfat\n' "$GUID" ;;
        *' PKNAME /dev/fakeesp '*) printf 'fake\n' ;;
        *' PARTN /dev/fakeesp '*) printf '1\n' ;;
        *) return 1 ;;
    esac
}

findmnt() {
    case " $* " in
        *' -S /dev/fakeesp '*) return 1 ;;
        *" -T $ESP -o SOURCE "*) printf '/dev/fakeesp\n' ;;
        *" -T $ESP -o FSTYPE "*) printf 'vfat\n' ;;
        *) return 1 ;;
    esac
}

udisksctl() {
    printf '%s\n' "$*" >> "$CALLS"
    case "${1:-}" in
        mount) printf 'Mounted /dev/fakeesp at %s.\n' "$ESP" ;;
        unmount) return 0 ;;
        *) return 1 ;;
    esac
}

clover_resolve_esp_device || fail "未能从已有 Clover NVRAM 启动项定位 EFI"
[ "$CLOVER_ESP" = "$ESP" ] || fail "临时挂载点识别错误"
[ "$CLOVER_ESP_SOURCE" = '/dev/fakeesp' ] || fail "EFI 设备识别错误"
[ "$CLOVER_DISK" = '/dev/fake' ] || fail "EFI 所在磁盘识别错误"
[ "$CLOVER_PARTITION" = '1' ] || fail "EFI 分区编号识别错误"
[ "$CLOVER_ESP_MOUNTED_BY_TOOLBOX" = '1' ] || fail "未记录临时挂载状态"

clover_release_esp_mount
grep -Fq 'unmount --block-device /dev/fakeesp' "$CALLS" || fail "状态检查后没有卸载临时 EFI"

BAD_ESP="$TMP_ROOT/not-an-esp"
mkdir -p "$BAD_ESP"
bootctl() { return 1; }
clover_device_from_nvram() { printf '%s\n' '/dev/badesp'; }
findmnt() {
    case " $* " in
        *' -S /dev/badesp '*) printf '%s\n' "$BAD_ESP" ;;
        *) return 1 ;;
    esac
}
if clover_find_esp >"$TMP_ROOT/clover-diagnostic.output" 2>&1; then
    fail "不含 EFI 目录的挂载点仍被识别为 EFI 分区"
fi
grep -Fq '不含 EFI 目录' "$TMP_ROOT/clover-diagnostic.output" || \
    fail "Clover EFI 定位失败没有输出具体原因"

FALLBACK_ESP="$TMP_ROOT/fallback-esp"
mkdir -p "$FALLBACK_ESP/EFI/steamos"
printf 'steam\n' > "$FALLBACK_ESP/EFI/steamos/steamcl.efi"
findmnt() {
    case " $* " in
        *' -t vfat,fat,fat32,msdos -o TARGET '*) printf '%s\n' "$BAD_ESP" "$FALLBACK_ESP" ;;
        *) return 1 ;;
    esac
}
CLOVER_ESP_FOUND=""
clover_find_mounted_esp || fail "没有从已挂载 FAT 分区找到实际 EFI"
[ "$CLOVER_ESP_FOUND" = "$FALLBACK_ESP" ] || fail "已挂载 EFI 兜底路径选择错误"

UNMOUNTED_ESP="$TMP_ROOT/unmounted-esp"
mkdir -p "$UNMOUNTED_ESP/EFI/steamos"
printf 'steam\n' > "$UNMOUNTED_ESP/EFI/steamos/steamcl.efi"
lsblk() {
    case " $* " in
        *' NAME,FSTYPE '*) printf '/dev/unmountedesp vfat\n' ;;
        *) return 1 ;;
    esac
}
findmnt() {
    case " $* " in
        *' -S /dev/unmountedesp '*) return 1 ;;
        *) return 1 ;;
    esac
}
udisksctl() {
    printf '%s\n' "$*" >> "$CALLS"
    case "${1:-}" in
        mount) printf 'Mounted /dev/unmountedesp at %s.\n' "$UNMOUNTED_ESP" ;;
        unmount) return 0 ;;
        *) return 1 ;;
    esac
}
CLOVER_ESP_FOUND=""
CLOVER_ESP_MOUNTED_BY_TOOLBOX=0
CLOVER_ESP_MOUNT_DEVICE=""
clover_find_unmounted_esp || fail "没有从未挂载 FAT 分区找到实际 EFI"
[ "$CLOVER_ESP_FOUND" = "$UNMOUNTED_ESP" ] || fail "未挂载 EFI 兜底路径选择错误"
[ "$CLOVER_ESP_MOUNTED_BY_TOOLBOX" = '1' ] || fail "未记录未挂载 EFI 的临时挂载状态"
clover_release_esp_mount
grep -Fq 'unmount --block-device /dev/unmountedesp' "$CALLS" || fail "未挂载 EFI 检查后没有释放挂载"

# Fedora/Bazzite 常以 root-only 权限挂载 /boot/efi。模拟普通用户无法 stat
# 子目录、但 sudo test 可以只读确认 EFI 内容的场景。
PROTECTED_ESP="$TMP_ROOT/protected-esp"
toolbox_sudo() {
    if [ "${1:-}" = "test" ]; then
        case "${2:-}:${3:-}" in
            "-d:$PROTECTED_ESP/EFI"|\
            "-f:$PROTECTED_ESP/EFI/CLOVER/CLOVERX64.efi") return 0 ;;
        esac
    fi
    "$@"
}
clover_candidate_is_esp "$PROTECTED_ESP" || \
    fail "root-only 的 Bazzite EFI 被误判为不含 EFI 目录"

echo "PASS: 可识别 root-only EFI，并从 NVRAM 反查、临时挂载和释放 EFI"
