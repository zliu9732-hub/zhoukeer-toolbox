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

mkdir -p "$MOUNT_PATH" "$STATE" "$TMP_ROOT/home/Desktop" "$TMP_ROOT/logs" \
    "$TMP_ROOT/esp/EFI/CLOVER" "$TMP_ROOT/esp/EFI/Microsoft/Boot" "$TMP_ROOT/esp/EFI/steamos"
printf 'windows\n' > "$TMP_ROOT/esp/EFI/Microsoft/Boot/bootmgfw.efi"
printf 'steamos\n' > "$TMP_ROOT/esp/EFI/steamos/steamcl.efi"
printf 'clover\n' > "$TMP_ROOT/esp/EFI/CLOVER/CLOVERX64.efi"
printf '0000,0001\n' > "$STATE/bootorder"

# shellcheck disable=SC1090
source "$MODULE"

HOME="$TMP_ROOT/home"
LOG_DIR="$TMP_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
TF_CARD_LINK="$HOME/双系统TF卡"
WINDOWS_SWITCH_DIR="$HOME/.local/share/zhoukeer-toolbox"
WINDOWS_SWITCH_LAUNCHER="$WINDOWS_SWITCH_DIR/windows-next.sh"
WINDOWS_LEGACY_SWITCH_LAUNCHER="$WINDOWS_SWITCH_DIR/windows/windows-next.sh"
WINDOWS_SWITCH_DESKTOP="$HOME/Desktop/一键切换Windows.desktop"
ZHOUKEER_TF_CARD_DEVICE="/dev/testtf"

require_steamos() { return 0; }
require_command() { return 0; }
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
toolbox_sudo() { "$@"; }
tf_card_confirm_format() { return 0; }
repair_drive_confirm() { return 0; }

lsblk() {
    case " $* " in
        *' -dnro TYPE /dev/testtf '*) printf 'disk\n' ;;
        *' -dnro SIZE /dev/testtf '*) printf '512G\n' ;;
        *' -dnro MODEL /dev/testtf '*) printf 'Test TF Card\n' ;;
        *' PKNAME /dev/systemp1 '*) printf 'system\n' ;;
        *' PKNAME /dev/fakep1 '*) printf '/dev/fake\n' ;;
        *' PARTN /dev/fakep1 '*) printf '1\n' ;;
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
    local target="" source="" field="" positional=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -T) target="$2"; shift 2 ;;
            -S) source="$2"; shift 2 ;;
            -o) field="$2"; shift 2 ;;
            -*) shift ;;
            *) positional="$1"; shift ;;
        esac
    done
    if [ "$positional" = "/" ] && [ "$field" = "SOURCE" ]; then
        printf '/dev/systemp1\n'
        return 0
    fi
    if [ -n "$source" ]; then
        [ "$source" = "/dev/testshare" ] || return 1
        case "$field" in
            TARGET|'') printf '%s\n' "$MOUNT_PATH" ;;
            *) return 1 ;;
        esac
        return 0
    fi
    case "$target" in
        "$TMP_ROOT/esp") [ "$field" = "SOURCE" ] && printf '/dev/fakep1\n' || return 1 ;;
        "$MOUNT_PATH")
            case "$field" in
                TARGET) printf '%s\n' "$MOUNT_PATH" ;;
                FSTYPE) printf 'ntfs3\n' ;;
                OPTIONS) [ -f "$STATE/readonly" ] && printf 'ro,nosuid\n' || printf 'rw,nosuid\n' ;;
                SOURCE) printf '/dev/testshare\n' ;;
                UUID) printf 'TEST-UUID\n' ;;
                *) return 1 ;;
            esac
            ;;
        "$HOME"|"$HOME"/*)
            case "$field" in
                TARGET) printf '%s\n' "$TMP_ROOT" ;;
                FSTYPE) printf 'ext4\n' ;;
                OPTIONS) printf 'rw,relatime\n' ;;
                SOURCE) printf '/dev/testhome\n' ;;
                UUID) printf 'HOME-UUID\n' ;;
                *) return 1 ;;
            esac
            ;;
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
mkfs.ntfs() { printf 'mkfs.ntfs %s\n' "$*" >> "$CALLS"; }

efibootmgr() {
    local order next omit windows_label label loader count boot_num
    order="$(cat "$STATE/bootorder" 2>/dev/null || printf '0000,0001\n')"
    next="$(cat "$STATE/bootnext" 2>/dev/null || true)"
    omit="$(cat "$STATE/omit" 2>/dev/null || true)"
    windows_label="$(cat "$STATE/windows-label" 2>/dev/null || printf 'Windows Boot Manager')"
    case "${1:-}" in
        --delete-bootnum) printf 'delete %s\n' "$3" >> "$CALLS" ;;
        --bootnext)
            printf '%s\n' "$2" > "$STATE/bootnext"
            printf 'bootnext %s\n' "$2" >> "$CALLS"
            ;;
        --bootorder)
            printf '%s\n' "$2" > "$STATE/bootorder"
            printf 'bootorder %s\n' "$2" >> "$CALLS"
            ;;
        --create)
            label=""
            loader=""
            while [ "$#" -gt 0 ]; do
                case "$1" in
                    --label) label="$2"; shift 2 ;;
                    --loader) loader="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            count="$(wc -l < "$STATE/created-entries" 2>/dev/null || printf '0\n')"
            count="$(printf '%s' "$count" | tr -d ' ')"
            boot_num=$((7 + count))
            printf 'Boot%04X* %s HD(1,GPT,AAA)/File(%s)\n' \
                "$boot_num" "$label" "$loader" >> "$STATE/created-entries"
            printf 'create %s\n' "$label" >> "$CALLS"
            cat "$STATE/created-entries"
            ;;
        *)
            [ -z "$next" ] || printf 'BootNext: %s\n' "$next"
            printf 'BootOrder: %s\n' "$order"
            if [ -n "$omit" ]; then
                {
                    printf 'Boot0000* SteamOS HD(1,GPT,AAA)/File(\\EFI\\steamos\\steamcl.efi)\n'
                    printf 'Boot0001* %s HD(1,GPT,AAA)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n' "$windows_label"
                    printf 'Boot0002* Zhoukeer Clover HD(1,GPT,AAA)/File(\\EFI\\CLOVER\\CLOVERX64.efi)\n'
                    printf 'Boot0003* rEFInd Boot Manager HD(1,GPT,AAA)/File(\\EFI\\refind\\refind_x64.efi)\n'
                    printf 'Boot0004* OpenCore HD(1,GPT,AAA)/File(\\EFI\\OC\\OpenCore.efi)\n'
                    printf 'Boot0005* GRUB HD(1,GPT,AAA)/File(\\EFI\\ubuntu\\grubx64.efi)\n'
                    printf 'Boot0006* Linux Boot Manager HD(1,GPT,AAA)/File(\\EFI\\systemd\\systemd-bootx64.efi)\n'
                } | grep -Ev -- "$omit"
            else
                printf 'Boot0000* SteamOS HD(1,GPT,AAA)/File(\\EFI\\steamos\\steamcl.efi)\n'
                printf 'Boot0001* %s HD(1,GPT,AAA)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n' "$windows_label"
                printf 'Boot0002* Zhoukeer Clover HD(1,GPT,AAA)/File(\\EFI\\CLOVER\\CLOVERX64.efi)\n'
                printf 'Boot0003* rEFInd Boot Manager HD(1,GPT,AAA)/File(\\EFI\\refind\\refind_x64.efi)\n'
                printf 'Boot0004* OpenCore HD(1,GPT,AAA)/File(\\EFI\\OC\\OpenCore.efi)\n'
                printf 'Boot0005* GRUB HD(1,GPT,AAA)/File(\\EFI\\ubuntu\\grubx64.efi)\n'
                printf 'Boot0006* Linux Boot Manager HD(1,GPT,AAA)/File(\\EFI\\systemd\\systemd-bootx64.efi)\n'
            fi
            [ ! -f "$STATE/created-entries" ] || cat "$STATE/created-entries"
            ;;
    esac
}

format_and_mount_tf_card >/dev/null || fail "TF 卡初始化模拟失败"
grep -Fq 'wipefs --all --force /dev/testtf' "$CALLS" || fail "TF 卡未清理旧分区签名"
grep -Fq 'mkfs.ntfs -f -L TFcard /dev/testtf1' "$CALLS" || fail "TF 卡未格式化为 NTFS"
[ -L "$TF_CARD_LINK" ] || fail "TF 卡未创建快捷入口"

repair_boot_confirm() { return 0; }
switch_windows_confirm() { return 0; }
systemctl() { printf 'systemctl %s\n' "$*" >> "$CALLS"; }
reboot() { printf 'reboot %s\n' "$*" >> "$CALLS"; }

mkdir -p "$MOUNT_PATH/steamapps/compatdata/123" \
    "$MOUNT_PATH/steamapps/downloading/unfinished" \
    "$MOUNT_PATH/steamapps/temp/stale" \
    "$MOUNT_PATH/steamapps/common/InstalledGame"
printf 'prefix\n' > "$MOUNT_PATH/steamapps/compatdata/123/prefix.txt"
printf 'partial\n' > "$MOUNT_PATH/steamapps/downloading/unfinished/data.bin"
printf 'temp\n' > "$MOUNT_PATH/steamapps/temp/stale/data.tmp"
printf 'game\n' > "$MOUNT_PATH/steamapps/common/InstalledGame/game.bin"
printf 'lock\n' > "$MOUNT_PATH/steamapps/content.lock"
ZHOUKEER_STEAM_LIBRARY="$MOUNT_PATH"
ZHOUKEER_COMPATDATA_ROOT="$HOME/.local/share/Steam/renkit-compatdata"
ZHOUKEER_SKIP_STEAM_RESTART=1
repair_output="$(repair_shared_drive)" || fail "NTFS 写入错误修复模拟失败"
printf '%s\n' "$repair_output" | grep -Fq 'Steam 磁盘写入错误修复完成' || fail "修复未输出成功结果"
[ -L "$MOUNT_PATH/steamapps/compatdata" ] || fail "compatdata 未改为 Linux 文件系统符号链接"
compat_target="$(readlink -f "$MOUNT_PATH/steamapps/compatdata")"
case "$compat_target" in
    "$ZHOUKEER_COMPATDATA_ROOT"/uuid-test-uuid-path-*) ;;
    *) fail "compatdata 没有使用 UUID 与库路径生成独立目标：$compat_target" ;;
esac
[ -f "$MOUNT_PATH/steamapps/compatdata.backup-"*/123/prefix.txt ] || fail "原 compatdata 未按时间戳备份"
[ -f "$MOUNT_PATH/steamapps/common/InstalledGame/game.bin" ] || fail "修复误删了已安装游戏"
[ -d "$MOUNT_PATH/steamapps/downloading" ] && \
    [ -z "$(find "$MOUNT_PATH/steamapps/downloading" -mindepth 1 -print -quit)" ] || fail "下载残留未清理"
[ -d "$MOUNT_PATH/steamapps/temp" ] && \
    [ -z "$(find "$MOUNT_PATH/steamapps/temp" -mindepth 1 -print -quit)" ] || fail "临时残留未清理"
[ ! -e "$MOUNT_PATH/steamapps/content.lock" ] || fail "Steam 锁文件残留未清理"
backup_count="$(find "$MOUNT_PATH/steamapps" -maxdepth 1 -type d -name 'compatdata.backup-*' | wc -l)"
repair_shared_drive >/dev/null || fail "重复运行修复失败"
[ "$(find "$MOUNT_PATH/steamapps" -maxdepth 1 -type d -name 'compatdata.backup-*' | wc -l)" = "$backup_count" ] || \
    fail "重复运行错误地再次备份 compatdata"

printf 'keep\n' > "$MOUNT_PATH/steamapps/downloading/keep.bin"
: > "$STATE/readonly"
if repair_shared_drive > "$TMP_ROOT/readonly.output" 2>&1; then
    fail "只读 NTFS 库仍继续执行修复"
fi
grep -Fq 'powercfg -h off' "$TMP_ROOT/readonly.output" || fail "只读提示缺少 powercfg 指令"
grep -Fq 'chkdsk X: /f' "$TMP_ROOT/readonly.output" || fail "只读提示缺少 chkdsk 指令"
if grep -Fq '修复完成' "$TMP_ROOT/readonly.output"; then
    fail "只读失败时错误显示修复成功"
fi
[ -f "$MOUNT_PATH/steamapps/downloading/keep.bin" ] || fail "只读检查后仍修改了下载目录"
rm -f "$STATE/readonly"

ZHOUKEER_TF_CARD_DEVICE="/not-a-device"
if find_tf_card_device >"$TMP_ROOT/tf-diagnostic.output" 2>&1; then
    fail "不安全的 TF 卡设备路径未被拒绝"
fi
grep -Fq '指定的 TF 卡设备路径不安全' "$TMP_ROOT/tf-diagnostic.output" || \
    fail "TF 卡设备识别失败没有输出具体原因"
unset ZHOUKEER_TF_CARD_DEVICE

mkdir -p "$WINDOWS_SWITCH_DIR/windows"
printf 'legacy\n' > "$WINDOWS_SWITCH_LAUNCHER"
printf 'legacy\n' > "$WINDOWS_LEGACY_SWITCH_LAUNCHER"
printf 'legacy\n' > "$WINDOWS_SWITCH_DESKTOP"
retire_windows_switch_shortcuts >/dev/null || fail "旧 Windows 切换入口清理失败"
for removed_path in "$WINDOWS_SWITCH_LAUNCHER" "$WINDOWS_LEGACY_SWITCH_LAUNCHER" "$WINDOWS_SWITCH_DESKTOP"; do
    [ ! -e "$removed_path" ] && [ ! -L "$removed_path" ] || fail "旧 Windows 切换入口未清理：$removed_path"
done

create_windows_switch_shortcut >/dev/null || fail "Windows 桌面快捷方式创建失败"
[ -x "$WINDOWS_SWITCH_LAUNCHER" ] || fail "Windows 切换脚本未创建或不可执行"
[ -x "$WINDOWS_SWITCH_DESKTOP" ] || fail "Windows 桌面快捷方式未创建或不可执行"
grep -Fq 'switch-to-windows' "$WINDOWS_SWITCH_LAUNCHER" || fail "桌面快捷方式没有绑定 Windows 切换动作"
if grep -Fq 'unset ZHOUKEER_AUTO_CONFIRM' "$WINDOWS_SWITCH_LAUNCHER"; then
    fail "桌面快捷方式仍要求二次确认"
fi
grep -Fq 'Terminal=true' "$WINDOWS_SWITCH_DESKTOP" || fail "桌面快捷方式无法显示二次确认终端"
[ ! -f "$STATE/bootnext" ] || fail "创建桌面快捷方式时错误设置了 BootNext"
if grep -Fq 'systemctl reboot' "$CALLS"; then
    fail "创建桌面快捷方式时错误触发了重启"
fi

find_boot_esp_for_health() { printf '%s\n' "$TMP_ROOT/esp"; }
health_output="$(dual_boot_health_check)" || fail "双系统健康检查失败"
for expected in 'Windows（受保护）' 'SteamOS（受保护）' 'Renkit Clover' 'rEFInd' 'OpenCore' 'GRUB' 'systemd-boot（仅检查）'; do
    printf '%s\n' "$health_output" | grep -Fq "$expected" || fail "健康检查缺少：$expected"
done

ZHOUKEER_BOOT_ENTRY=0003
printf 'DELETE BOOT0003\n' | cleanup_third_party_boot_entry >/dev/null || fail "rEFInd NVRAM 清理模拟失败"
grep -Fq 'delete 0003' "$CALLS" || fail "未删除选定的 rEFInd NVRAM 项"

ZHOUKEER_BOOT_ENTRY=0001
if cleanup_third_party_boot_entry </dev/null >/dev/null 2>&1; then
    fail "Windows Boot Manager 未受到删除保护"
fi

printf 'Windows Boot Manager|Zhoukeer Clover\n' > "$STATE/omit"
rm -f "$STATE/created-entries" "$STATE/bootnext"
printf '0000,0001\n' > "$STATE/bootorder"
repair_dual_boot >/dev/null || fail "双系统引导修复模拟失败"
grep -Fq 'create Windows Boot Manager' "$CALLS" || fail "未创建 Windows 引导项"
grep -Fq 'create Zhoukeer Clover' "$CALLS" || fail "未创建 Clover 引导项"
grep -Eq 'bootorder 0007,0000,0001|bootorder 0008,0000,0001' "$CALLS" || \
    fail "Clover 未放回 BootOrder 首位"

printf '0000,0001\n' > "$STATE/bootorder"
rm -f "$STATE/omit" "$STATE/created-entries" "$STATE/bootnext"
switch_to_windows >/dev/null || fail "Windows 一键切换模拟失败"
grep -Fq 'bootnext 0001' "$CALLS" || fail "未设置 BootNext"
grep -Fq 'systemctl reboot' "$CALLS" || fail "未触发系统重启"

printf 'Microsoft Boot Option\n' > "$STATE/windows-label"
rm -f "$STATE/bootnext"
switch_to_windows >/dev/null || fail "固件重命名 Windows 标签后仍应按官方 EFI 路径切换"
grep -Fq 'bootnext 0001' "$CALLS" || fail "固件重命名 Windows 标签后未设置 BootNext"
rm -f "$STATE/windows-label"

printf 'Windows Boot Manager\n' > "$STATE/omit"
rm -f "$STATE/created-entries" "$STATE/bootnext"
if switch_to_windows >/dev/null 2>&1; then
    fail "缺少 Windows Boot Manager 时仍允许一键切换"
fi

echo "PASS: TF 卡、磁盘修复、引导修复、Windows 切换、健康检查和第三方引导清理模拟通过"
