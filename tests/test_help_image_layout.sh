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
check_layout 'Steam Deck 800p 矮窗口' 28 100 12 246 336
check_layout 'Steam Deck 800p 较大窗口' 40 125 12 369 504
check_layout '1080p' 47 150 14 451 616
check_layout '2K' 65 160 16 615 840
check_layout '4K' 90 240 20 779 1064

# Steam Deck 矮窗口的左图应与本列标题/说明同轴；右图位置保持不变。
MOCK_ROWS=28 MOCK_COLS=100 ZHOUKEER_FONT_SIZE=12
ui_detect_layout
ui_help_image 6 left "$PROJECT_ROOT/assets/help/renamamiya-qr.sixel" > "$capture_file"
printf -v expected_move '\033[6;35H'
LC_ALL=C grep -aFq "$expected_move" "$capture_file" || {
    printf 'FAIL: Steam Deck 二维码未居中\n' >&2
    exit 1
}
ui_help_image 6 right "$PROJECT_ROOT/assets/help/xianyu-renamamiya.sixel" > "$capture_file"
printf -v expected_move '\033[6;69H'
LC_ALL=C grep -aFq "$expected_move" "$capture_file" || {
    printf 'FAIL: 闲鱼图片位置发生意外变化\n' >&2
    exit 1
}

printf '帮助页图片尺寸模拟测试通过\n'
