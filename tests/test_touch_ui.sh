#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_choice_test() {
    local input="$1"
    local expected="$2"
    local mapping="$3"
    local actual

    actual="$(
        INPUT="$input" MAPPING="$mapping" PROJECT_ROOT="$PROJECT_ROOT" bash -c '
            # shellcheck disable=SC1091
            source "$PROJECT_ROOT/core/ui.sh"
            printf "%b" "$INPUT" | read_menu_choice "$MAPPING"
        '
    )"
    if [ "$actual" != "$expected" ]; then
        echo "FAIL: 触控事件期望 $expected，实际为 $actual"
        exit 1
    fi
}

# 数字键必须被忽略，随后的 SGR 触摸按下事件才能选中。
run_choice_test '1\033[<0;40;13M' "wechat" "right:12-14:wechat"

# 触摸松开事件不得重复触发，后续的新按下事件才生效。
run_choice_test '\033[<0;40;13m\033[<0;40;18M' "cancel" "right:18-19:cancel"

# 滚轮与拖动事件不能误触菜单。
run_choice_test '\033[<64;40;13M\033[<32;40;13M\033[<0;40;18M' "cancel" "right:18-19:cancel"

# 大按钮使用行范围命中，不再要求精确点在单行文字上。
run_choice_test '\033[<0;15;5M' "software" "left:4-5:software"

grep -Fq 'Font=Noto Sans Mono CJK SC,17' "$PROJECT_ROOT/install.sh"
grep -Fq 'TerminalRows=22' "$PROJECT_ROOT/install.sh"
grep -Fq 'UI_LAST_ROW=20' "$PROJECT_ROOT/core/ui.sh"
grep -Fq 'WINDOW_SIZE="1220x740"' "$PROJECT_ROOT/launch.sh"
grep -Fq 'FillStyle=Crop' "$PROJECT_ROOT/assets/Zhoukeer.colorscheme.in"
grep -Fq 'Wallpaper=@WALLPAPER@' "$PROJECT_ROOT/assets/Zhoukeer.colorscheme.in"
grep -Fq 'WallpaperOpacity=0.35' "$PROJECT_ROOT/assets/Zhoukeer.colorscheme.in"
grep -Fq "label_color='\\033[1;38;5;45m'" "$PROJECT_ROOT/core/ui.sh"
grep -Fq 'Exec=bash "$INSTALL_DIR/launch.sh"' "$PROJECT_ROOT/install.sh"
grep -Fq 'launch_basic' "$PROJECT_ROOT/launch.sh"
if grep -Eq -- '--hide-(menubar|toolbars|tabbar)' "$PROJECT_ROOT/launch.sh" "$PROJECT_ROOT/install.sh"; then
    echo "FAIL: 启动流程仍包含旧版 Konsole 可能不支持的参数"
    exit 1
fi

grep -Fq '知悉并开始使用' "$PROJECT_ROOT/main.sh"
grep -Fq 'draw_disclaimer_frame' "$PROJECT_ROOT/main.sh"
grep -Fq 'any:15-16:agree any:18-19:exit' "$PROJECT_ROOT/main.sh"
grep -Fq '闲鱼：超级妹宝双叶' "$PROJECT_ROOT/main.sh"
grep -Fq '作者本人的123云盘提供' "$PROJECT_ROOT/main.sh"
grep -Fq '欢迎来闲鱼支持作者' "$PROJECT_ROOT/main.sh"
grep -Fq '小黄鸭（LSFG-VK）' "$PROJECT_ROOT/main.sh"
if sed -n '/ui_touch_button()/,/^}/p' "$PROJECT_ROOT/core/ui.sh" | grep -Fq "printf '%b%-50s%b'"; then
    echo "FAIL: 右侧按钮仍在绘制整块色块"
    exit 1
fi

sidebar_source="$(sed -n '/ui_sidebar_item()/,/^}/p' "$PROJECT_ROOT/core/ui.sh")"
frame_source="$(sed -n '/draw_category_frame()/,/^}/p' "$PROJECT_ROOT/core/ui.sh")"
if printf '%s\n%s\n' "$sidebar_source" "$frame_source" | grep -Eq '48;5;(24|45)'; then
    echo "FAIL: 左侧菜单仍包含蓝色背景填充"
    exit 1
fi
printf '%s\n' "$sidebar_source" | grep -Fq "marker='▌ '"
printf '%s\n' "$sidebar_source" | grep -Fq '──────────────────────────'

echo "PASS: 纯触控、透明按钮、免责声明、字体和背景主题测试通过"
