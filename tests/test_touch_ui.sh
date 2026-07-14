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
run_choice_test '\033[<0;15;7M' "software" "left:6-7:software"

grep -Fq 'Font=Noto Sans Mono CJK SC,19' "$PROJECT_ROOT/install.sh"
grep -Fq 'FillStyle=Crop' "$PROJECT_ROOT/assets/Zhoukeer.colorscheme.in"
grep -Fq 'Wallpaper=@WALLPAPER@' "$PROJECT_ROOT/assets/Zhoukeer.colorscheme.in"
grep -Fq 'Exec=konsole --profile' "$PROJECT_ROOT/install.sh"

echo "PASS: 纯触控、大按钮、大字体和背景主题测试通过"
