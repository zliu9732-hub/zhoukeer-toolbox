#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/dual_system_tools.sh"
TMP_ROOT="$(mktemp -d)"
MOUNT_PATH="$TMP_ROOT/mount"
STATE="$TMP_ROOT/state"
CALLS="$TMP_ROOT/commands.log"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$MOUNT_PATH" "$STATE" "$TMP_ROOT/home/Desktop" "$TMP_ROOT/logs" "$TMP_ROOT/esp/EFI/CLOVER"

# shellcheck disable=SC1090
source "$MODULE"

HOME="$TMP_ROOT/home"
LOG_DIR="$TMP_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
TF_CARD_LINK="$HOME/双系统TF卡"
WINDOWS_SWITCH_DIR="$HOME/.local/share/zhoukeer-toolbox"
WINDOWS_SWITCH_LAUNCHER="$WINDOWS_SWITCH_DIR/windows-next.sh"
WINDOWS_SWITCH_DESKTOP="$HOME/Desktop/一键切换Windows.desktop"
ZHOUKEER_TF_CARD_DEVICE="/dev/testtf"

require_steamos() { return 0; }
require_command() { return 0; }
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
toolbox_sudo() { "$@"; }
tf_card_confirm_format() { return 0; }
repair_drive_confirm() { return 0; }
confirm_windows_reboot() { return 0; }

lsblk() {
    case " $* " in
        *' -dnro TYPE /dev/testtf '*) printf 'disk\n' ;;
        *' -dnro SIZE /dev/testtf '*) printf '512G\n' ;;
        *' -dnro MODEL /dev/testtf '*) printf 'Test TF Card\n' ;;
        *' PKNAME /dev/systemp1 '*) printf 'system\n' ;;
        *' NAME,TYPE /dev/testtf '*)
            printf '/dev/testtf disk\n'
            [ ! -f "$STATE/partitioned" ] || printf '/dev/testtf1 part\n'
            ;;
        *' FSTYPE /dev/testshare '*) printf 'ntfs\n' ;;
        *' NAME,FSTYPE,MOUNTPOINT,RO '*) printf '/dev/testshare ntfs %s 0\n' "$MOUNT_PATH" ;;
        *) return 1 ;;
    esac
}

findmnt() {
    case " $* " in
        *' -o SOURCE / '*) printf '/dev/systemp1\n' ;;
        *' -S /dev/testshare '*) printf '%s\n' "$MOUNT_PATH" ;;
        *) return 1 ;;
    esac
}

udisksctl() {
    printf 'udisksctl %s\n' "$*" >> "$CALLS"
    case "${1:-}" in
        mount) printf 'Mounted %s at %s.\n' "$3" "$MOUNT_PATH" ;;
        unmount) return 0 ;;
        *) return 1 ;;
    esac
}

wipefs() { printf 'wipefs %s\n' "$*" >> "$CALLS"; }
parted() { printf 'parted %s\n' "$*" >> "$CALLS"; : > "$STATE/partitioned"; }
partprobe() { printf 'partprobe %s\n' "$*" >> "$CALLS"; }
udevadm() { printf 'udevadm %s\n' "$*" >> "$CALLS"; }
mkfs.exfat() { printf 'mkfs.exfat %s\n' "$*" >> "$CALLS"; }
ntfsfix() { printf 'ntfsfix %s\n' "$*" >> "$CALLS"; }
systemctl() { printf 'systemctl %s\n' "$*" >> "$CALLS"; }

efibootmgr() {
    case "${1:-}" in
        --bootnext) printf 'bootnext %s\n' "$2" >> "$CALLS" ;;
        --delete-bootnum) printf 'delete %s\n' "$3" >> "$CALLS" ;;
        *)
            cat <<'EOF'
Boot0000* SteamOS HD(1,GPT,AAA)/File(\EFI\steamos\steamcl.efi)
Boot0001* Windows Boot Manager HD(1,GPT,AAA)/File(\EFI\Microsoft\Boot\bootmgfw.efi)
Boot0002* Zhoukeer Clover HD(1,GPT,AAA)/File(\EFI\CLOVER\CLOVERX64.efi)
Boot0003* rEFInd Boot Manager HD(1,GPT,AAA)/File(\EFI\refind\refind_x64.efi)
Boot0004* OpenCore HD(1,GPT,AAA)/File(\EFI\OC\OpenCore.efi)
Boot0005* GRUB HD(1,GPT,AAA)/File(\EFI\ubuntu\grubx64.efi)
Boot0006* Linux Boot Manager HD(1,GPT,AAA)/File(\EFI\systemd\systemd-bootx64.efi)
EOF
            ;;
    esac
}

format_and_mount_tf_card >/dev/null || fail "TF 卡初始化模拟失败"
grep -Fq 'wipefs --all --force /dev/testtf' "$CALLS" || fail "TF 卡未清理旧分区签名"
grep -Fq 'mkfs.exfat -n ZHOUKEER_TF /dev/testtf1' "$CALLS" || fail "TF 卡未格式化为 exFAT"
[ -L "$TF_CARD_LINK" ] || fail "TF 卡未创建快捷入口"

find_shared_drive_device() { printf '/dev/testshare\n'; }
shared_drive_mountpoint() { printf '%s\n' "$MOUNT_PATH"; }
mount_shared_drive_device() { printf '%s\n' "$MOUNT_PATH"; }
create_shared_drive_shortcut() { return 0; }
repair_shared_drive >/dev/null || fail "NTFS 写入错误修复模拟失败"
grep -Fq 'ntfsfix /dev/testshare' "$CALLS" || fail "NTFS 修复未调用 ntfsfix"

create_windows_switch_shortcut >/dev/null || fail "Windows 快捷方式创建失败"
[ -x "$WINDOWS_SWITCH_LAUNCHER" ] || fail "Windows 切换启动器不可执行"
[ -x "$WINDOWS_SWITCH_DESKTOP" ] || fail "Windows 桌面图标不可执行"
grep -Fq 'dual_system_tools.sh' "$WINDOWS_SWITCH_LAUNCHER" || fail "Windows 启动器调用目标错误"
if grep -Eq 'bash -c|sh -c|eval' "$WINDOWS_SWITCH_LAUNCHER"; then
    fail "Windows 启动器使用动态命令执行"
fi

boot_windows_once >/dev/null || fail "Windows BootNext 模拟失败"
grep -Fq 'bootnext 0001' "$CALLS" || fail "未将 Windows 设为 BootNext"
grep -Fq 'systemctl reboot' "$CALLS" || fail "设置 BootNext 后未请求重启"

find_boot_esp_for_health() { printf '%s\n' "$TMP_ROOT/esp"; }
health_output="$(dual_boot_health_check)" || fail "双系统健康检查失败"
for expected in 'Windows（受保护）' 'SteamOS（受保护）' '工具箱 Clover' 'rEFInd' 'OpenCore' 'GRUB' 'systemd-boot（仅检查）'; do
    printf '%s\n' "$health_output" | grep -Fq "$expected" || fail "健康检查缺少：$expected"
done

ZHOUKEER_BOOT_ENTRY=0003
printf 'DELETE BOOT0003\n' | cleanup_third_party_boot_entry >/dev/null || fail "rEFInd NVRAM 清理模拟失败"
grep -Fq 'delete 0003' "$CALLS" || fail "未删除选定的 rEFInd NVRAM 项"

ZHOUKEER_BOOT_ENTRY=0001
if cleanup_third_party_boot_entry </dev/null >/dev/null 2>&1; then
    fail "Windows Boot Manager 未受到删除保护"
fi

echo "PASS: TF 卡、磁盘修复、Windows 切换、健康检查和第三方引导清理模拟通过"
