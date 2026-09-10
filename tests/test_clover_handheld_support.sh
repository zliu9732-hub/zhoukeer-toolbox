#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/clover_boot.sh"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$MODULE"

toolbox_sudo() {
    "$@"
}

detect_platform() {
    IS_STEAMOS=1
    IS_BAZZITE=0
}

DMI="$TMP_ROOT/dmi"
mkdir -p "$DMI"
CLOVER_DMI_ROOT="$DMI"

assert_device() {
    local board="$1" product="$2" expected_prefix="$3" expected_driver="$4"
    local expected_resolution="${5:-}"

    printf '%s\n' "$board" > "$DMI/board_name"
    printf '%s\n' "$product" > "$DMI/product_name"
    clover_detect_device || fail "设备识别失败：$board / $product"
    [ "$CLOVER_DEVICE_PREFIX" = "$expected_prefix" ] || \
        fail "设备配置映射错误：$board / $product -> $CLOVER_DEVICE_PREFIX"
    [ "$CLOVER_EFI_DRIVER" = "$expected_driver" ] || \
        fail "手柄驱动映射错误：$board / $product -> $CLOVER_EFI_DRIVER"
    [ "$CLOVER_SCREEN_RESOLUTION" = "$expected_resolution" ] || \
        fail "开机菜单分辨率映射错误：$board / $product -> $CLOVER_SCREEN_RESOLUTION"
    if [ -n "$expected_driver" ]; then
        [ "$CLOVER_EFI_DRIVER_SHA256" = "$CLOVER_CONTROLLER_DRIVER_SHA256" ] || \
            fail "设备未绑定固定的手柄驱动 SHA256：$board / $product"
    fi
}

assert_device RC71L 'ROG Ally' ROG-Ally UsbXbox360Dxe.efi
assert_device RC72LA 'ROG Ally X' ROG-Ally UsbXbox360Dxe.efi
assert_device RC73XA 'ROG Xbox Ally X' ROG-Xbox-Ally UsbXbox360Dxe.efi 1920x1080
assert_device RC73YA 'ROG Xbox Ally' ROG-Xbox-Ally UsbXbox360Dxe.efi 1920x1080
assert_device LENOVO 83E1 Legion-Go UsbXbox360Dxe.efi 2560x1600
assert_device LENOVO 83N0 Legion-Go UsbXbox360Dxe.efi 1920x1200
assert_device LENOVO 83N1 Legion-Go UsbXbox360Dxe.efi 1920x1200
assert_device LENOVO 83N6 Legion-Go UsbXbox360Dxe.efi 1920x1200
assert_device Jupiter 'Steam Deck LCD' SD ''
assert_device Galileo 'Steam Deck OLED' SD ''

CLOVER_DRIVER_DIR="$PROJECT_ROOT/assets/clover/drivers"
CLOVER_EFI_DRIVER="$CLOVER_CONTROLLER_DRIVER"
CLOVER_EFI_DRIVER_SHA256="$CLOVER_CONTROLLER_DRIVER_SHA256"
clover_validate_efi_driver || fail "上游 UsbXbox360Dxe 驱动未通过固定校验"
[ "$(wc -c < "$CLOVER_DRIVER_DIR/$CLOVER_EFI_DRIVER" | tr -d '[:space:]')" = '52032' ] || \
    fail "UsbXbox360Dxe 驱动大小与发布文件不一致"

BAD_DRIVER_DIR="$TMP_ROOT/bad-driver"
mkdir -p "$BAD_DRIVER_DIR"
printf 'MZcorrupted-driver\n' > "$BAD_DRIVER_DIR/$CLOVER_EFI_DRIVER"
CLOVER_DRIVER_DIR="$BAD_DRIVER_DIR"
if clover_validate_efi_driver >"$TMP_ROOT/bad-driver.output" 2>&1; then
    fail "损坏的 UEFI 手柄驱动仍通过安装前校验"
fi
grep -Eq '大小异常|SHA256 校验失败' "$TMP_ROOT/bad-driver.output" || \
    fail "损坏驱动没有输出具体校验原因"

CONFIG="$TMP_ROOT/config.plist"
cp -- "$PROJECT_ROOT/assets/clover/devices/ROG-Xbox-Ally-config.plist" "$CONFIG"
clover_configure_steamos_loader_path "$CONFIG" '\EFI\steamos\grubx64.efi' || \
    fail "无法把设备配置切换到 SteamOS grub 启动器"
grep -Fq '<string>\EFI\steamos\grubx64.efi</string>' "$CONFIG" || \
    fail "SteamOS grub 启动路径没有写入 Clover 配置"
if grep -Fiq 'steamcl.efi' "$CONFIG"; then
    fail "切换 SteamOS 启动器后仍残留 steamcl.efi"
fi

BOOTCTL_ESP="$TMP_ROOT/bootctl-esp"
mkdir -p "$BOOTCTL_ESP/EFI/vendor"
findmnt() {
    case " $* " in
        *" -T $BOOTCTL_ESP -o SOURCE,FSTYPE "*) printf '/dev/fakeesp vfat\n' ;;
        *) return 1 ;;
    esac
}
clover_bootctl_candidate_is_esp "$BOOTCTL_ESP" || \
    fail "bootctl 明确报告的新款掌机 FAT EFI 未被接受"

CURRENT_GUID='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
efibootmgr() {
    printf 'BootCurrent: 000A\n'
    printf 'Boot000A* SteamOS HD(1,GPT,%s,0x800,0x100000)/File(\\EFI\\vendor\\unknownx64.efi)\n' \
        "$CURRENT_GUID"
}
[ "$(clover_nvram_partuuid)" = "$CURRENT_GUID" ] || \
    fail "未知 SteamOS 启动器未从 BootCurrent 安全反查 EFI PARTUUID"

GRUB_ESP="$TMP_ROOT/grub-esp"
mkdir -p "$GRUB_ESP/EFI/steamos"
printf 'grub\n' > "$GRUB_ESP/EFI/steamos/grubx64.efi"
clover_candidate_is_esp "$GRUB_ESP" || fail "SteamOS grub EFI 布局未被识别"
CLOVER_ESP="$GRUB_ESP"
[ "$(clover_linux_loader_path)" = '\EFI\steamos\grubx64.efi' ] || \
    fail "SteamOS grub EFI 启动路径识别错误"

echo "PASS: ROG Xbox Ally/Ally X、ROG Ally、Legion Go/Go 2/Go S 驱动映射与新 EFI 布局测试通过"
