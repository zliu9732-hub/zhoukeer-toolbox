#!/bin/bash

# 只模拟终端尺寸并读取本地图片；不执行系统安装、联网或提权操作。
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCK_ROWS=24 MOCK_COLS=120
stty() { [ "$1" = size ] && printf '%s %s\n' "$MOCK_ROWS" "$MOCK_COLS"; }
tput() { return 1; }
source "$PROJECT_ROOT/core/ui.sh"

capture_file="$(mktemp "${TMPDIR:-/tmp}/renkit-help-layout.XXXXXX")"
trap 'rm -f "$capture_file"' EXIT
KONSOLE_VERSION=220400

check_layout() {
    local label="$1" rows="$2" cols="$3" font="$4" qr_size="$5" xianyu_size="$6"
    MOCK_ROWS="$rows" MOCK_COLS="$cols" ZHOUKEER_FONT_SIZE="$font"
    ui_detect_layout
    ui_help_image 6 left "$PROJECT_ROOT/assets/help/renamamiya-qr.sixel" > "$capture_file"
    if ! LC_ALL=C grep -aFq "\"1;1;$qr_size;$qr_size" "$capture_file"; then
        printf 'FAIL: %s 二维码尺寸错误\n' "$label" >&2
        return 1
    fi
    ui_help_image 6 right "$PROJECT_ROOT/assets/help/xianyu-renamamiya.sixel" > "$capture_file"
    if ! LC_ALL=C grep -aFq "\"1;1;$xianyu_size;$qr_size" "$capture_file"; then
        printf 'FAIL: %s 闲鱼图片尺寸错误\n' "$label" >&2
        return 1
    fi
}

check_layout '窄窗口' 26 80 12 123 168
check_layout 'Steam Deck 800p' 42 125 12 205 280
check_layout '1080p' 54 190 14 451 616
check_layout '2K' 70 230 16 615 840
check_layout '4K' 100 360 20 779 1064

printf '帮助页图片尺寸模拟测试通过\n'
