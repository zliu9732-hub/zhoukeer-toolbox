#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

run_choice_test() {
    local input="$1"
    local expected="$2"
    local mapping="$3"
    local actual

    if ! actual="$(
        INPUT="$input" MAPPING="$mapping" PROJECT_ROOT="$PROJECT_ROOT" bash -c '
            source "$PROJECT_ROOT/core/ui.sh"
            printf "%b" "$INPUT" | read_menu_choice "$MAPPING"
        '
    )"; then
        fail "触控事件未命中任何动作：$mapping"
    fi
    [ "$actual" = "$expected" ] || fail "触控事件期望 $expected，实际为 $actual"
}

run_choice_test '1\033[<0;40;13M' "wechat" "right:12-14:wechat"
run_choice_test '\033[<0;40;13m\033[<0;40;18M' "cancel" "right:18-19:cancel"
run_choice_test '\033[<64;40;13M\033[<32;40;13M\033[<0;40;18M' "cancel" "right:18-19:cancel"
run_choice_test '\033[<0;15;5M' "nav-software" "left:5-6:nav-software"
run_choice_test '\033[<0;40;22M' "home" "right:22-23:home"

grep -Fq 'UI_LAST_ROW=24' "$PROJECT_ROOT/core/ui.sh" || fail "触控画布行数异常"
grep -Fq 'Font=Noto Sans Mono CJK SC,17' "$PROJECT_ROOT/install.sh" || fail "中文字体配置缺失"

frame="$(sed -n '/^draw_category_frame()/,/^}/p' "$PROJECT_ROOT/core/ui.sh")"
for entry in \
    'ui_sidebar_item 2 init "◆ 新机必备"' \
    'ui_sidebar_item 5 software "▣ 常用软件"' \
    'ui_sidebar_item 8 games "✦ 游戏环境"' \
    'ui_sidebar_item 11 network "⌁ 网络与应用商店"' \
    'ui_sidebar_item 14 maintenance "▲ 系统维护"' \
    'ui_sidebar_item 17 help "▤ 检测与帮助"' \
    'ui_sidebar_item 20 advanced "! 高级工具"' \
    'ui_sidebar_item 22 exit "× 退出工具箱"'; do
    printf '%s\n' "$frame" | grep -Fq -- "$entry" || fail "侧栏缺少：$entry"
done

[ "$(printf '%s\n' "$frame" | grep -c 'ui_sidebar_item')" -eq 8 ] || fail "侧栏入口数量错误"

touch_nav="$(sed -n '/^read_touch_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
for mapping in \
    'left:2-3:nav-init' \
    'left:5-6:nav-software' \
    'left:8-9:nav-games' \
    'left:11-12:nav-network' \
    'left:14-15:nav-maintenance' \
    'left:17-18:nav-help' \
    'left:20-21:nav-advanced' \
    'left:22-23:nav-exit'; do
    printf '%s\n' "$touch_nav" | grep -Fq -- "$mapping" || fail "导航坐标缺失：$mapping"
done

software="$(sed -n '/^common_software_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
printf '%s\n' "$software" | grep -Fq 'ui_touch_button 22' || fail "常用软件返回首页文字行错误"
printf '%s\n' "$software" | grep -Fq 'right:22-23:home' || fail "常用软件返回首页坐标错误"

changelog="$(sed -n '/^changelog_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
printf '%s\n' "$changelog" | grep -Fq 'CHANGELOG.md' || fail "更新日志文件映射缺失"
printf '%s\n' "$changelog" | grep -Fq 'VERSION' || fail "更新日志版本映射缺失"

echo "PASS: 七分类触控坐标、返回首页和基础界面配置正确"
