#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../utils/colors.sh"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

UI_SIDEBAR_WIDTH=31
UI_SEPARATOR_COL=34
UI_PANEL_COL=37
UI_LAST_ROW=24

ui_detect_layout() {
    local columns="${COLUMNS:-}"

    if ! [[ "$columns" =~ ^[0-9]+$ ]]; then
        columns="$(tput cols 2>/dev/null || printf '120')"
    fi

    # 小屏掌机常见的窄终端下收紧导航栏，保留右侧至少 50 列内容空间。
    if [ "$columns" -le 104 ]; then
        UI_SIDEBAR_WIDTH=27
        UI_SEPARATOR_COL=30
        UI_PANEL_COL=33
    fi
}

ui_detect_layout

logo() {
echo -e "${BLUE}"
cat << "EOL"
====================================
   📦 周克儿工具箱 v4
   SteamOS Handheld Toolbox
====================================
EOL
echo -e "${NC}"
}

print_header() {
    clear
    logo
}

print_section_title() {
    echo "------------------------------------"
    echo " $1"
    echo "------------------------------------"
}

ui_move() {
    printf '\033[%s;%sH' "$1" "$2"
}

ui_reset_screen() {
    # 重置滚动区域并清除可视区和历史残影，避免启动更新输出挤乱首屏。
    printf '\033[0m\033[r\033[3J\033[2J\033[H'
}

# 将旧页面传入的多种强调色统一成红、白、灰三档，和红黑背景保持一致。
ui_resolve_text_color() {
    local requested="$1"

    UI_THEME_COLOR='\033[38;5;255m'
    case "$requested" in
        *'5;220'*|*'5;203'*|*'5;160'*) UI_THEME_COLOR='\033[38;5;203m' ;;
        *'5;114'*) UI_THEME_COLOR='\033[38;5;255m' ;;
        *'5;45'*) UI_THEME_COLOR='\033[38;5;250m' ;;
    esac
}

ui_panel_line() {
    local row="$1"
    local color="$2"
    local text="$3"

    ui_resolve_text_color "$color"
    ui_move "$row" "$UI_PANEL_COL"
    # 文字使用短暗底，保留壁纸氛围但不再让人物图案干扰阅读。
    printf '\033[48;5;234m %b%s \033[0m' "$UI_THEME_COLOR" "$text"
}

# 每个分类是两行高的大按钮，内部值只用于程序识别，界面不显示字母或数字。
ui_sidebar_item() {
    local row="$1"
    local value="$2"
    local label="$3"
    local selected="$4"
    local show_separator="${5:-1}"
    local marker='  '
    local foreground='\033[38;5;252;48;5;234m'
    local separator='\033[38;5;239m'

    if [ "$value" = "$selected" ]; then
        marker='▶ '
        foreground='\033[1;38;5;255;48;5;52m'
        separator='\033[38;5;203m'
    fi

    # 左侧用短暗底建立稳定导航层级，选中项只使用低饱和红色强调。
    ui_move "$row" 3
    printf '%b %s%s %b' "$foreground" "$marker" "$label" "$NC"
    if [ "$show_separator" = "1" ]; then
        ui_move "$((row + 1))" 3
        printf '%b──────────────────────────%b' "$separator" "$NC"
    fi
}

ui_touch_button() {
    local row="$1"
    local color="$2"
    local label="$3"
    local hint="${4:-}"
    local label_color='\033[38;5;255m'
    local rail_color='\033[38;5;203m'

    # 名称与说明放在同一行；仍保留两行高的点击区域，兼顾整洁和触控命中率。
    case "$color" in
        *'48;5;114'*) label_color='\033[38;5;255m' ;;
        *'48;5;160'*) label_color='\033[38;5;255m'; rail_color='\033[38;5;203m' ;;
        *'48;5;238'*) label_color='\033[38;5;250m'; rail_color='\033[38;5;245m' ;;
    esac

    ui_move "$row" "$UI_PANEL_COL"
    # 临时关闭终端自动换行，过长说明会在右边缘截断，不会挤乱下一行。
    printf '\033[?7l\033[48;5;234m%b▌ %b%s' \
        "$rail_color" "$label_color" "$label"
    if [ -n "$hint" ]; then
        printf '\033[38;5;245m · %s' "$hint"
    fi
    printf ' \033[0m\033[?7h'
}

draw_category_frame() {
    local selected="${1:-}"
    local title="$2"
    local subtitle="$3"
    local show_context="${4:-1}"
    local row

    ui_discard_pending_input
    ui_reset_screen

    ui_move 1 3
    printf '\033[1;38;5;245m功能导航\033[0m'

    # 两行点击区配合更高窗口，为每一类功能留出清晰的阅读间距。
    ui_sidebar_item 2 init "◆ 新机必备" "$selected"
    ui_sidebar_item 5 software "▣ 常用软件" "$selected"
    ui_sidebar_item 8 games "✦ 游戏与插件" "$selected"
    ui_sidebar_item 11 network "⌁ 网络与应用商店" "$selected"
    ui_sidebar_item 14 support "▤ 维护与帮助" "$selected"
    ui_sidebar_item 18 advanced "! 系统与密码" "$selected" 0
    ui_sidebar_item 22 exit "× 退出工具箱" "$selected" 0

    row=2
    while [ "$row" -le "$UI_LAST_ROW" ]; do
        ui_move "$row" "$UI_SEPARATOR_COL"
        printf '\033[38;5;239m│\033[0m'
        row=$((row + 1))
    done

    if [ -n "$title" ]; then
        ui_panel_line 2 '\033[1;38;5;203m' "◆ 周克儿工具箱  ·  V4"
        ui_panel_line 3 '\033[1;38;5;45m' "STEAMOS 掌机  /  中文工具"
        ui_panel_line 4 '\033[38;5;203m' "────────────────────────────────────────"
        if [ "$show_context" = "1" ]; then
            ui_panel_line 5 '\033[1;38;5;220m' "▌ $title"
            ui_panel_line 6 '\033[1;38;5;45m' "  $subtitle"
        fi
    fi
}

draw_disclaimer_frame() {
    ui_discard_pending_input
    ui_reset_screen

    ui_move 2 6
    printf '\033[1;38;5;203;48;5;234m ◆ 周克儿工具箱  ·  V4 \033[0m'
    ui_move 3 6
    printf '\033[38;5;203m────────────────────────────────────────────────────────────\033[0m'
    ui_move 5 6
    printf '\033[1;38;5;255;48;5;234m ▌ 使用说明与免责声明 \033[0m'
    ui_move 6 6
    printf '\033[38;5;250;48;5;234m  请阅读以下内容，知悉后再开始使用 \033[0m'
}

ui_disclaimer_line() {
    local row="$1"
    local color="$2"
    local text="$3"

    ui_resolve_text_color "$color"
    ui_move "$row" 6
    printf '\033[48;5;234m %b%s \033[0m' "$UI_THEME_COLOR" "$text"
}

ui_disclaimer_button() {
    local row="$1"
    local color="$2"
    local label="$3"
    local hint="$4"

    ui_resolve_text_color "$color"
    ui_move "$row" 8
    printf '\033[48;5;234m%b▌  %s \033[0m' "$UI_THEME_COLOR" "$label"
    ui_move "$((row + 1))" 11
    printf '\033[48;5;234m\033[38;5;250m  %s \033[0m' "$hint"
}

ui_prompt() {
    ui_move "$UI_LAST_ROW" "$UI_PANEL_COL"
    printf '\033[0m\033[2K\033[38;5;255;48;5;234m 触屏或触控板点击功能 \033[0m'
}

enable_mouse_tracking() {
    # 1000: 按键事件；1002: 按下后移动；1006: SGR 坐标，兼容 Konsole 触屏。
    printf '\033[?1003l\033[?1015l\033[?25l\033[?1000h\033[?1002h\033[?1006h'
}

disable_mouse_tracking() {
    printf '\033[?1006l\033[?1015l\033[?1003l\033[?1002l\033[?1000l\033[?25h'
}

ui_discard_pending_input() {
    local ignored

    # 切换页面后，触控板的松开事件有时会迟到；丢弃它，避免显示为文本残留。
    while IFS= read -rsn1 -t 0.01 ignored; do
        :
    done
}

char_code() {
    LC_CTYPE=C printf '%d' "'$1"
}

read_ui_event() {
    local button_char
    local char
    local first
    local index
    local old_ifs
    local payload
    local sequence=""
    local x_char
    local y_char

    UI_EVENT_TYPE=""
    UI_EVENT_BUTTON=""
    UI_EVENT_KEY=""
    UI_EVENT_X=""
    UI_EVENT_Y=""

    IFS= read -rsn1 first || return 1
    if [ "$first" != $'\033' ]; then
        # 触控界面故意忽略所有键盘输入，避免数字键与触屏冲突。
        UI_EVENT_TYPE="ignored-key"
        return 0
    fi

    index=0
    while [ "$index" -lt 32 ]; do
        IFS= read -rsn1 -t 1 char || break
        sequence="$sequence$char"

        # 旧式 X10 鼠标事件以 ESC [ M 开头，后面还有三个坐标字节。
        if [ "$sequence" = '[M' ]; then
            IFS= read -rsn1 -t 1 button_char || return 0
            IFS= read -rsn1 -t 1 x_char || return 0
            IFS= read -rsn1 -t 1 y_char || return 0
            UI_EVENT_BUTTON=$(( $(char_code "$button_char") - 32 ))
            UI_EVENT_X=$(( $(char_code "$x_char") - 32 ))
            UI_EVENT_Y=$(( $(char_code "$y_char") - 32 ))
            if [ $((UI_EVENT_BUTTON & 3)) -eq 0 ] && \
                [ $((UI_EVENT_BUTTON & 96)) -eq 0 ]; then
                UI_EVENT_TYPE="click"
            else
                UI_EVENT_TYPE="ignored-mouse"
            fi
            return 0
        fi

        case "$char" in
            M|m) break ;;
        esac
        index=$((index + 1))
    done

    case "$sequence" in
        '[<'*M)
            payload="${sequence#'[<'}"
            payload="${payload%M}"
            old_ifs="$IFS"
            IFS=';'
            # shellcheck disable=SC2162
            read UI_EVENT_BUTTON UI_EVENT_X UI_EVENT_Y <<EOF
$payload
EOF
            IFS="$old_ifs"
            # 只响应主指针按下，忽略滚轮、右键和拖动事件。
            if [ $((UI_EVENT_BUTTON & 3)) -eq 0 ] && \
                [ $((UI_EVENT_BUTTON & 96)) -eq 0 ]; then
                UI_EVENT_TYPE="click"
            else
                UI_EVENT_TYPE="ignored-mouse"
            fi
            return 0
            ;;
        '[<'*m)
            # 松开事件不再触发操作，避免一次触摸连续打开两层菜单。
            UI_EVENT_TYPE="release"
            return 0
            ;;
    esac

    UI_EVENT_TYPE="ignored-key"
}

read_touch_click() {
    while read_ui_event; do
        [ "$UI_EVENT_TYPE" = "click" ] || continue
        return 0
    done
    return 1
}

read_menu_choice() {
    local mapping
    local region
    local row_end
    local row_spec
    local row_start
    local value

    while read_ui_event; do
        [ "$UI_EVENT_TYPE" = "click" ] || continue

        for mapping in "$@"; do
            region="${mapping%%:*}"
            mapping="${mapping#*:}"
            row_spec="${mapping%%:*}"
            value="${mapping#*:}"
            row_start="${row_spec%-*}"
            row_end="${row_spec#*-}"
            [ "$row_start" = "$row_spec" ] && row_end="$row_start"

            [ "$UI_EVENT_Y" -ge "$row_start" ] 2>/dev/null || continue
            [ "$UI_EVENT_Y" -le "$row_end" ] 2>/dev/null || continue
            case "$region" in
                left) [ "$UI_EVENT_X" -le "$UI_SIDEBAR_WIDTH" ] || continue ;;
                right) [ "$UI_EVENT_X" -ge "$UI_PANEL_COL" ] || continue ;;
                any) ;;
                *) continue ;;
            esac
            printf '%s\n' "$value"
            return 0
        done
    done
    return 1
}
