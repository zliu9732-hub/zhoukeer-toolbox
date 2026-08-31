#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../utils/colors.sh"
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

UI_SIDEBAR_WIDTH=31
UI_SEPARATOR_COL=34
UI_PANEL_COL=37
UI_LAST_ROW=24
UI_PREFERRED_COLUMNS=120
UI_PREFERRED_ROWS=32
UI_LAYOUT_RETRY_COUNT=20
UI_LAYOUT_RETRY_INTERVAL=0.2
UI_COLUMNS=120
UI_ROWS=24
UI_CONTENT_ROWS=24
UI_PANEL_WIDTH=81
UI_RECORDING=0
UI_REPLAYING=0
UI_DRAW_COUNT=0
UI_DRAW_FUNCTION=()
UI_DRAW_ARG1=()
UI_DRAW_ARG2=()
UI_DRAW_ARG3=()
UI_DRAW_ARG4=()
UI_DEFERRED=0
UI_GRID=0
UI_HOME=0
UI_TERMINAL_OUTPUT_READY=0
UI_LEFT_TOP=() UI_LEFT_BOTTOM=() UI_LEFT_COL=() UI_LEFT_WIDTH=()
UI_RIGHT_TOP=() UI_RIGHT_BOTTOM=() UI_RIGHT_COL=() UI_RIGHT_WIDTH=()
TOOLBOX_VERSION="$(tr -d '\r\n' < "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSION" 2>/dev/null || true)"
[ -n "$TOOLBOX_VERSION" ] || TOOLBOX_VERSION="?"

ui_detect_layout() {
    local columns rows size

    # 优先读取实际 TTY，避免最大化后继承的 COLUMNS/LINES 仍是旧值。
    size="$(stty size 2>/dev/null || true)"
    read -r rows columns <<< "$size"
    if ! [[ "$columns" =~ ^[1-9][0-9]{0,3}$ ]]; then
        columns="${COLUMNS:-$(tput cols 2>/dev/null || true)}"
    fi
    if ! [[ "$rows" =~ ^[1-9][0-9]{0,3}$ ]]; then
        rows="${LINES:-$(tput lines 2>/dev/null || true)}"
    fi
    [[ "$columns" =~ ^[1-9][0-9]{0,3}$ ]] || columns=120
    [[ "$rows" =~ ^[1-9][0-9]{0,3}$ ]] || rows=24
    UI_COLUMNS="$columns"
    UI_ROWS="$rows"
    UI_CONTENT_ROWS=$((rows - 2))
    [ "$UI_CONTENT_ROWS" -ge "$UI_LAST_ROW" ] || UI_CONTENT_ROWS="$UI_LAST_ROW"

    # 左侧约占四分之一宽度；每次重算，缩小后再放大也能恢复。
    UI_SEPARATOR_COL=$((columns / 4 + 4))
    [ "$UI_SEPARATOR_COL" -ge 30 ] || UI_SEPARATOR_COL=30
    UI_SIDEBAR_WIDTH=$((UI_SEPARATOR_COL - 3))
    UI_PANEL_COL=$((UI_SEPARATOR_COL + 3))
    UI_PANEL_WIDTH=$((columns - UI_PANEL_COL - 1))
    [ "$UI_PANEL_WIDTH" -ge 1 ] || UI_PANEL_WIDTH=1
    UI_LAYOUT_USABLE=1
    if [ "$rows" -lt "$UI_LAST_ROW" ] || [ "$columns" -lt 70 ]; then
        UI_LAYOUT_USABLE=0
    fi
}

ui_detect_layout

ui_terminal_rows() {
    local rows

    rows="$(tput lines 2>/dev/null || true)"
    if ! [[ "$rows" =~ ^[0-9]+$ ]]; then
        rows="${LINES:-0}"
    fi
    case "$rows" in
        ''|*[!0-9]*) rows=0 ;;
    esac
    printf '%s\n' "$rows"
}

ui_request_preferred_canvas() {
    # Konsole 偶尔会先按上次的矮窗口尺寸创建终端；请求标准画布后再绘制，
    # 否则第 17 行以下的“系统设置与双系统”等入口会被窗口底部裁掉。
    printf '\033[8;%s;%st' "$UI_PREFERRED_ROWS" "$UI_PREFERRED_COLUMNS"
}

ui_wait_for_minimum_canvas() {
    local rows attempt=0

    while [ "$attempt" -lt "$UI_LAYOUT_RETRY_COUNT" ]; do
        rows="$(ui_terminal_rows)"
        [ "$rows" -ge "$UI_LAST_ROW" ] 2>/dev/null && return 0
        ui_request_preferred_canvas
        [ "$UI_LAYOUT_RETRY_INTERVAL" = "0" ] || sleep "$UI_LAYOUT_RETRY_INTERVAL"
        attempt=$((attempt + 1))
    done
    return 1
}

ui_apply_screen_font() {
    local font_size="${ZHOUKEER_FONT_SIZE:-}"

    case "$font_size" in
        ''|*[!0-9]*) return 0 ;;
    esac
    if command -v konsoleprofile >/dev/null 2>&1; then
        konsoleprofile "Font=Noto Sans Mono CJK SC,$font_size" >/dev/null 2>&1 || true
    fi
}

logo() {
    echo -e "${BLUE}"
    echo "===================================="
    echo "    📦 Renkit v${TOOLBOX_VERSION}"
    echo "   ${RENKIT_CONSOLE_TITLE:-SteamOS Handheld Toolbox}"
    echo "===================================="
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
    ui_scale_row "$1"
    ui_move_absolute "$UI_SCALED_ROW" "$2"
}

# 菜单保留原来的 24 行逻辑坐标；绘制和命中测试使用同一个变换。
ui_scale_row() {
    if [ "$1" -gt "$UI_LAST_ROW" ]; then
        UI_SCALED_ROW=$((UI_CONTENT_ROWS + 1))
    else
        UI_SCALED_ROW=$((1 + ($1 - 1) * (UI_CONTENT_ROWS - 1) / (UI_LAST_ROW - 1)))
    fi
}

ui_move_absolute() {
    printf '\033[%s;%sH' "$1" "$2"
}

ui_rule() {
    local rule
    printf -v rule '%*s' "$1" ''
    printf '%s' "${rule// /─}"
}

# 先收集当前页的显示内容，再决定排版；动作仍由原来的逻辑行号识别。
# 含额外说明的页面保持纵向顺序，只有纯按钮页使用双列卡片。
ui_prepare_layout() {
    local index row count=0 notes=0 stride height slot=0 grid_rows card_width
    UI_GRID=0 UI_HOME=0
    UI_LEFT_TOP=() UI_LEFT_BOTTOM=() UI_LEFT_COL=() UI_LEFT_WIDTH=()
    UI_RIGHT_TOP=() UI_RIGHT_BOTTOM=() UI_RIGHT_COL=() UI_RIGHT_WIDTH=()
    [ "${UI_DRAW_FUNCTION[0]:-}" = draw_category_frame ] || return 0
    for ((index=1; index<UI_DRAW_COUNT; index++)); do
        case "${UI_DRAW_FUNCTION[index]}" in
            ui_touch_button) count=$((count + 1)) ;;
            ui_panel_line) notes=$((notes + 1)) ;;
        esac
    done
    if [ "$count" -eq 0 ] && [ "$notes" -eq 8 ] && [ -z "${UI_DRAW_ARG1[0]}${UI_DRAW_ARG2[0]}" ]; then
        UI_HOME=1
        count="$notes"
    fi
    # 侧栏共用两侧竖线和相邻横线，均分可用高度，底边延伸到页脚上方。
    # 分隔线归下一个选项，末项包含底边，点击范围不重叠。
    for ((index=0; index<9; index++)); do
        row=$((2 + index * 2))
        UI_LEFT_TOP[row]=$((2 + index * (UI_CONTENT_ROWS - 2) / 9))
        UI_LEFT_BOTTOM[row]=$((1 + (index + 1) * (UI_CONTENT_ROWS - 2) / 9))
        [ "$index" -ne 8 ] || UI_LEFT_BOTTOM[row]="$UI_CONTENT_ROWS"
        UI_LEFT_COL[row]=3
        UI_LEFT_WIDTH[row]=$((UI_SIDEBAR_WIDTH - 2))
    done
    if { [ "$notes" -eq 0 ] || [ "$UI_HOME" = 1 ]; } && [ "$count" -ge 4 ] && [ "$UI_COLUMNS" -ge 110 ]; then
        UI_GRID=1
        grid_rows=$(((count + 1) / 2))
        stride=$(((UI_CONTENT_ROWS - 3) / grid_rows))
        height="$stride"
        [ "$height" -le 4 ] || height=$((height - 1))
        [ "$height" -le 6 ] || height=6
        card_width=$(((UI_PANEL_WIDTH - 3) / 2))
    fi
    for ((index=1; index<UI_DRAW_COUNT; index++)); do
        if [ "${UI_DRAW_FUNCTION[index]}" != ui_touch_button ]; then
            [ "$UI_HOME" = 1 ] && [ "${UI_DRAW_FUNCTION[index]}" = ui_panel_line ] || continue
        fi
        row="${UI_DRAW_ARG1[index]}"
        UI_RIGHT_COL[row]="$UI_PANEL_COL"
        UI_RIGHT_WIDTH[row]="$UI_PANEL_WIDTH"
        if [ "$UI_GRID" = 1 ]; then
            UI_RIGHT_TOP[row]=$((4 + (slot / 2) * stride))
            UI_RIGHT_BOTTOM[row]=$((UI_RIGHT_TOP[row] + height - 1))
            if [ "$slot" -lt "$((count - 1))" ] || [ "$((count % 2))" -eq 0 ]; then
                UI_RIGHT_COL[row]=$((UI_PANEL_COL + (slot % 2) * (card_width + 3)))
                UI_RIGHT_WIDTH[row]="$card_width"
            fi
        else
            ui_scale_row "$row"
            UI_RIGHT_TOP[row]="$UI_SCALED_ROW"
            ui_scale_row "$((row + 2))"
            UI_RIGHT_BOTTOM[row]=$((UI_SCALED_ROW - 1))
        fi
        slot=$((slot + 1))
    done
}

ui_button_rect() {
    local row="$2"
    case "$1" in
        left)
            [ -n "${UI_LEFT_TOP[row]:-}" ] || return 1
            UI_HIT_TOP="${UI_LEFT_TOP[row]}" UI_HIT_BOTTOM="${UI_LEFT_BOTTOM[row]}"
            UI_HIT_COL="${UI_LEFT_COL[row]}" UI_HIT_WIDTH="${UI_LEFT_WIDTH[row]}" ;;
        right)
            [ -n "${UI_RIGHT_TOP[row]:-}" ] || return 1
            UI_HIT_TOP="${UI_RIGHT_TOP[row]}" UI_HIT_BOTTOM="${UI_RIGHT_BOTTOM[row]}"
            UI_HIT_COL="${UI_RIGHT_COL[row]}" UI_HIT_WIDTH="${UI_RIGHT_WIDTH[row]}" ;;
        *) return 1 ;;
    esac
}

# 框按当前页的矩形绘制；未重排页面沿用两行逻辑触控区，不借用说明行。
# 两行高时名称嵌在上边框；空间充足时名称位于框内，保持中文完整。
ui_button_box() {
    local row="$1" col="$2" width="$3"
    local border="${4:-\033[38;5;131m}" span="${5:-2}" region="${6:-}"
    local top bottom current
    ui_scale_row "$row"
    top="$UI_SCALED_ROW"
    ui_scale_row "$((row + span))"
    bottom=$((UI_SCALED_ROW - 1))
    if ui_button_rect "$region" "$row"; then
        top="$UI_HIT_TOP" bottom="$UI_HIT_BOTTOM"
        col="$UI_HIT_COL" width="$UI_HIT_WIDTH"
    fi
    UI_BOX_COL="$col" UI_BOX_WIDTH="$width"
    UI_BOX_TEXT_ROW=$(((top + bottom) / 2))
    UI_BOX_HINT_ROW=0
    if [ "$((bottom - top))" -ge 3 ]; then
        UI_BOX_TEXT_ROW=$(((top + bottom - 1) / 2))
        UI_BOX_HINT_ROW=$((UI_BOX_TEXT_ROW + 1))
    fi
    printf '\033[?7l'
    for ((current=top; current<=bottom; current++)); do
        ui_move_absolute "$current" "$col"
        printf '%b' "$border"
        if [ "$current" -eq "$top" ]; then
            printf '╭'; ui_rule "$((width - 2))"; printf '╮'
        elif [ "$current" -eq "$bottom" ]; then
            printf '╰'; ui_rule "$((width - 2))"; printf '╯'
        else
            printf '│%*s│' "$((width - 2))" ''
        fi
    done
    printf '\033[0m\033[?7h'
}

# 静态中文菜单按终端单元格限宽；其他非 ASCII 字符保守预留两格，
# 避免中文字或 emoji 被切成半个，或长说明覆盖右边框。无需外部进程。
ui_fit_button_text() {
    local text="$1" limit="$2" character width
    local LC_COLLATE=C
    UI_FIT_TEXT=''
    UI_FIT_USED=0
    while [ -n "$text" ]; do
        character="${text:0:1}"
        case "$character" in
            [[:cntrl:]]) text="${text:1}"; continue ;;
            [\ -~]|◆|▣|✦|▦|◎|▧|×|▶|›|·|…|—|–|→|←|✓|✗) width=1 ;;
            *) width=2 ;;
        esac
        [ "$((UI_FIT_USED + width))" -le "$limit" ] || break
        UI_FIT_TEXT="$UI_FIT_TEXT$character"
        UI_FIT_USED=$((UI_FIT_USED + width))
        text="${text:1}"
    done
}

ui_button_caption() {
    local col="$1" width="$2" color="$3" label="$4" hint="${5:-}"
    local remaining=$((width - 4))
    ui_move_absolute "$UI_BOX_TEXT_ROW" "$((col + 1))"
    printf '\033[?7l %b' "$color"
    ui_fit_button_text "$label" "$remaining"
    printf '%s' "$UI_FIT_TEXT"
    remaining=$((remaining - UI_FIT_USED))
    if [ -n "$hint" ]; then
        if [ "$UI_BOX_HINT_ROW" -gt 0 ]; then
            ui_move_absolute "$UI_BOX_HINT_ROW" "$((col + 1))"
            ui_fit_button_text "$hint" "$((width - 4))"
            printf ' \033[38;5;245m%s' "$UI_FIT_TEXT"
        elif [ "$remaining" -gt 3 ]; then
            ui_fit_button_text " · $hint" "$remaining"
            printf '\033[38;5;245m%s' "$UI_FIT_TEXT"
        fi
    fi
    printf ' \033[0m\033[?7h'
}

# 只保存界面函数的参数，缩放时重画当前页，不重跑菜单或功能模块。
# 不保存或执行拼接的 Shell 命令，也不改动调用方的 action ID。
ui_record_draw() {
    [ "$UI_RECORDING" = 1 ] && [ "$UI_REPLAYING" = 0 ] || return 0
    UI_DRAW_FUNCTION[UI_DRAW_COUNT]="$1"
    UI_DRAW_ARG1[UI_DRAW_COUNT]="${2:-}"
    UI_DRAW_ARG2[UI_DRAW_COUNT]="${3:-}"
    UI_DRAW_ARG3[UI_DRAW_COUNT]="${4:-}"
    UI_DRAW_ARG4[UI_DRAW_COUNT]="${5:-}"
    UI_DRAW_COUNT=$((UI_DRAW_COUNT + 1))
}

ui_begin_frame() {
    if [ "$UI_REPLAYING" = 0 ]; then
        # 在 choice=$(...) 捕获 stdout 前保存真正的终端输出。
        # FD 9 专供 UI 重绘使用；不能经启动器按行过滤的 stderr 绘制无换行帧。
        if [ -t 1 ]; then
            exec 9>&1
            UI_TERMINAL_OUTPUT_READY=1
        fi
        ui_wait_for_minimum_canvas || true
        ui_discard_pending_input
        UI_DRAW_COUNT=0
        UI_GRID=0 UI_HOME=0
    fi
    [ "$UI_REPLAYING" != 0 ] || ui_detect_layout
    UI_RECORDING=1
    ui_record_draw "$@"
    UI_RECORDING=0
    # 收集菜单时保留上一帧，统一绘制时再清屏，避免先显示旧排版再跳动。
    if [ "$UI_REPLAYING" = 0 ] && [ "$1" = draw_category_frame ]; then
        return 0
    fi
    ui_reset_screen
    if [ "$UI_LAYOUT_USABLE" = 0 ]; then
        printf '\033[?7l窗口太小，请放大至至少 70 列 × 24 行\033[?7h'
    fi
}

ui_redraw_if_resized() {
    local previous_size="$UI_COLUMNS:$UI_ROWS"
    [ "$UI_DRAW_COUNT" -gt 0 ] || return 1
    ui_detect_layout
    [ "$previous_size" != "$UI_COLUMNS:$UI_ROWS" ] || return 1
    ui_prepare_layout
    ui_replay_frame
}

ui_replay_frame() {
    local index function
    UI_DEFERRED=0
    UI_REPLAYING=1
    for ((index=0; index<UI_DRAW_COUNT; index++)); do
        function="${UI_DRAW_FUNCTION[index]}"
        case "$function" in
            draw_category_frame|draw_disclaimer_frame|ui_panel_line|ui_touch_button|ui_disclaimer_line|ui_disclaimer_button|ui_prompt)
                "$function" "${UI_DRAW_ARG1[index]}" "${UI_DRAW_ARG2[index]}" \
                    "${UI_DRAW_ARG3[index]}" "${UI_DRAW_ARG4[index]}" ;;
        esac
    done
    UI_REPLAYING=0
    return 0
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
    ui_record_draw ui_panel_line "$@"
    [ "$UI_DEFERRED" = 0 ] || return 0
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    local row="$1"
    local color="$2"
    local text="$3"

    if [ "$UI_HOME" = 1 ] && [[ "$text" = *'｜'* ]]; then
        ui_button_box "$row" "$UI_PANEL_COL" "$UI_PANEL_WIDTH" '\033[38;5;131m' 2 right
        ui_button_caption "$UI_BOX_COL" "$UI_BOX_WIDTH" '\033[1;38;5;255m' "${text%%｜*}" "${text#*｜}"
        return 0
    fi

    ui_resolve_text_color "$color"
    ui_move "$row" "$UI_PANEL_COL"
    printf '\033[?7l %b' "$UI_THEME_COLOR"
    case "$text" in
        ─*) ui_rule "$((UI_PANEL_WIDTH - 2))" ;;
        *) printf '%s' "$text" ;;
    esac
    printf ' \033[0m\033[?7h'
}

# 分类共用一个红色外框，横线逐项分隔；右侧继续使用独立卡片。
ui_sidebar_item() {
    local row="$1"
    local value="$2"
    local label="$3"
    local selected="$4"
    local current content_bottom
    local marker='  '
    local foreground='\033[38;5;250m'
    local border='\033[38;5;131m'

    # 去掉不同字体下容易显示为方块的装饰图形，名称和导航 ID 保持不变。
    label="${label#* }"

    if [ "$value" = "$selected" ]; then
        marker='› '
        foreground='\033[1;38;5;255m'
        border='\033[1;38;5;203m'
    fi

    ui_button_rect left "$row" || return 1
    UI_BOX_COL="$UI_HIT_COL" UI_BOX_WIDTH="$UI_HIT_WIDTH"
    content_bottom="$UI_HIT_BOTTOM"
    [ "$row" -ne 18 ] || content_bottom=$((content_bottom - 1))
    UI_BOX_TEXT_ROW=$(((UI_HIT_TOP + 1 + content_bottom) / 2)) UI_BOX_HINT_ROW=0
    printf '\033[?7l'
    ui_move_absolute "$UI_HIT_TOP" "$UI_BOX_COL"
    printf '\033[38;5;131m'
    if [ "$row" -eq 2 ]; then
        printf '╭'; ui_rule "$((UI_BOX_WIDTH - 2))"; printf '╮'
    else
        printf '├'; ui_rule "$((UI_BOX_WIDTH - 2))"; printf '┤'
    fi
    for ((current=UI_HIT_TOP+1; current<=content_bottom; current++)); do
        ui_move_absolute "$current" "$UI_BOX_COL"
        printf '%b│%*s│' "$border" "$((UI_BOX_WIDTH - 2))" ''
    done
    if [ "$row" -eq 18 ]; then
        ui_move_absolute "$UI_HIT_BOTTOM" "$UI_BOX_COL"
        printf '\033[38;5;131m╰'; ui_rule "$((UI_BOX_WIDTH - 2))"; printf '╯'
    fi
    printf '\033[0m\033[?7h'
    ui_button_caption "$UI_BOX_COL" "$UI_BOX_WIDTH" "$foreground" "$marker$label"
}

ui_touch_button() {
    ui_record_draw ui_touch_button "$@"
    [ "$UI_DEFERRED" = 0 ] || return 0
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    local row="$1"
    local color="$2"
    local label="$3"
    local hint="${4:-}"
    local label_color='\033[1;38;5;255m'
    local border='\033[38;5;131m'

    # 右侧边框统一为同一种红色；危险确认只加亮文字，不改变边框色。
    case "$color" in
        *'48;5;160'*) label_color='\033[1;38;5;203m' ;;
        *'48;5;238'*) label_color='\033[38;5;250m' ;;
    esac

    ui_button_box "$row" "$UI_PANEL_COL" "$UI_PANEL_WIDTH" "$border" 2 right
    ui_button_caption "$UI_BOX_COL" "$UI_BOX_WIDTH" "$label_color" "$label" "$hint"
}

draw_category_frame() {
    local selected="${1:-}"
    local title="$2"
    local subtitle="$3"
    local show_context="${4:-1}"
    local row

    ui_begin_frame draw_category_frame "$@"
    if [ "$UI_REPLAYING" = 0 ]; then
        UI_DEFERRED=1
        UI_RECORDING=1
        return 0
    fi
    if [ "$UI_LAYOUT_USABLE" = 0 ]; then
        UI_RECORDING=1
        return 0
    fi

    ui_move 1 3
    printf '\033[1;38;5;203mRENKIT\033[0m  \033[38;5;245m掌机工具箱\033[0m'

    # 九个分类共用等高布局；最小 24 行窗口也保留全部入口。
    ui_sidebar_item 2 init "◆ 新机器设置" "$selected"
    ui_sidebar_item 4 software "▣ 安装常用软件" "$selected"
    ui_sidebar_item 6 games "✦ 游戏与插件" "$selected"
    ui_sidebar_item 8 emulators "▦ 模拟器" "$selected"
    ui_sidebar_item 10 support "◎ 检查与维护" "$selected"
    ui_sidebar_item 12 advanced "! 更多设置" "$selected" 0
    ui_sidebar_item 14 uninstall "- 卸载已安装" "$selected" 0
    ui_sidebar_item 16 notice "▧ 免责声明与须知" "$selected" 0
    ui_sidebar_item 18 exit "× 退出Renkit" "$selected" 0

    row=2
    while [ "$row" -lt "$UI_ROWS" ]; do
        ui_move_absolute "$row" "$UI_SEPARATOR_COL"
        printf '\033[38;5;236m│\033[0m'
        row=$((row + 1))
    done

    if [ "$UI_GRID" = 1 ]; then
        if [ "$UI_HOME" = 1 ]; then
            title='掌机控制中心'
            subtitle='新机设置、游戏工具与日常维护，从这里开始'
        fi
        if [ -z "$title" ]; then
            case "$selected" in
                init) title='新机器设置' ;; software) title='安装常用软件' ;;
                games) title='游戏与插件' ;; emulators) title='模拟器' ;;
                support) title='检查与维护' ;; advanced) title='更多设置' ;;
                uninstall) title='卸载已安装' ;; *) title='功能选择' ;;
            esac
        fi
        ui_move_absolute 1 "$((UI_PANEL_COL + 1))"
        ui_fit_button_text "$title" "$((UI_PANEL_WIDTH - 3))"
        printf '\033[1;38;5;255m%s\033[0m' "$UI_FIT_TEXT"
        ui_move_absolute 2 "$((UI_PANEL_COL + 1))"
        ui_fit_button_text "${subtitle:-选择功能，按提示操作}" "$((UI_PANEL_WIDTH - 3))"
        printf '\033[38;5;245m%s\033[0m' "$UI_FIT_TEXT"
    elif [ -n "$title" ]; then
        ui_panel_line 2 '\033[1;38;5;203m' "◆ Renkit  ·  V${TOOLBOX_VERSION}"
        ui_panel_line 3 '\033[1;38;5;45m' "${RENKIT_PLATFORM_LABEL:-STEAMOS 掌机  /  中文工具}"
        ui_panel_line 4 '\033[38;5;203m' "────────────────────────────────────────"
        if [ "$show_context" = "1" ]; then
            ui_panel_line 5 '\033[1;38;5;220m' "▌ $title"
            ui_panel_line 6 '\033[1;38;5;45m' "  $subtitle"
        fi
    fi
    UI_RECORDING=1
}

draw_disclaimer_frame() {
    UI_DEFERRED=0
    ui_begin_frame draw_disclaimer_frame
    if [ "$UI_LAYOUT_USABLE" = 0 ]; then
        UI_RECORDING=1
        return 0
    fi

    ui_move 2 6
    printf '\033[1;38;5;203m ◆ Renkit  ·  V%s \033[0m' "$TOOLBOX_VERSION"
    ui_move 3 6
    printf '\033[38;5;203m'
    ui_rule "$((UI_COLUMNS - 8))"
    printf '\033[0m'
    ui_move 5 6
    printf '\033[1;38;5;255m ▌ 使用说明与免责声明 \033[0m'
    ui_move 6 6
    printf '\033[38;5;250m  请阅读以下内容，知悉后再开始使用 \033[0m'
    UI_RECORDING=1
}

ui_disclaimer_line() {
    ui_record_draw ui_disclaimer_line "$@"
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    local row="$1"
    local color="$2"
    local text="$3"

    ui_resolve_text_color "$color"
    ui_move "$row" 6
    printf '\033[?7l %b%s \033[0m\033[?7h' "$UI_THEME_COLOR" "$text"
}

ui_disclaimer_button() {
    ui_record_draw ui_disclaimer_button "$@"
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    local row="$1"
    local color="$2"
    local label="$3"
    local hint="$4"

    # 欢迎页没有密集相邻按钮，可使用四行逻辑高度保留完整说明。
    ui_button_box "$row" 6 "$((UI_COLUMNS - 10))" '\033[38;5;203m' 4
    ui_button_caption 6 "$((UI_COLUMNS - 10))" '\033[38;5;255m' "$label"
    UI_BOX_TEXT_ROW=$((UI_BOX_TEXT_ROW + 1))
    ui_button_caption 6 "$((UI_COLUMNS - 10))" '\033[38;5;250m' "$hint"
}

ui_prompt() {
    ui_record_draw ui_prompt
    if [ "$UI_DEFERRED" = 1 ]; then
        ui_detect_layout
        ui_prepare_layout
        ui_replay_frame
        return 0
    fi
    # 操作完成后 pause_menu 会暂时关闭鼠标追踪；每次显示触控提示前重新
    # 进入点击模式，避免下一层菜单退回普通光标导致触控失效。
    enable_mouse_tracking
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    # 24 行紧凑窗口优先显示最底部按钮的完整红框，不用提示覆盖按钮。
    [ "$UI_ROWS" -gt "$UI_CONTENT_ROWS" ] || return 0
    ui_move_absolute "$UI_ROWS" 3
    printf '\033[38;5;245mRenkit %s\033[0m' "$TOOLBOX_VERSION"
    ui_move_absolute "$UI_ROWS" "$UI_PANEL_COL"
    printf '\033[?7l\033[0m\033[K\033[38;5;245m 触屏或触控板点击功能 \033[0m\033[?7h'
}

enable_mouse_tracking() {
    # 只接收按下/松开事件。1002 会把触控板移动持续写进终端，部分 Konsole
    # 会把这些转义序列显示成文字，导致“点击返回”后满屏乱码。
    printf '\033[?1003l\033[?1015l\033[?1002l\033[?25l\033[?1000h\033[?1006h'
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
    local code
    LC_CTYPE=C printf -v code '%d' "'$1"
    # 部分 Bash 对高位字节返回负数，X10 坐标必须按无符号字节解释。
    printf '%d' "$((code & 255))"
}

read_ui_event() {
    local char
    local first
    local index
    local sequence=""
    local mouse_pattern='^\[<([0-9]{1,3});([0-9]{1,4});([0-9]{1,4})([Mm])$'
    # X10 使用原始字节坐标；不能按 UTF-8 字符合并相邻坐标字节。
    local LC_ALL=C

    UI_EVENT_TYPE=""
    UI_EVENT_BUTTON=""
    UI_EVENT_KEY=""
    UI_EVENT_X=""
    UI_EVENT_Y=""

    if [ "${UI_POLL_RESIZE:-0}" = 1 ]; then
        local read_started=$SECONDS
        if IFS= read -rsn1 -t 1 first; then
            :
        else
            local status=$?
            [ "$status" -gt 128 ] && return 2
            # macOS Bash 3.2 把超时和 EOF 都返回 1；用耗时区分模拟测试中的超时。
            if [ "${BASH_VERSINFO[0]}" -lt 4 ] && [ "$SECONDS" -gt "$read_started" ]; then
                return 2
            fi
            return 1
        fi
    else
        IFS= read -rsn1 first || return 1
    fi
    if [ "$first" != $'\033' ]; then
        # 触控界面故意忽略所有键盘输入，避免数字键与触屏冲突。
        UI_EVENT_TYPE="ignored-key"
        return 0
    fi

    index=0
    while [ "$index" -lt 32 ]; do
        IFS= read -rsn1 -t 1 char || break
        # 残缺事件或 ESC 键后紧接一次点击时，从新 ESC 重新同步，
        # 不把新的完整点击拼进旧事件并一起丢弃。
        if [ "$char" = $'\033' ]; then
            sequence=""
            index=0
            continue
        fi
        sequence="$sequence$char"

        # 旧式 X10 鼠标事件以 ESC [ M 开头，后面还有三个坐标字节。
        if [[ "$sequence" = '[M'* ]]; then
            [ "${#sequence}" -ge 5 ] || { index=$((index + 1)); continue; }
            UI_EVENT_BUTTON=$(( $(char_code "${sequence:2:1}") - 32 ))
            UI_EVENT_X=$(( $(char_code "${sequence:3:1}") - 32 ))
            UI_EVENT_Y=$(( $(char_code "${sequence:4:1}") - 32 ))
            if [ $((UI_EVENT_BUTTON & ~28)) -eq 0 ]; then
                UI_EVENT_TYPE="click"
            else
                UI_EVENT_TYPE="ignored-mouse"
            fi
            return 0
        fi

        case "$sequence" in
            '[') ;;
            '[<'*)
                case "$char" in
                    M|m) break ;;
                    '<'|[0-9]|';') ;;
                    *) UI_EVENT_TYPE="ignored-mouse"; return 0 ;;
                esac ;;
            *) UI_EVENT_TYPE="ignored-key"; return 0 ;;
        esac
        index=$((index + 1))
    done

    # 只接受有界十进制字段，残缺或畸形事件不能进入算术解析。
    if [[ "$sequence" =~ $mouse_pattern ]]; then
        UI_EVENT_BUTTON=$((10#${BASH_REMATCH[1]}))
        UI_EVENT_X=$((10#${BASH_REMATCH[2]}))
        UI_EVENT_Y=$((10#${BASH_REMATCH[3]}))
        if [ "${BASH_REMATCH[4]}" = m ]; then
            # 松开不触发操作，避免一次触摸连续打开两层菜单。
            UI_EVENT_TYPE="release"
        elif [ $((UI_EVENT_BUTTON & ~28)) -eq 0 ]; then
            # 只响应主指针按下，忽略滚轮、额外按键和拖动事件。
            UI_EVENT_TYPE="click"
        else
            UI_EVENT_TYPE="ignored-mouse"
        fi
        return 0
    fi

    UI_EVENT_TYPE="ignored-key"
}

read_touch_click() {
    while read_ui_event; do
        [ "$UI_EVENT_TYPE" = "click" ] || continue
        return 0
    done
    return 1
}

ui_render_to_terminal() {
    case "${1:-}" in ui_prompt|ui_redraw_if_resized) ;; *) return 1 ;; esac
    if [ "$UI_TERMINAL_OUTPUT_READY" = 1 ] && [ -t 9 ]; then
        "$1" >&9
    else
        # 无终端的管道与模拟调用保留 stderr 回退，不污染动作返回值。
        "$1" >&2
    fi
}

read_menu_choice() {
    local mapping
    local region
    local row_end
    local row_spec
    local row_start
    local value
    local status
    local UI_POLL_RESIZE=1

    # ToDesk / 新机准备页直接读取触控，没有显式 ui_prompt；仍须先完整
    # 显示说明和按钮，且不能让重绘内容混入 choice=$(...) 的动作值。
    if [ "$UI_DEFERRED" = 1 ]; then
        ui_render_to_terminal ui_prompt
    fi

    while true; do
        status=0
        read_ui_event || status=$?
        [ "$status" -ne 1 ] || return 1
        # choice=$(...) 的 stdout 只返回动作；重绘直达终端，不经过日志过滤。
        # 尺寸变化这一瞬间收到的点击丢弃，防止用旧位置误触另一项。
        ui_render_to_terminal ui_redraw_if_resized && continue
        [ "$status" -eq 0 ] || continue
        [ "$UI_EVENT_TYPE" = "click" ] || continue
        [ "$UI_LAYOUT_USABLE" = 1 ] || continue
        [ "$UI_EVENT_X" -ge 1 ] && [ "$UI_EVENT_X" -le "$UI_COLUMNS" ] || continue
        [ "$UI_EVENT_Y" -ge 1 ] && [ "$UI_EVENT_Y" -le "$UI_ROWS" ] || continue

        for mapping in "$@"; do
            region="${mapping%%:*}"
            mapping="${mapping#*:}"
            row_spec="${mapping%%:*}"
            value="${mapping#*:}"
            row_start="${row_spec%-*}"
            row_end="${row_spec#*-}"
            [ "$row_start" = "$row_spec" ] && row_end="$row_start"

            # 首页右侧卡片复用左侧的分类导航值，不增加模块执行入口。
            if [ "$UI_HOME" = 1 ] && [ "$region" = left ] && ui_button_rect right "$row_start"; then
                if [ "$UI_EVENT_Y" -ge "$UI_HIT_TOP" ] && [ "$UI_EVENT_Y" -le "$UI_HIT_BOTTOM" ] && \
                    [ "$UI_EVENT_X" -ge "$UI_HIT_COL" ] && [ "$UI_EVENT_X" -lt "$((UI_HIT_COL + UI_HIT_WIDTH))" ]; then
                    printf '%s\n' "$value"
                    return 0
                fi
            fi

            if ui_button_rect "$region" "$row_start"; then
                [ "$UI_EVENT_Y" -ge "$UI_HIT_TOP" ] && [ "$UI_EVENT_Y" -le "$UI_HIT_BOTTOM" ] || continue
                [ "$UI_EVENT_X" -ge "$UI_HIT_COL" ] && [ "$UI_EVENT_X" -lt "$((UI_HIT_COL + UI_HIT_WIDTH))" ] || continue
                printf '%s\n' "$value"
                return 0
            fi

            # 分类页只接受本帧实际绘制的按钮。动态列表末页仍可能传入空槽
            # 映射，不能回退到旧行号，否则会截走重排后的翻页/返回点击。
            if [ "${UI_DRAW_FUNCTION[0]:-}" = draw_category_frame ]; then
                case "$region" in left|right) continue ;; esac
            fi

            if [ "$region" != any ]; then
                ui_scale_row "$row_start"
                row_start="$UI_SCALED_ROW"
                ui_scale_row "$((row_end + 1))"
                row_end=$((UI_SCALED_ROW - 1))
                [ "$UI_EVENT_Y" -le "$UI_CONTENT_ROWS" ] || continue
            fi

            [ "$UI_EVENT_Y" -ge "$row_start" ] 2>/dev/null || continue
            [ "$UI_EVENT_Y" -le "$row_end" ] 2>/dev/null || continue
            case "$region" in
                left) [ "$UI_EVENT_X" -ge 3 ] && [ "$UI_EVENT_X" -le "$UI_SIDEBAR_WIDTH" ] || continue ;;
                right) [ "$UI_EVENT_X" -ge "$UI_PANEL_COL" ] && [ "$UI_EVENT_X" -lt "$((UI_PANEL_COL + UI_PANEL_WIDTH))" ] || continue ;;
                any) ;;
                *) continue ;;
            esac
            printf '%s\n' "$value"
            return 0
        done
    done
    return 1
}
