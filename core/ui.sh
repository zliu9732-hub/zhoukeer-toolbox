#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../utils/colors.sh"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

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

    ui_move "$row" 30
    printf '%b%s%b' "$color" "$text" "$NC"
}

ui_sidebar_item() {
    local row="$1"
    local key="$2"
    local label="$3"
    local selected="$4"

    ui_move "$row" 2
    if [ "$key" = "$selected" ]; then
        printf '\033[48;5;45m%24s\033[0m' ""
        ui_move "$row" 3
        printf '\033[1;30;48;5;45m%s. %s\033[0m' "$key" "$label"
    else
        printf '\033[48;5;24m%24s\033[0m' ""
        ui_move "$row" 3
        printf '\033[1;97;48;5;24m%s. %s\033[0m' "$key" "$label"
    fi
}

draw_category_frame() {
    local selected="${1:-}"
    local title="$2"
    local subtitle="$3"
    local row

    printf '\033[0m\033[2J\033[H'

    row=2
    while [ "$row" -le 22 ]; do
        ui_move "$row" 2
        printf '\033[48;5;24m%24s\033[0m' ""
        row=$((row + 1))
    done

    ui_sidebar_item 3 A "新机初始化" "$selected"
    ui_sidebar_item 5 B "常用软件" "$selected"
    ui_sidebar_item 7 C "远程协助" "$selected"
    ui_sidebar_item 9 D "插件商城" "$selected"
    ui_sidebar_item 11 E "系统设置" "$selected"
    ui_sidebar_item 13 F "系统优化" "$selected"
    ui_sidebar_item 15 G "工具箱更新" "$selected"
    ui_sidebar_item 20 X "退出" "$selected"

    ui_move 2 27
    printf '\033[38;5;45m│\033[0m'
    row=3
    while [ "$row" -le 22 ]; do
        ui_move "$row" 27
        printf '\033[38;5;45m│\033[0m'
        row=$((row + 1))
    done

    ui_panel_line 2 '\033[1;38;5;45m' "📦 周克儿工具箱 V4"
    ui_panel_line 3 '\033[38;5;250m' "Steam Deck Toolbox"
    ui_panel_line 4 '\033[38;5;45m' "────────────────────────────────────────────"
    ui_panel_line 6 '\033[1;38;5;220m' "$title"
    ui_panel_line 7 '\033[38;5;250m' "$subtitle"
}

ui_prompt() {
    ui_move 23 2
    printf '\033[0m\033[2K\033[1;38;5;45m可直接点击菜单，也可使用键盘：\033[0m'
}

enable_mouse_tracking() {
    printf '\033[?1000h\033[?1006h'
}

disable_mouse_tracking() {
    printf '\033[?1000l\033[?1006l'
}

read_ui_event() {
    local char
    local first
    local index
    local old_ifs
    local payload
    local sequence=""

    UI_EVENT_TYPE=""
    UI_EVENT_KEY=""
    UI_EVENT_X=""
    UI_EVENT_Y=""

    IFS= read -rsn1 first || return 1
    if [ "$first" != $'\033' ]; then
        UI_EVENT_TYPE="key"
        UI_EVENT_KEY="$first"
        return 0
    fi

    index=0
    while [ "$index" -lt 32 ]; do
        IFS= read -rsn1 -t 1 char || break
        sequence="$sequence$char"
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
            UI_EVENT_TYPE="click"
            return 0
            ;;
    esac

    UI_EVENT_TYPE="key"
    UI_EVENT_KEY="$first"
}

read_menu_choice() {
    local mapping
    local region
    local row
    local value

    while read_ui_event; do
        if [ "$UI_EVENT_TYPE" = "key" ]; then
            printf '%s\n' "$UI_EVENT_KEY"
            return 0
        fi

        for mapping in "$@"; do
            region="${mapping%%:*}"
            mapping="${mapping#*:}"
            row="${mapping%%:*}"
            value="${mapping#*:}"

            [ "$UI_EVENT_Y" = "$row" ] || continue
            case "$region" in
                left) [ "$UI_EVENT_X" -le 26 ] || continue ;;
                right) [ "$UI_EVENT_X" -ge 28 ] || continue ;;
                any) ;;
                *) continue ;;
            esac
            printf '%s\n' "$value"
            return 0
        done
    done
    return 1
}
