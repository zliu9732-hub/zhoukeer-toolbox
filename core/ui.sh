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

# 框只占用原来的两行逻辑触控区，不借用相邻说明或其他按钮的行。
# 两行高时名称嵌在上边框；空间充足时名称位于框内，保持中文完整。
ui_button_box() {
    local row="$1" col="$2" width="$3"
    local border="${4:-\033[38;5;203m}" span="${5:-2}"
    local top bottom current
    ui_scale_row "$row"
    top="$UI_SCALED_ROW"
    ui_scale_row "$((row + span))"
    bottom=$((UI_SCALED_ROW - 1))
    UI_BOX_TEXT_ROW=$(((top + bottom) / 2))
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
            [\ -~]|◆|▣|✦|▦|◎|▧|×|▶|·|…|—|–|→|←|✓|✗) width=1 ;;
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
    if [ -n "$hint" ] && [ "$remaining" -gt 3 ]; then
        ui_fit_button_text " · $hint" "$remaining"
        printf '\033[38;5;245m%s' "$UI_FIT_TEXT"
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
        ui_wait_for_minimum_canvas || true
        ui_discard_pending_input
        UI_DRAW_COUNT=0
    fi
    ui_detect_layout
    UI_RECORDING=1
    ui_record_draw "$@"
    UI_RECORDING=0
    ui_reset_screen
    if [ "$UI_LAYOUT_USABLE" = 0 ]; then
        printf '\033[?7l窗口太小，请放大至至少 70 列 × 24 行\033[?7h'
    fi
}

ui_redraw_if_resized() {
    local previous_size="$UI_COLUMNS:$UI_ROWS" index function
    [ "$UI_DRAW_COUNT" -gt 0 ] || return 1
    ui_detect_layout
    [ "$previous_size" != "$UI_COLUMNS:$UI_ROWS" ] || return 1
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
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    local row="$1"
    local color="$2"
    local text="$3"

    ui_resolve_text_color "$color"
    ui_move "$row" "$UI_PANEL_COL"
    printf '\033[?7l %b' "$UI_THEME_COLOR"
    case "$text" in
        ─*) ui_rule "$((UI_PANEL_WIDTH - 2))" ;;
        *) printf '%s' "$text" ;;
    esac
    printf ' \033[0m\033[?7h'
}

# 分类沿用两行逻辑触控区，实际边框随窗口高度展开。
ui_sidebar_item() {
    local row="$1"
    local value="$2"
    local label="$3"
    local selected="$4"
    local marker='  '
    local foreground='\033[38;5;252m'
    local border='\033[38;5;203m'

    if [ "$value" = "$selected" ]; then
        marker='▶ '
        foreground='\033[1;38;5;203m'
        border='\033[1;38;5;203m'
    fi

    ui_button_box "$row" 3 "$((UI_SIDEBAR_WIDTH - 2))" "$border"
    ui_button_caption 3 "$((UI_SIDEBAR_WIDTH - 2))" "$foreground" "$marker$label"
}

ui_touch_button() {
    ui_record_draw ui_touch_button "$@"
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    local row="$1"
    local color="$2"
    local label="$3"
    local hint="${4:-}"
    local label_color='\033[38;5;255m'
    local border='\033[38;5;203m'

    # 返回、安装和确认按钮都使用红框，危险确认保留加亮边框。
    case "$color" in
        *'48;5;160'*) border='\033[1;38;5;203m' ;;
        *'48;5;238'*) label_color='\033[38;5;250m' ;;
    esac

    ui_button_box "$row" "$UI_PANEL_COL" "$UI_PANEL_WIDTH" "$border"
    ui_button_caption "$UI_PANEL_COL" "$UI_PANEL_WIDTH" "$label_color" "$label" "$hint"
}

draw_category_frame() {
    local selected="${1:-}"
    local title="$2"
    local subtitle="$3"
    local show_context="${4:-1}"
    local row

    ui_begin_frame draw_category_frame "$@"
    if [ "$UI_LAYOUT_USABLE" = 0 ]; then
        UI_RECORDING=1
        return 0
    fi

    ui_move 1 3
    printf '\033[1;38;5;245m功能导航\033[0m'

    # 侧栏改为连续两行一项：即使 Konsole 未能放大窗口，九个入口也都在
    # 默认 24 行画布内可见，不能把新入口排到窗口底部之外。
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
        printf '\033[38;5;239m│\033[0m'
        row=$((row + 1))
    done

    if [ -n "$title" ]; then
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
    # 操作完成后 pause_menu 会暂时关闭鼠标追踪；每次显示触控提示前重新
    # 进入点击模式，避免下一层菜单退回普通光标导致触控失效。
    enable_mouse_tracking
    [ "$UI_LAYOUT_USABLE" = 1 ] || return 0
    # 24 行紧凑窗口优先显示最底部按钮的完整红框，不用提示覆盖按钮。
    [ "$UI_ROWS" -gt "$UI_CONTENT_ROWS" ] || return 0
    ui_move_absolute "$UI_ROWS" "$UI_PANEL_COL"
    printf '\033[?7l\033[0m\033[K\033[38;5;255m 触屏或触控板点击功能 \033[0m\033[?7h'
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
    local status
    local UI_POLL_RESIZE=1

    while true; do
        status=0
        read_ui_event || status=$?
        [ "$status" -ne 1 ] || return 1
        # choice=$(...) 的 stdout 只返回动作；重绘输出送回终端 stderr。
        # 尺寸变化这一瞬间收到的点击丢弃，防止用旧位置误触另一项。
        ui_redraw_if_resized >&2 && continue
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
