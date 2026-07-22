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

echo "PASS: 可从现有 Clover NVRAM 启动项反查、临时挂载并释放 EFI"
