#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="$PROJECT_ROOT/modules/f1_bios_prepare.sh"
TMP_ROOT="$(mktemp -d)"
FIXTURE_ROOT_NAME="F1-AMD7840U-Black-White-BIOS-V1.14-HarmanForWin&Linux-tutorial"
FIXTURE_PARENT="$TMP_ROOT/fixture"
FIXTURE_ROOT="$FIXTURE_PARENT/$FIXTURE_ROOT_NAME"
FIXTURE_ZIP="$TMP_ROOT/f1-bios.zip"
SHARED_DRIVE="$TMP_ROOT/run/media/deck/Game"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

mkdir -p "$FIXTURE_ROOT" "$SHARED_DRIVE" "$TMP_ROOT/logs"
for file in \
    AFUWINGUIx64.EXE \
    AFUWINx64.exe \
    AfuEfix64.efi \
    OXF.bat \
    OXP_7840U_P6C2L18M0C15_V1.14_AMP_LinuxV0_EC_V1.0.22_S011.8_20240725.bin \
    'OneXFly-BIOS-Process Steps.txt' \
    Thumbs.db \
    amifldrv64.sys \
    amigendrv64.sys; do
    printf 'fixture:%s\n' "$file" > "$FIXTURE_ROOT/$file"
done
(
    cd "$FIXTURE_PARENT"
    zip -qr "$FIXTURE_ZIP" "$FIXTURE_ROOT_NAME"
)

printf 'ONEXPLAYER F1\n' > "$TMP_ROOT/product-f1"
printf 'Other Device\n' > "$TMP_ROOT/product-other"
printf 'model name : AMD Ryzen 7 7840U w/ Radeon 780M Graphics\n' > "$TMP_ROOT/cpu-7840u"
printf 'model name : AMD Ryzen 7 8840U w/ Radeon 780M Graphics\n' > "$TMP_ROOT/cpu-8840u"

ZHOUKEER_TEST_MODE=1
ZHOUKEER_F1_BIOS_PRODUCT_FILE="$TMP_ROOT/product-f1"
ZHOUKEER_F1_BIOS_CPUINFO_FILE="$TMP_ROOT/cpu-7840u"
ZHOUKEER_F1_BIOS_SHARED_DRIVE="$SHARED_DRIVE"

# shellcheck disable=SC1090
source "$MODULE"
trap 'f1_bios_cleanup; rm -rf -- "$TMP_ROOT"' EXIT

LOG_DIR="$TMP_ROOT/logs"
LOG_FILE="$LOG_DIR/toolbox.log"
DOWNLOAD_CALLS="$TMP_ROOT/download.log"

detect_platform() { IS_STEAMOS=1; }
require_command() { return 0; }
log() { printf '%s\n' "$*" >> "$LOG_FILE"; }
download_github_file() {
    local url="$1" output="$2" sha="$3" name="$4"
    printf '%s|%s|%s\n' "$url" "$sha" "$name" >> "$DOWNLOAD_CALLS"
    cp "$FIXTURE_ZIP" "$output"
}
# 行为测试使用等结构小型夹具；生产函数仍固定校验原厂 ZIP 和九个文件 SHA256。
f1_bios_vendor_files_valid() {
    local directory="$1" file
    for file in \
        AFUWINGUIx64.EXE \
        AFUWINx64.exe \
        AfuEfix64.efi \
        OXF.bat \
        "$F1_BIOS_BIN_NAME" \
        'OneXFly-BIOS-Process Steps.txt' \
        Thumbs.db \
        amifldrv64.sys \
        amigendrv64.sys; do
        [ -f "$directory/$file" ] && [ ! -L "$directory/$file" ] || return 1
    done
}

f1_bios_archive_layout_valid "$FIXTURE_ZIP" || fail "合法原厂结构夹具被拒绝"
cp "$FIXTURE_ZIP" "$TMP_ROOT/bad-layout.zip"
printf 'unexpected\n' > "$TMP_ROOT/unexpected.txt"
zip -qj "$TMP_ROOT/bad-layout.zip" "$TMP_ROOT/unexpected.txt"
if f1_bios_archive_layout_valid "$TMP_ROOT/bad-layout.zip"; then
    fail "包含额外文件的 BIOS 压缩包仍通过结构校验"
fi

F1_BIOS_PRODUCT_FILE="$TMP_ROOT/product-other"
if f1_bios_prepare > "$TMP_ROOT/not-f1.out" 2>&1; then
    fail "非 ONEXPLAYER F1 仍允许准备 BIOS"
fi
grep -Fq '不是 ONEXPLAYER F1' "$TMP_ROOT/not-f1.out" || fail "非目标机型缺少拒绝提示"
[ ! -e "$SHARED_DRIVE/$F1_BIOS_TARGET_NAME" ] || fail "非目标机型写入了互通盘"

F1_BIOS_PRODUCT_FILE="$TMP_ROOT/product-f1"
F1_BIOS_CPUINFO_FILE="$TMP_ROOT/cpu-8840u"
if f1_bios_prepare > "$TMP_ROOT/8840u.out" 2>&1; then
    fail "8840U 仍允许准备 7840U BIOS"
fi
grep -Fq '不适用于 8840U' "$TMP_ROOT/8840u.out" || fail "8840U 缺少明确拒绝提示"

F1_BIOS_CPUINFO_FILE="$TMP_ROOT/cpu-7840u"
if ! f1_bios_prepare > "$TMP_ROOT/prepare.out"; then
    fail "F1 7840U BIOS 准备失败"
fi
TARGET="$SHARED_DRIVE/$F1_BIOS_TARGET_NAME"
[ -f "$TARGET/OXF.bat" ] || fail "互通盘缺少 OXF.bat"
[ -f "$TARGET/$F1_BIOS_BIN_NAME" ] || fail "互通盘缺少 V1.14 BIOS BIN"
[ -f "$TARGET/刷写前必读.txt" ] || fail "互通盘缺少刷写安全说明"
[ ! -d "$TARGET/$FIXTURE_ROOT_NAME" ] || fail "原始含 & 的目录名未被展平"
grep -Fq '没有刷写 BIOS' "$TMP_ROOT/prepare.out" || fail "完成提示未说明 SteamOS 不刷 BIOS"
grep -Fq "$F1_BIOS_ARCHIVE_SHA256" "$DOWNLOAD_CALLS" || fail "下载未使用固定原厂 ZIP SHA256"
grep -Fq '严禁用于：8840U、EVA、F1 Pro' "$TARGET/刷写前必读.txt" || fail "刷写说明缺少禁用机型"

: > "$DOWNLOAD_CALLS"
if ! f1_bios_prepare > "$TMP_ROOT/idempotent.out"; then
    fail "重复准备 BIOS 失败"
fi
[ ! -s "$DOWNLOAD_CALLS" ] || fail "有效目标目录仍重复下载 BIOS"
grep -Fq '已经准备完成' "$TMP_ROOT/idempotent.out" || fail "重复准备缺少幂等提示"

SECOND_SHARED="$TMP_ROOT/shared-two"
mkdir -p "$SECOND_SHARED/$F1_BIOS_TARGET_NAME"
printf 'user data\n' > "$SECOND_SHARED/$F1_BIOS_TARGET_NAME/do-not-overwrite.txt"
ZHOUKEER_F1_BIOS_SHARED_DRIVE="$SECOND_SHARED"
if f1_bios_prepare > "$TMP_ROOT/existing.out" 2>&1; then
    fail "异常目标目录仍被覆盖"
fi
grep -Fq '不会覆盖' "$TMP_ROOT/existing.out" || fail "异常目录缺少拒绝覆盖提示"
[ -f "$SECOND_SHARED/$F1_BIOS_TARGET_NAME/do-not-overwrite.txt" ] || fail "用户原文件被删除"

grep -Fq "/run/media/deck/*" "$MODULE" || fail "未实现 Game 挂载名大小写不敏感扫描"
grep -Fq "tr '[:upper:]' '[:lower:]'" "$MODULE" || fail "Game 挂载名未转为小写比较"

echo "PASS: 飞行家 F1 7840U BIOS 机型保护、互通盘准备、结构校验、幂等与拒绝覆盖模拟通过"
