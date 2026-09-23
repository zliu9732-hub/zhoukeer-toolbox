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
    local label="$1" rows="$2" cols="$3" font="$4" qr_size="$5" xianyu_size="$6" xianyu_height="$7"
    MOCK_ROWS="$rows" MOCK_COLS="$cols" ZHOUKEER_FONT_SIZE="$font"
    ui_detect_layout
    ui_help_image 6 left "$PROJECT_ROOT/assets/help/renamamiya-qr.sixel" > "$capture_file"
    if ! LC_ALL=C grep -aFq "\"1;1;$qr_size;$qr_size" "$capture_file"; then
        printf 'FAIL: %s 二维码尺寸错误\n' "$label" >&2
        return 1
    fi
    ui_help_image 6 right "$PROJECT_ROOT/assets/help/xianyu-renamamiya.sixel" > "$capture_file"
    if ! LC_ALL=C grep -aFq "\"1;1;$xianyu_size;$xianyu_height" "$capture_file"; then
        printf 'FAIL: %s 闲鱼图片尺寸错误\n' "$label" >&2
        return 1
    fi
}

check_layout '窄窗口' 26 80 12 123 126 92
check_layout 'Steam Deck 800p 矮窗口' 28 100 12 246 252 184
check_layout 'Steam Deck 800p 较大窗口' 40 125 12 369 378 276
check_layout '1080p' 47 150 14 451 462 338
check_layout '2K 保守档' 65 160 16 451 462 338
check_layout '4K 保守档' 90 240 20 615 630 461

# Steam Deck 矮窗口的左图和缩小后的右图均在各自栏位居中。
MOCK_ROWS=28 MOCK_COLS=100 ZHOUKEER_FONT_SIZE=12
ui_detect_layout
ui_help_image 6 left "$PROJECT_ROOT/assets/help/renamamiya-qr.sixel" > "$capture_file"
printf -v expected_move '\033[6;35H'
LC_ALL=C grep -aFq "$expected_move" "$capture_file" || {
    printf 'FAIL: Steam Deck 二维码未居中\n' >&2
    exit 1
}
ui_help_image 6 right "$PROJECT_ROOT/assets/help/xianyu-renamamiya.sixel" > "$capture_file"
ui_scale_row 6
expected_row=$((UI_SCALED_ROW + (246 - 184) / (2 * 24)))
right_start=$((UI_PANEL_COL + UI_PANEL_WIDTH / 2 + 1))
right_width=$((UI_PANEL_WIDTH - UI_PANEL_WIDTH / 2 - 1))
image_columns=$(((252 + 9 - 1) / 9))
expected_column=$((right_start + (right_width - image_columns) / 2))
printf -v expected_move '\033[%s;%sH' "$expected_row" "$expected_column"
LC_ALL=C grep -aFq "$expected_move" "$capture_file" || {
    printf 'FAIL: Steam Deck 闲鱼图片未居中\n' >&2
    exit 1
}
[ "$image_columns" -le "$right_width" ] || {
    printf 'FAIL: Steam Deck 闲鱼图仍超出右侧栏位\n' >&2
    exit 1
}

# 1080p 右图缩小后留出安全边距并与右栏标题/说明同轴；左图保持原位置。
MOCK_ROWS=47 MOCK_COLS=150 ZHOUKEER_FONT_SIZE=14
ui_detect_layout
ui_help_image 6 left "$PROJECT_ROOT/assets/help/renamamiya-qr.sixel" > "$capture_file"
printf -v expected_move '\033[10;47H'
LC_ALL=C grep -aFq "$expected_move" "$capture_file" || {
    printf 'FAIL: 1080p 二维码位置发生意外变化\n' >&2
    exit 1
}
ui_help_image 6 right "$PROJECT_ROOT/assets/help/xianyu-renamamiya.sixel" > "$capture_file"
ui_scale_row 6
expected_row=$((UI_SCALED_ROW + (451 - 338) / (2 * 28)))
right_start=$((UI_PANEL_COL + UI_PANEL_WIDTH / 2 + 1))
right_width=$((UI_PANEL_WIDTH - UI_PANEL_WIDTH / 2 - 1))
image_columns=$(((462 + 10 - 1) / 10))
expected_column=$((right_start + (right_width - image_columns) / 2))
printf -v expected_move '\033[%s;%sH' "$expected_row" "$expected_column"
LC_ALL=C grep -aFq "$expected_move" "$capture_file" || {
    printf 'FAIL: 1080p 闲鱼图片未居中\n' >&2
    exit 1
}
[ "$image_columns" -le "$right_width" ] || {
    printf 'FAIL: 1080p 闲鱼图仍超出右侧栏位\n' >&2
    exit 1
}

printf '帮助页图片尺寸模拟测试通过\n'
