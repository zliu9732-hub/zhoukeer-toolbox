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
grep -Fq 'Font=Noto Sans Mono CJK SC,12' "$PROJECT_ROOT/install.sh" || fail "中文字体大小不是紧凑布局"
grep -Fq 'TerminalColumns=120' "$PROJECT_ROOT/install.sh" || fail "终端列数不是紧凑布局"
grep -Fq 'TerminalRows=32' "$PROJECT_ROOT/install.sh" || fail "终端行数不是紧凑布局"
grep -Fq 'WINDOW_SIZE="1280x820"' "$PROJECT_ROOT/launch.sh" || fail "工具箱窗口尺寸未同步"
grep -Fq "printf '\\033[0m\\033[r\\033[3J\\033[2J\\033[H'" "$PROJECT_ROOT/launch.sh" || fail "首次进入前未清理更新输出"

disclaimer="$(sed -n '/^draw_disclaimer_frame()/,/^}/p' "$PROJECT_ROOT/core/ui.sh")"
printf '%s\n' "$disclaimer" | grep -Fq 'ui_reset_screen' || fail "免责声明首屏未执行完整清屏"
main_disclaimer="$(sed -n '/^show_disclaimer()/,/^}/p' "$PROJECT_ROOT/main.sh")"
if printf '%s\n' "$main_disclaimer" | grep -Fq 'ui_disclaimer_line 14'; then
    fail "免责声明正文仍紧贴首个按钮"
fi
printf '%s\n' "$main_disclaimer" | grep -Fq 'launch.sh" --open-main' || fail "欢迎页确认后没有进入常规工具箱主题"
grep -Fq 'ZHOUKEER_SKIP_DISCLAIMER' "$PROJECT_ROOT/main.sh" || fail "常规工具箱没有跳过重复免责声明"
grep -Fq 'WELCOME_BACKGROUND_PATH' "$PROJECT_ROOT/install.sh" || fail "安装程序没有配置欢迎页背景"
grep -Fq 'ZhoukeerToolboxSplash' "$PROJECT_ROOT/install.sh" || fail "安装程序没有生成欢迎页主题"

touch_button="$(sed -n '/^ui_touch_button()/,/^}/p' "$PROJECT_ROOT/core/ui.sh")"
printf '%s\n' "$touch_button" | grep -Fq 'if [ -n "$hint" ]' || fail "空说明按钮仍会显示分隔符"

password_gate="$(sed -n '/^ensure_password_ready()/,/^}/p' "$PROJECT_ROOT/main.sh")"
printf '%s\n' "$password_gate" | grep -Fq 'modules/password.sh" import' || fail "首次启动缺少现有密码录入入口"
printf '%s\n' "$password_gate" | grep -Fq 'modules/password.sh" set' || fail "首次启动缺少新密码设置入口"
printf '%s\n' "$password_gate" | grep -Fq 'right:10-11:import' || fail "现有密码按钮坐标错误"
printf '%s\n' "$password_gate" | grep -Fq 'right:15-16:set' || fail "新密码按钮坐标错误"
grep -Fq 'ensure_gui_password_ready' "$PROJECT_ROOT/core/gui.sh" || fail "图形入口未强制准备密码记录"

touch_button="$(sed -n '/^ui_touch_button()/,/^}/p' "$PROJECT_ROOT/core/ui.sh")"
printf '%s\n' "$touch_button" | grep -Fq '· %s' || fail "按钮说明没有放到功能名称后方"
if printf '%s\n' "$touch_button" | grep -Fq 'row + 1'; then
    fail "按钮说明仍被拆分到下一行"
fi

installer_entry="$(sed -n '/^if download_bootstrap/,/^fi$/p' "$PROJECT_ROOT/i")"
printf '%s\n' "$installer_entry" | sed -n '1p' | grep -Fq 'GITEE_URL' || fail "短安装入口没有优先使用 Gitee"
printf '%s\n' "$installer_entry" | grep -Fq 'GITHUB_URL' || fail "短安装入口缺少 GitHub 备用源"
printf '%s\n' "$installer_entry" | grep -Fq 'DOMAIN_URL' || fail "短安装入口缺少域名备用源"

frame="$(sed -n '/^draw_category_frame()/,/^}/p' "$PROJECT_ROOT/core/ui.sh")"
for entry in \
    'ui_sidebar_item 2 init "◆ 新机必备"' \
    'ui_sidebar_item 5 software "▣ 常用软件"' \
    'ui_sidebar_item 8 games "✦ 游戏与插件"' \
    'ui_sidebar_item 11 network "⌁ 网络与应用商店"' \
    'ui_sidebar_item 14 support "▤ 维护与帮助"' \
    'ui_sidebar_item 18 advanced "! 系统与密码"' \
    'ui_sidebar_item 22 exit "× 退出工具箱"'; do
    printf '%s\n' "$frame" | grep -Fq -- "$entry" || fail "侧栏缺少：$entry"
done

[ "$(printf '%s\n' "$frame" | grep -c 'ui_sidebar_item')" -eq 7 ] || fail "侧栏入口数量错误"

touch_nav="$(sed -n '/^read_touch_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
for mapping in \
    'left:2-3:nav-init' \
    'left:5-6:nav-software' \
    'left:8-9:nav-games' \
    'left:11-12:nav-network' \
    'left:14-15:nav-help' \
    'left:18-19:nav-advanced' \
    'left:22-23:nav-exit'; do
    printf '%s\n' "$touch_nav" | grep -Fq -- "$mapping" || fail "导航坐标缺失：$mapping"
done

software="$(sed -n '/^common_software_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
printf '%s\n' "$software" | grep -Fq 'draw_category_frame software "常用软件" "安装聊天、浏览器和远程工具" 0' || fail "常用软件仍显示与首个按钮重叠的分类文字"
printf '%s\n' "$software" | grep -Fq 'ui_touch_button 23' || fail "常用软件返回首页文字行错误"
printf '%s\n' "$software" | grep -Fq 'right:23-24:home' || fail "常用软件返回首页坐标错误"
printf '%s\n' "$software" | grep -Fq 'ui_touch_button 9' || fail "Firefox按钮行错误"
printf '%s\n' "$software" | grep -Fq 'right:9-10:browser' || fail "Firefox触控坐标错误"
printf '%s\n' "$software" | grep -Fq 'modules/software.sh" browser' || fail "Firefox安装动作缺失"

games="$(sed -n '/^game_environment_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
printf '%s\n' "$games" | grep -Fq 'draw_category_frame games "游戏与插件｜插件商城" "浏览插件商城、运行组件和启动器" 0' || fail "游戏与插件仍显示与首个按钮重叠的分类文字"

home="$(sed -n '/^home_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
for aligned_line in \
    'ui_panel_line 2' \
    'ui_panel_line 5' \
    'ui_panel_line 8' \
    'ui_panel_line 11' \
    'ui_panel_line 14' \
    'ui_panel_line 18'; do
    printf '%s\n' "$home" | grep -Fq "$aligned_line" || fail "首页说明没有与左侧分类对齐：$aligned_line"
done

changelog="$(sed -n '/^changelog_menu()/,/^}/p' "$PROJECT_ROOT/main.sh")"
printf '%s\n' "$changelog" | grep -Fq 'CHANGELOG.md' || fail "更新日志文件映射缺失"
printf '%s\n' "$changelog" | grep -Fq 'VERSION' || fail "更新日志版本映射缺失"

echo "PASS: 六分类触控坐标、返回首页和基础界面配置正确"
