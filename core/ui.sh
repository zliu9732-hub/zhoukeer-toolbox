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
    printf '\033[0m\033[2K\033[1;38;5;45m请选择：\033[0m'
}
