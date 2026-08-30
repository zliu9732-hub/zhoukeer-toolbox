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
# 模拟 1.2.7 已把 Windows 启动文件移走；1.2.8 重装必须自动恢复。
printf 'windows\n' > "$ESP/EFI/Microsoft/bootmgfw.efi"
printf 'windows\n' > "$ESP/EFI/Microsoft/Boot/bootmgfw.efi.zhoukeer-orig"
printf 'fallback-sentinel\n' > "$ESP/EFI/BOOT/BOOTX64.EFI"
printf 'original-clover\n' > "$ESP/EFI/CLOVER/original.txt"
mkdir -p "$ESP/EFI/CLOVER/themes/zhoukeer-phantom"
printf 'old-background\n' > "$ESP/EFI/CLOVER/themes/zhoukeer-phantom/background.png"
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

eval "$(declare -f clover_prepare_staging | \
    sed '1s/clover_prepare_staging/clover_prepare_staging_real/')"
clover_prepare_staging() {
    echo "tar: 忽略未知的扩展头关键字 LIBARCHIVE.xattr.com.apple.quarantine" >&2
    clover_prepare_staging_real "$@"
}

CLOVER_BOOTMANAGER_SYSTEM_DIR="$SYSTEM_DIR"
CLOVER_BOOTMANAGER_WHITELIST_DIR="$WHITELIST_DIR"
require_supported_gaming_os() { return 0; }
detect_platform() { IS_STEAMOS=1; IS_BAZZITE=0; }
require_command() { return 0; }
log() { :; }
toolbox_sudo() {
    "$@"
}
clover_prepare_admin_access() { return 0; }
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
cp() {
    local source="${@: -2:1}"
    local target="${@: -1}"
    if [ "$(basename "$source")" = "cloverx64.efi" ] && \
        [ "$(basename "$target")" = "CLOVERX64.efi" ]; then
        fail "Clover 准备阶段仍复制大小写冲突的 EFI 文件"
    fi
    command cp "$@"
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
if rg -n 'toolbox_sudo[[:space:]]+cp[[:space:]]+-a' "$MODULE" >/dev/null; then
    fail "Clover 仍使用 FAT32 不兼容的 cp -a 复制 EFI 文件"
fi
[ -s "$ESP/EFI/CLOVER/CLOVERX64.efi" ] || fail "未写入 Clover EFI 文件"
[ -f "$ESP/EFI/CLOVER/.zhoukeer-managed" ] || fail "未写入Renkit管理标记"
[ -f "$ESP/EFI/CLOVER/themes/zhoukeer-phantom/background.png" ] || fail "未写入怪盗主题背景"
cmp -s "$PROJECT_ROOT/assets/clover/zhoukeer-phantom/background.png" \
    "$ESP/EFI/CLOVER/themes/zhoukeer-phantom/background.png" || fail "开机背景与项目资源不一致"
if command -v sha256sum >/dev/null 2>&1; then
    background_sha="$(sha256sum "$ESP/EFI/CLOVER/themes/zhoukeer-phantom/background.png" | awk '{print $1}')"
else
    background_sha="$(shasum -a 256 "$ESP/EFI/CLOVER/themes/zhoukeer-phantom/background.png" | awk '{print $1}')"
fi
[ "$background_sha" = "83ad7be810be72fe79bfb1085e2738bf34f2b114f856e0f825525f8aed2634a4" ] || \
    fail "Clover 安装后仍保留旧版开机背景"
grep -Fq 'steamcl.efi' "$ESP/EFI/CLOVER/config.plist" || \
    fail "SteamOS 不是默认启动器"
grep -Fq 'zhoukeer-phantom' "$ESP/EFI/CLOVER/config.plist" || \
    fail "设备配置未指向Renkit主题"
if grep -Fq '<key>ScreenResolution</key>' "$ESP/EFI/CLOVER/config.plist"; then
    fail "SteamOS Clover 安装后仍写死屏幕分辨率"
fi
[ "$(cat "$STATE/bootorder")" = '0002,0000,0001' ] || fail "Clover 未放到 BootOrder 首位"
[ "$(cat "$ESP/EFI/BOOT/BOOTX64.EFI")" = 'fallback-sentinel' ] || fail "安装覆盖了 BOOTX64.EFI"
[ -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi" ] || fail "Windows 官方启动文件未恢复"
[ ! -e "$ESP/EFI/Microsoft/bootmgfw.efi" ] || fail "旧版 Windows 启动副本未清理"
[ ! -e "$ESP/EFI/Microsoft/Boot/bootmgfw.efi.zhoukeer-orig" ] || fail "旧版 Windows 启动备份未清理"
[ -f "$SYSTEM_DIR/clover-bootmanager.service" ] || fail "开机修复服务未安装"
[ -f "$SYSTEM_DIR/clover-bootmanager.sh" ] || fail "开机修复脚本未安装"
[ -f "$WHITELIST_DIR/clover-whitelist.conf" ] || fail "开机修复白名单未安装"
grep -Fq 'enable --now clover-bootmanager.service' "$STATE/calls" || \
    fail "开机修复服务未启用"

status_output="$(clover_status)" || fail "安装后状态检查失败"
printf '%s\n' "$status_output" | grep -Fq 'Clover：已由Renkit安装' || fail "状态未报告 Clover 已安装"

clover_delete >/dev/null || fail "模拟删除Renkit Clover 双系统引导失败"
[ -f "$ESP/EFI/CLOVER/original.txt" ] || fail "没有恢复安装前的 CLOVER 目录"
[ ! -e "$ESP/EFI/CLOVER/.zhoukeer-managed" ] || fail "恢复后仍使用Renkit Clover"
[ "$(cat "$STATE/bootorder")" = '0000,0001' ] || fail "没有恢复原 BootOrder"
[ "$(cat "$STATE/clover-entry")" = '0' ] || fail "没有删除Renkit Clover NVRAM 入口"
[ -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi" ] || fail "Windows 直启未恢复"
[ ! -e "$ESP/EFI/Microsoft/bootmgfw.efi" ] || fail "旧版 Clover Windows 入口未清理"
[ ! -e "$SYSTEM_DIR/clover-bootmanager.service" ] || fail "Clover 服务未移除"
[ ! -e "$SYSTEM_DIR/clover-bootmanager.sh" ] || fail "Clover 开机修复脚本未移除"
[ ! -e "$WHITELIST_DIR/clover-whitelist.conf" ] || fail "SteamOS Clover 白名单未移除"
grep -Fq 'disable --now clover-bootmanager.service' "$STATE/calls" || fail "Clover 服务未停用"

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

echo "PASS: Clover Gitee 镜像、设备配置、怪盗主题、Windows 启动保留、BootOrder 和删除恢复模拟测试通过"
