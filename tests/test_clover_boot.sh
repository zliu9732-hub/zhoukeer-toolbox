#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/clover_boot.sh"
TMP_ROOT="$(mktemp -d)"
ESP="$TMP_ROOT/esp"
FIXTURE_ROOT="$TMP_ROOT/fixture"
FIXTURE="$TMP_ROOT/Clover.tar.gz"
STATE="$TMP_ROOT/state"
SYSTEM_DIR="$TMP_ROOT/system"
WHITELIST_DIR="$TMP_ROOT/whitelist"

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p \
    "$ESP/EFI/steamos" \
    "$ESP/EFI/Microsoft/Boot" \
    "$ESP/EFI/BOOT" \
    "$ESP/EFI/CLOVER" \
    "$FIXTURE_ROOT/Clover/clover" \
    "$FIXTURE_ROOT/Clover/custom" \
    "$STATE"
printf 'steam\n' > "$ESP/EFI/steamos/steamcl.efi"
printf 'windows\n' > "$ESP/EFI/Microsoft/Boot/bootmgfw.efi"
printf 'fallback-sentinel\n' > "$ESP/EFI/BOOT/BOOTX64.EFI"
printf 'original-clover\n' > "$ESP/EFI/CLOVER/original.txt"
printf 'clover-binary\n' > "$FIXTURE_ROOT/Clover/clover/cloverx64.efi"
cp -- "$PROJECT_ROOT/assets/clover/devices/SD-config.plist" \
    "$FIXTURE_ROOT/Clover/custom/SD-config.plist"
(
    cd "$FIXTURE_ROOT"
    tar -czf "$FIXTURE" Clover
)

printf '0000,0001\n' > "$STATE/bootorder"
printf '0\n' > "$STATE/clover-entry"

# shellcheck disable=SC1090
source "$MODULE"

CLOVER_BOOTMANAGER_SYSTEM_DIR="$SYSTEM_DIR"
CLOVER_BOOTMANAGER_WHITELIST_DIR="$WHITELIST_DIR"
require_steamos() { return 0; }
require_command() { return 0; }
log() { :; }
toolbox_sudo() {
    "$@"
}
clover_resolve_esp_device() {
    CLOVER_ESP="$ESP"
    CLOVER_ESP_SOURCE="/dev/fakep1"
    CLOVER_DISK="/dev/fake"
    CLOVER_PARTITION="1"
}
clover_confirm_install() { return 0; }
clover_confirm_restore() { return 0; }
clover_detect_device() {
    CLOVER_DEVICE_PREFIX="SD"
    CLOVER_DEVICE_NAME="Steam Deck Test"
    CLOVER_EFI_DRIVER=""
    CLOVER_DEVICE_CONFIG="$PROJECT_ROOT/assets/clover/devices/SD-config.plist"
}
clover_choose_default_os() { printf '%s\n' "SteamOS"; }
download_gitee_mirror_file() {
    cp -- "$FIXTURE" "$2"
}
systemctl() {
    printf 'systemctl %s\n' "$*" >> "$STATE/calls"
}
ZHOUKEER_CLOVER_SKIP_BOOTMANAGER_RUN=1

efibootmgr() {
    local order
    order="$(cat "$STATE/bootorder")"
    case "${1:-}" in
        --create)
            printf '1\n' > "$STATE/clover-entry"
            printf 'Boot0002* Zhoukeer Clover\n'
            ;;
        --bootorder)
            printf '%s\n' "$2" > "$STATE/bootorder"
            ;;
        --delete-bootnum)
            printf '0\n' > "$STATE/clover-entry"
            ;;
        -v)
            printf 'BootCurrent: 0000\nBootOrder: %s\n' "$order"
            printf 'Boot0000* SteamOS HD(1,GPT,TEST)/File(\\EFI\\steamos\\steamcl.efi)\n'
            printf 'Boot0001* Windows Boot Manager HD(1,GPT,TEST)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n'
            if [ "$(cat "$STATE/clover-entry")" = "1" ]; then
                printf 'Boot0002* Zhoukeer Clover HD(1,GPT,TEST)/File(\\EFI\\CLOVER\\CLOVERX64.efi)\n'
            fi
            ;;
        *)
            printf 'BootCurrent: 0000\nBootOrder: %s\n' "$order"
            ;;
    esac
}

clover_install >/dev/null || fail "模拟 Clover 安装失败"
[ -s "$ESP/EFI/CLOVER/CLOVERX64.efi" ] || fail "未写入 Clover EFI 文件"
[ -f "$ESP/EFI/CLOVER/.zhoukeer-managed" ] || fail "未写入工具箱管理标记"
[ -f "$ESP/EFI/CLOVER/themes/zhoukeer-phantom/background.png" ] || fail "未写入怪盗主题背景"
cmp -s "$PROJECT_ROOT/assets/clover/zhoukeer-phantom/background.png" \
    "$ESP/EFI/CLOVER/themes/zhoukeer-phantom/background.png" || fail "开机背景与项目资源不一致"
grep -Fq 'steamcl.efi' "$ESP/EFI/CLOVER/config.plist" || \
    fail "SteamOS 不是默认启动器"
grep -Fq 'zhoukeer-phantom' "$ESP/EFI/CLOVER/config.plist" || \
    fail "设备配置未指向工具箱主题"
[ "$(cat "$STATE/bootorder")" = '0002,0000,0001' ] || fail "Clover 未放到 BootOrder 首位"
[ "$(cat "$ESP/EFI/BOOT/BOOTX64.EFI")" = 'fallback-sentinel' ] || fail "安装覆盖了 BOOTX64.EFI"
[ ! -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi" ] || fail "Windows 直启未禁用"
[ -f "$ESP/EFI/Microsoft/bootmgfw.efi" ] || fail "Clover Windows 入口文件缺失"
[ -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi.zhoukeer-orig" ] || fail "Windows EFI 未备份"
[ -f "$SYSTEM_DIR/clover-bootmanager.service" ] || fail "开机修复服务未安装"
[ -f "$SYSTEM_DIR/clover-bootmanager.sh" ] || fail "开机修复脚本未安装"
[ -f "$WHITELIST_DIR/clover-whitelist.conf" ] || fail "开机修复白名单未安装"
grep -Fq 'enable --now clover-bootmanager.service' "$STATE/calls" || \
    fail "开机修复服务未启用"

status_output="$(clover_status)" || fail "安装后状态检查失败"
printf '%s\n' "$status_output" | grep -Fq 'Clover：已由工具箱安装' || fail "状态未报告 Clover 已安装"

clover_delete >/dev/null || fail "模拟删除工具箱 Clover 双系统引导失败"
[ -f "$ESP/EFI/CLOVER/original.txt" ] || fail "没有恢复安装前的 CLOVER 目录"
[ ! -e "$ESP/EFI/CLOVER/.zhoukeer-managed" ] || fail "恢复后仍使用工具箱 Clover"
[ "$(cat "$STATE/bootorder")" = '0000,0001' ] || fail "没有恢复原 BootOrder"
[ "$(cat "$STATE/clover-entry")" = '0' ] || fail "没有删除工具箱 Clover NVRAM 入口"
[ -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi" ] || fail "Windows 直启未恢复"
[ ! -e "$ESP/EFI/Microsoft/bootmgfw.efi" ] || fail "Clover Windows 入口未清理"

CLOVER_ESP="$ESP"
clover_backup_path_is_safe "$ESP/EFI/zhoukeer-backups/clover-before-20260722123045" || \
    fail "合法 Clover 备份路径被拒绝"
clover_backup_path_is_safe "$ESP/EFI/zhoukeer-backups/clover-before-20260722123045-1234" || \
    fail "带进程号的合法 Clover 备份路径被拒绝"
if clover_backup_path_is_safe "$TMP_ROOT/outside"; then
    fail "管理标记可指向 EFI 备份目录之外"
fi
clover_boot_order_is_safe '0000,00AF,0001' || fail "合法 BootOrder 被拒绝"
if clover_boot_order_is_safe '0000,../../tmp'; then
    fail "异常 BootOrder 标记未被拒绝"
fi

BAD_ROOT="$TMP_ROOT/bad"
BAD_ZIP="$TMP_ROOT/bad.tar.gz"
mkdir -p "$BAD_ROOT/Clover/clover" "$BAD_ROOT/Clover/custom"
printf 'binary\n' > "$BAD_ROOT/Clover/clover/cloverx64.efi"
printf '<plist/>\n' > "$BAD_ROOT/Clover/custom/SD-config.plist"
ln -s ../../outside "$BAD_ROOT/Clover/custom/unsafe-link"
(
    cd "$BAD_ROOT"
    tar -czf "$BAD_ZIP" Clover
)
if clover_archive_is_safe "$BAD_ZIP" >/dev/null 2>&1; then
    fail "包含符号链接的 Clover 压缩包未被拒绝"
fi
if clover_prepare_staging "$BAD_ZIP" "$TMP_ROOT/bad-stage" >"$TMP_ROOT/bad-stage-output" 2>&1; then
    fail "不安全 Clover 压缩包仍可进入准备阶段"
fi
grep -Fq '包含符号链接' "$TMP_ROOT/bad-stage-output" || \
    fail "Clover 安装包准备失败没有输出具体原因"

echo "PASS: Clover Gitee 镜像、设备配置、怪盗主题、Windows 直启禁用、BootOrder 和删除恢复模拟测试通过"
