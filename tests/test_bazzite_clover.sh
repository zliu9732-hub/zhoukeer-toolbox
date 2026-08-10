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
grep -Fq '<string>\EFI\Microsoft\bootmgfw.efi</string>' "$staged/config.plist" || \
    fail "Clover Windows 入口没有指向Renkit管理位置"
if grep -Fq '<key>ScreenResolution</key>' "$staged/config.plist"; then
    fail "Bazzite Clover 通用配置仍写死屏幕分辨率"
fi

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

# 下面所有 EFI/NVRAM 操作均使用临时目录与模拟命令，不接触真实系统。
ESP="$TMP_ROOT/esp"
MOCK_BIN="$TMP_ROOT/bin"
MOCK_STATE="$TMP_ROOT/state"
mkdir -p "$ESP/EFI/fedora" "$ESP/EFI/CLOVER" "$ESP/EFI/Microsoft/Boot" "$MOCK_BIN" "$MOCK_STATE"
printf '%s\n' "bazzite" > "$ESP/EFI/fedora/shimx64.efi"
printf '%s\n' "clover" > "$ESP/EFI/CLOVER/CLOVERX64.efi"
printf '%s\n' "windows" > "$ESP/EFI/Microsoft/Boot/bootmgfw.efi"
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
[ -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi.zhoukeer-orig" ] || fail "Windows EFI 没有备份"
[ -f "$ESP/EFI/Microsoft/bootmgfw.efi" ] || fail "Windows EFI 没有移到 Clover 入口位置"
[ ! -f "$ESP/EFI/Microsoft/Boot/bootmgfw.efi" ] || fail "Windows 直启文件仍在原位置"
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

if rg -n '/dev/nvme0n1|sudo|bash[[:space:]]+-c' "$PROJECT_ROOT/assets/clover/bootmanager"; then
    fail "Clover 开机修复仍包含固定磁盘、sudo 或 bash -c"
fi

echo "PASS: Bazzite 通用 Clover 配置、动态 EFI 设备与 BootOrder 保留模拟测试通过"
