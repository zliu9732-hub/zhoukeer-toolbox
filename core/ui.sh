#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../utils/colors.sh"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

UI_SIDEBAR_WIDTH=29
UI_SEPARATOR_COL=32
UI_PANEL_COL=35
UI_LAST_ROW=27

logo() {
echo -e "${BLUE}"
cat << "EOL"
====================================
   📦 周克儿工具箱 v4
   Steam Deck Toolbox
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

ui_panel_line() {
    local row="$1"
    local color="$2"
    local text="$3"

    ui_move "$row" "$UI_PANEL_COL"
    printf '%b%s%b' "$color" "$text" "$NC"
}

ui_fill_sidebar_row() {
    local row="$1"
    local color="$2"

    ui_move "$row" 2
    printf '\033[%sm%*s\033[0m' "$color" "$UI_SIDEBAR_WIDTH" ""
}

# 每个分类是两行高的大按钮，内部值只用于程序识别，界面不显示字母或数字。
ui_sidebar_item() {
    local row="$1"
    local value="$2"
    local label="$3"
    local selected="$4"
    local background='48;5;24'
    local foreground='1;97;48;5;24'

    if [ "$value" = "$selected" ]; then
        background='48;5;45'
        foreground='1;30;48;5;45'
    fi

    ui_fill_sidebar_row "$row" "$background"
    ui_fill_sidebar_row "$((row + 1))" "$background"
    ui_move "$row" 4
    printf '\033[%sm%s\033[0m' "$foreground" "$label"
}

ui_touch_button() {
    local row="$1"
    local color="$2"
    local label="$3"
    local hint="${4:-}"

    ui_move "$row" "$UI_PANEL_COL"
    printf '%b%-50s%b' "$color" "  $label" "$NC"
    ui_move "$((row + 1))" "$UI_PANEL_COL"
    printf '%b%-50s%b' "$color" "  $hint" "$NC"
}

draw_category_frame() {
    local selected="${1:-}"
    local title="$2"
    local subtitle="$3"
    local row

    printf '\033[0m\033[2J\033[H'

    row=2
    while [ "$row" -le "$UI_LAST_ROW" ]; do
        ui_fill_sidebar_row "$row" '48;5;24'
        row=$((row + 1))
    done

    ui_sidebar_item 2 init "⭐ 新机初始化" "$selected"
    ui_sidebar_item 5 software "💻 常用软件" "$selected"
    ui_sidebar_item 8 remote "📡 远程协助" "$selected"
    ui_sidebar_item 11 plugins "🧩 插件商城" "$selected"
    ui_sidebar_item 14 settings "⚙  系统设置" "$selected"
    ui_sidebar_item 17 optimize "🚀 系统优化" "$selected"
    ui_sidebar_item 20 update "🔄 工具箱更新" "$selected"
    ui_sidebar_item 24 exit "✖  退出工具箱" "$selected"

    row=2
    while [ "$row" -le "$UI_LAST_ROW" ]; do
        ui_move "$row" "$UI_SEPARATOR_COL"
        printf '\033[38;5;45m│\033[0m'
        row=$((row + 1))
    done

    ui_panel_line 2 '\033[1;38;5;45m' "📦 周克儿工具箱 V4"
    ui_panel_line 3 '\033[1;38;5;255m' "Steam Deck Toolbox"
    ui_panel_line 4 '\033[38;5;45m' "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    ui_panel_line 6 '\033[1;38;5;220m' "$title"
    ui_panel_line 7 '\033[1;38;5;255m' "$subtitle"
}

ui_prompt() {
    ui_move "$UI_LAST_ROW" "$UI_PANEL_COL"
    printf '\033[0m\033[2K\033[1;38;5;45m请用触屏或触控板点击大按钮\033[0m'
}

enable_mouse_tracking() {
    # 1000: 按键事件；1002: 按下后移动；1006: SGR 坐标，兼容 Konsole 触屏。
    printf '\033[?25l\033[?1000h\033[?1002h\033[?1006h'
}

disable_mouse_tracking() {
    printf '\033[?1006l\033[?1002l\033[?1000l\033[?25h'
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
