#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TMP_ROOT"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

OS_RELEASE="$TMP_ROOT/os-release"
DMI_ROOT="$TMP_ROOT/dmi"
FIXTURE_ROOT="$TMP_ROOT/fixture"
FIXTURE="$TMP_ROOT/Clover.tar.gz"
STAGE_ROOT="$TMP_ROOT/stage"
GPD_STAGE_ROOT="$TMP_ROOT/gpd-stage"
mkdir -p "$DMI_ROOT" "$FIXTURE_ROOT/Clover/clover" "$FIXTURE_ROOT/Clover/custom"
cat > "$OS_RELEASE" <<'EOF'
ID=bazzite
VARIANT_ID=bazzite-deck
PRETTY_NAME="Bazzite Test"
EOF
printf '%s\n' "Unknown Iris Xe Handheld" > "$DMI_ROOT/product_name"
printf '%s\n' "Unknown Board" > "$DMI_ROOT/board_name"
printf '%s\n' "clover" > "$FIXTURE_ROOT/Clover/clover/cloverx64.efi"
printf '%s\n' '<plist/>' > "$FIXTURE_ROOT/Clover/custom/Generic-config.plist"
(
    cd "$FIXTURE_ROOT"
    tar -czf "$FIXTURE" Clover
)

ZHOUKEER_OS_RELEASE_FILE="$OS_RELEASE"
ZHOUKEER_DMI_ROOT="$DMI_ROOT"
ZHOUKEER_AUTO_CONFIRM=1
export ZHOUKEER_OS_RELEASE_FILE ZHOUKEER_DMI_ROOT ZHOUKEER_AUTO_CONFIRM
# shellcheck disable=SC1090
source "$PROJECT_ROOT/modules/clover_boot.sh"

require_supported_gaming_os || fail "Bazzite 被 Clover 模块拒绝"
clover_detect_device || fail "Bazzite 通用设备识别失败"
[ "$CLOVER_DEVICE_PREFIX" = "Bazzite-generic" ] || fail "未知 Bazzite 设备没有使用通用配置"
[ -z "$CLOVER_EFI_DRIVER" ] || fail "通用 Bazzite 配置误加载设备专用驱动"
[ -z "$CLOVER_SCREEN_RESOLUTION" ] || fail "通用 Bazzite 配置误写固定分辨率"
[ "$(clover_choose_default_os)" = "Bazzite" ] || fail "Bazzite 默认启动项选择错误"

CLOVER_DEFAULT_OS="Bazzite"
CLOVER_DEVICE_CONFIG="$PROJECT_ROOT/assets/clover/config.plist"
staged="$(clover_prepare_staging "$FIXTURE" "$STAGE_ROOT")" || fail "Bazzite Clover 准备阶段失败"
awk '
    /<key>DefaultLoader<\/key>/ {
        getline
        if (index($0, "\\EFI\\fedora\\shimx64.efi")) found=1
    }
    END { exit(found ? 0 : 1) }
' "$staged/config.plist" || fail "Bazzite shim 未设置为默认启动器"
grep -Fq '<string>\EFI\Microsoft\Boot\bootmgfw.efi</string>' "$staged/config.plist" || \
    fail "Clover Windows 入口没有指向官方启动文件"
if grep -Fiq 'steamcl.efi' "$staged/config.plist"; then
    fail "Bazzite Clover 配置仍保留旧 SteamOS 菜单项"
fi
if grep -Fq '<key>ScreenResolution</key>' "$staged/config.plist"; then
    fail "Bazzite Clover 通用配置仍写死屏幕分辨率"
fi

printf '%s\n' "G1618-03" > "$DMI_ROOT/product_name"
clover_detect_device || fail "GPD WIN 3 设备识别失败"
[ "$CLOVER_DEVICE_PREFIX" = "Bazzite-generic" ] || fail "GPD WIN 3 没有复用 Bazzite 通用配置"
[ "$CLOVER_SCREEN_RESOLUTION" = "1280x720" ] || fail "GPD WIN 3 没有启用横屏分辨率"
CLOVER_DEFAULT_OS="Bazzite"
CLOVER_DEVICE_CONFIG="$PROJECT_ROOT/assets/clover/config.plist"
gpd_staged="$(clover_prepare_staging "$FIXTURE" "$GPD_STAGE_ROOT")" || \
    fail "GPD WIN 3 Clover 准备阶段失败"
awk '
    /<key>ScreenResolution<\/key>/ {
        getline
        if ($0 ~ /<string>1280x720<\/string>/) found=1
    }
    END { exit(found ? 0 : 1) }
' "$gpd_staged/config.plist" || fail "GPD WIN 3 Clover 未写入 1280x720 横屏模式"

SYSTEM_DIR="$TMP_ROOT/systemd"
WHITELIST_DIR="$TMP_ROOT/steam-atomic-whitelist"
SYSTEMCTL_LOG="$TMP_ROOT/systemctl.log"
CLOVER_BOOTMANAGER_SYSTEM_DIR="$SYSTEM_DIR"
CLOVER_BOOTMANAGER_WHITELIST_DIR="$WHITELIST_DIR"
ZHOUKEER_CLOVER_SKIP_BOOTMANAGER_RUN=1
toolbox_sudo() { "$@"; }
systemctl() { printf '%s\n' "$*" >> "$SYSTEMCTL_LOG"; }
clover_install_bootmanager >/dev/null || fail "Bazzite Clover 服务模拟安装失败"
[ -f "$SYSTEM_DIR/clover-bootmanager.service" ] || fail "Bazzite Clover 服务文件缺失"
[ -f "$SYSTEM_DIR/clover-bootmanager.sh" ] || fail "Bazzite Clover 修复脚本缺失"
[ ! -e "$WHITELIST_DIR/clover-whitelist.conf" ] || fail "Bazzite 误安装 SteamOS atomic-update 白名单"
grep -Fq 'After=local-fs.target' "$SYSTEM_DIR/clover-bootmanager.service" || \
    fail "Bazzite Clover 服务未等待本地 EFI 挂载"
grep -Fq 'ExecStart=/usr/bin/bash /etc/systemd/system/clover-bootmanager.sh' \
    "$SYSTEM_DIR/clover-bootmanager.service" || \
    fail "Bazzite Clover 服务仍直接执行 systemd 配置目录中的脚本"

# 下面所有 EFI/NVRAM 操作均使用临时目录与模拟命令，不接触真实系统。
ESP="$TMP_ROOT/esp"
MOCK_BIN="$TMP_ROOT/bin"
MOCK_STATE="$TMP_ROOT/state"
mkdir -p "$ESP/EFI/fedora" "$ESP/EFI/CLOVER" "$ESP/EFI/Microsoft/Boot" "$MOCK_BIN" "$MOCK_STATE"
printf '%s\n' "bazzite" > "$ESP/EFI/fedora/shimx64.efi"
printf '%s\n' "clover" > "$ESP/EFI/CLOVER/CLOVERX64.efi"
# 模拟旧版 Renkit 已移动 Windows 文件，开机服务必须迁回官方位置。
printf '%s\n' "windows" > "$ESP/EFI/Microsoft/bootmgfw.efi"
printf '%s\n' "windows" > "$ESP/EFI/Microsoft/Boot/bootmgfw.efi.zhoukeer-orig"
printf '%s\n' "0" > "$MOCK_STATE/clover-entry"
printf '%s\n' "0001,0003,0004" > "$MOCK_STATE/bootorder"

cat > "$MOCK_BIN/efibootmgr" <<'EOF'
#!/bin/bash
set -eu
case "${1:-}" in
    --create)
        printf '%s\n' "1" > "$MOCK_STATE/clover-entry"
        ;;
    --bootorder)
        printf '%s\n' "$2" > "$MOCK_STATE/bootorder"
        ;;
    *)
        printf 'BootCurrent: 0001\nBootOrder: %s\n' "$(cat "$MOCK_STATE/bootorder")"
        printf 'Boot0001* Bazzite HD(7,GPT,TEST)/File(\\EFI\\fedora\\shimx64.efi)\n'
        if [ "$(cat "$MOCK_STATE/clover-entry")" = "1" ]; then
            printf 'Boot0002* Zhoukeer Clover HD(7,GPT,TEST)/File(\\EFI\\CLOVER\\CLOVERX64.efi)\n'
        fi
        printf 'Boot0003* Windows Boot Manager HD(7,GPT,TEST)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n'
        printf 'Boot0004* PXE Network\n'
        ;;
esac
EOF
cat > "$MOCK_BIN/findmnt" <<'EOF'
#!/bin/bash
case "$*" in
    *'-o SOURCE'*) printf '%s\n' "/dev/nvme1n1p7" ;;
    *'-o FSTYPE'*) printf '%s\n' "vfat" ;;
esac
EOF
cat > "$MOCK_BIN/lsblk" <<'EOF'
#!/bin/bash
case "$*" in
    *PKNAME*) printf '%s\n' "nvme1n1" ;;
    *PARTN*) printf '%s\n' "7" ;;
esac
EOF
chmod +x "$MOCK_BIN/efibootmgr" "$MOCK_BIN/findmnt" "$MOCK_BIN/lsblk"

STATUS_FILE="$TMP_ROOT/clover-status.txt"
MOCK_STATE="$MOCK_STATE" PATH="$MOCK_BIN:/usr/bin:/bin" \
ZHOUKEER_OS_RELEASE_FILE="$OS_RELEASE" ZHOUKEER_CLOVER_ESP="$ESP" \
ZHOUKEER_CLOVER_STATUS_FILE="$STATUS_FILE" \
    bash "$PROJECT_ROOT/assets/clover/bootmanager/clover-bootmanager.sh" || \
    fail "Bazzite Clover 开机修复模拟失败"

[ "$(cat "$MOCK_STATE/bootorder")" = "0002,0001,0003,0004" ] || \
    fail "开机修复没有保留原有 Bazzite、Windows 与 PXE 启动项"
[ -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi" ] || fail "Windows 官方启动文件没有恢复"
[ ! -e "$ESP/EFI/Microsoft/Boot/bootmgfw.efi.zhoukeer-orig" ] || fail "旧版 Windows 启动备份仍残留"
[ ! -e "$ESP/EFI/Microsoft/bootmgfw.efi" ] || fail "旧版 Windows 启动副本仍残留"
grep -Fq 'Clover 开机修复完成' "$STATUS_FILE" || fail "开机修复状态日志缺失"

STATUS_TARGET="$TMP_ROOT/status-target.txt"
STATUS_LINK="$TMP_ROOT/status-link.txt"
printf '%s\n' "sentinel" > "$STATUS_TARGET"
ln -s "$STATUS_TARGET" "$STATUS_LINK"
if MOCK_STATE="$MOCK_STATE" PATH="$MOCK_BIN:/usr/bin:/bin" \
    ZHOUKEER_OS_RELEASE_FILE="$OS_RELEASE" ZHOUKEER_CLOVER_ESP="$ESP" \
    ZHOUKEER_CLOVER_STATUS_FILE="$STATUS_LINK" \
        bash "$PROJECT_ROOT/assets/clover/bootmanager/clover-bootmanager.sh" >/dev/null 2>&1; then
    fail "Clover 开机修复接受了符号链接状态日志"
fi
[ "$(cat "$STATUS_TARGET")" = "sentinel" ] || fail "符号链接状态日志覆盖了其他文件"

# 模拟 Bazzite 重装到原 SteamOS 双系统后，Clover 安装流程自动归档旧 SteamOS
# EFI 文件并删除且仅删除指向 steamcl.efi 的 NVRAM 项。所有操作均在临时目录。
CLEANUP_ESP="$TMP_ROOT/cleanup-esp"
CLEANUP_STATE="$TMP_ROOT/cleanup-state"
mkdir -p "$CLEANUP_ESP/EFI/fedora" "$CLEANUP_ESP/EFI/steamos" \
    "$CLEANUP_ESP/EFI/CLOVER" "$CLEANUP_ESP/EFI/Microsoft/Boot" "$CLEANUP_STATE"
printf '%s\n' "bazzite" > "$CLEANUP_ESP/EFI/fedora/shimx64.efi"
printf '%s\n' "steam" > "$CLEANUP_ESP/EFI/steamos/steamcl.efi"
printf '%s\n' "clover" > "$CLEANUP_ESP/EFI/CLOVER/CLOVERX64.efi"
printf '%s\n' "windows" > "$CLEANUP_ESP/EFI/Microsoft/Boot/bootmgfw.efi"
cat > "$CLEANUP_ESP/EFI/CLOVER/.zhoukeer-managed" <<'EOF'
VERSION=5173
ORIGINAL_BACKUP=
ORIGINAL_BOOT_ORDER=0005,0001,0003
EOF
printf '%s\n' "1" > "$CLEANUP_STATE/steam-entry"
printf '%s\n' "0005,0001,0003" > "$CLEANUP_STATE/bootorder"

detect_platform() { IS_STEAMOS=0; IS_BAZZITE=1; }
toolbox_sudo() { "$@"; }
log() { printf '%s\n' "$*" >> "$CLEANUP_STATE/log"; }
efibootmgr() {
    case "${1:-}" in
        -v)
            printf 'BootCurrent: 0001\nBootOrder: %s\n' "$(cat "$CLEANUP_STATE/bootorder")"
            if [ "$(cat "$CLEANUP_STATE/steam-entry")" = "1" ]; then
                printf 'Boot0005* SteamOS HD(1,GPT,TEST)/File(\\EFI\\steamos\\steamcl.efi)\n'
            fi
            printf 'Boot0001* Bazzite HD(1,GPT,TEST)/File(\\EFI\\fedora\\shimx64.efi)\n'
            printf 'Boot0003* Windows Boot Manager HD(1,GPT,TEST)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n'
            ;;
        --delete-bootnum)
            [ "${3:-}" = "0005" ] || fail "清理流程删除了非 SteamOS NVRAM 项：${3:-}"
            printf '%s\n' "0" > "$CLEANUP_STATE/steam-entry"
            printf '%s\n' "0001,0003" > "$CLEANUP_STATE/bootorder"
            ;;
        --create)
            printf '%s\n' "1" > "$CLEANUP_STATE/steam-entry"
            printf 'Boot0005* SteamOS HD(1,GPT,TEST)/File(\\EFI\\steamos\\steamcl.efi)\n'
            ;;
        --bootorder)
            printf '%s\n' "$2" > "$CLEANUP_STATE/bootorder"
            ;;
        *) printf 'BootOrder: %s\n' "$(cat "$CLEANUP_STATE/bootorder")" ;;
    esac
}
CLOVER_ESP="$CLEANUP_ESP"
CLOVER_DISK="/dev/mockdisk"
CLOVER_PARTITION="1"
clover_cleanup_legacy_steamos >/dev/null || fail "Bazzite 旧 SteamOS 引导自动清理失败"
[ ! -e "$CLEANUP_ESP/EFI/steamos" ] || fail "旧 SteamOS EFI 目录仍在活动位置"
steamos_backup="$(clover_marker_value \
    "$CLEANUP_ESP/EFI/CLOVER/.zhoukeer-managed" STEAMOS_BACKUP)"
[ -f "$steamos_backup/steamcl.efi" ] || fail "旧 SteamOS EFI 文件没有进入安全备份"
[ "$(cat "$CLEANUP_STATE/steam-entry")" = "0" ] || fail "旧 SteamOS NVRAM 项未删除"
[ "$(cat "$CLEANUP_STATE/bootorder")" = "0001,0003" ] || fail "清理后 BootOrder 仍含旧 SteamOS"
[ -f "$CLEANUP_ESP/EFI/fedora/shimx64.efi" ] || fail "清理误删 Bazzite EFI"
[ -f "$CLEANUP_ESP/EFI/Microsoft/Boot/bootmgfw.efi" ] || fail "清理误删 Windows EFI"
[ -f "$CLEANUP_ESP/EFI/CLOVER/CLOVERX64.efi" ] || fail "清理误删 Clover EFI"
clover_cleanup_legacy_steamos >/dev/null || fail "旧 SteamOS 引导清理重复执行不幂等"

require_command() { return 0; }
clover_prepare_admin_access() { return 0; }
clover_resolve_esp_device() {
    CLOVER_ESP="$CLEANUP_ESP"
    CLOVER_ESP_SOURCE="/dev/mockdiskp1"
    CLOVER_DISK="/dev/mockdisk"
    CLOVER_PARTITION="1"
}
clover_confirm_restore() { return 0; }
clover_restore >/dev/null || fail "恢复 Clover 时没有还原已备份的旧 SteamOS 引导"
[ -f "$CLEANUP_ESP/EFI/steamos/steamcl.efi" ] || fail "恢复入口没有还原 SteamOS EFI 文件"
[ "$(cat "$CLEANUP_STATE/steam-entry")" = "1" ] || fail "恢复入口没有重建 SteamOS NVRAM 项"
[ "$(cat "$CLEANUP_STATE/bootorder")" = "0005,0001,0003" ] || \
    fail "恢复入口没有还原包含 SteamOS 的原 BootOrder"

clover_steamos_backup_path_is_safe "$steamos_backup" || fail "合法 SteamOS 备份路径被拒绝"
if clover_steamos_backup_path_is_safe "$TMP_ROOT/outside-steamos"; then
    fail "SteamOS 管理标记可指向 EFI 备份目录之外"
fi
clover_boot_number_list_is_safe $'0005\n00AF' || fail "合法 SteamOS 启动编号列表被拒绝"
if clover_boot_number_list_is_safe $'0005\n../../tmp'; then
    fail "异常 SteamOS 启动编号列表未被拒绝"
fi
[ "$(clover_replace_boot_numbers '0005,0001,0003' '0005' '0007')" = \
    "0007,0001,0003" ] || fail "恢复流程未正确替换 SteamOS BootOrder 编号"

if rg -n '/dev/nvme0n1|sudo|bash[[:space:]]+-c' "$PROJECT_ROOT/assets/clover/bootmanager"; then
    fail "Clover 开机修复仍包含固定磁盘、sudo 或 bash -c"
fi

echo "PASS: Bazzite 通用 Clover 配置、动态 EFI 设备与 BootOrder 保留模拟测试通过"
