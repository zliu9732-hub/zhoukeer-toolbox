#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_PROFILE_FILE="$HOME/.local/share/konsole/ZhoukeerToolbox.profile"
SPLASH_PROFILE_FILE="$HOME/.local/share/konsole/ZhoukeerToolboxSplash.profile"
PROFILE_FILE="$SPLASH_PROFILE_FILE"
STARTUP_VIEW="splash"
WINDOW_SIZE="1280x820"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
LAUNCH_LOG="${ZHOUKEER_LAUNCH_LOG:-$STATE_HOME/zhoukeer-toolbox/launcher.log}"

prepare_launcher_log() {
    local fallback_log

    if mkdir -p "$(dirname "$LAUNCH_LOG")" 2>/dev/null && \
        touch "$LAUNCH_LOG" 2>/dev/null; then
        chmod 600 "$LAUNCH_LOG" 2>/dev/null || true
        return 0
    fi

    fallback_log="${TMPDIR:-/tmp}/zhoukeer-toolbox-launcher-${UID:-user}.log"
    LAUNCH_LOG="$fallback_log"
    touch "$LAUNCH_LOG" 2>/dev/null || return 1
    chmod 600 "$LAUNCH_LOG" 2>/dev/null || true
}

launcher_log() {
    printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$$" "$*" \
        >> "$LAUNCH_LOG" 2>/dev/null || true
}

show_launch_error() {
    local title="$1"
    local message="$2"

    launcher_log "错误：${title}；${message//$'\n'/；}"

    if command -v kdialog >/dev/null 2>&1 && \
        kdialog --title "$title" --error "$message" >/dev/null 2>&1; then
        return 0
    fi
    if command -v zenity >/dev/null 2>&1 && \
        zenity --error --title="$title" --text="$message" >/dev/null 2>&1; then
        return 0
    fi
    if command -v xmessage >/dev/null 2>&1 && \
        xmessage -center "$title

$message" >/dev/null 2>&1; then
        return 0
    fi
    if command -v notify-send >/dev/null 2>&1 && \
        notify-send -u critical "$title" "$message" >/dev/null 2>&1; then
        return 0
    fi

    printf '%s\n%s\n' "$title" "$message" >&2
    return 1
}

run_startup_update() {
    local default_install_dir="$HOME/.local/share/zhoukeer-toolbox"
    local status

    [ "${ZHOUKEER_AUTO_UPDATE:-1}" != "0" ] || return 0
    [ "${ZHOUKEER_SKIP_STARTUP_UPDATE:-0}" != "1" ] || return 0
    [ "$(uname -s 2>/dev/null || echo unknown)" = "Linux" ] || return 0
    [ -r "$PROJECT_ROOT/update.sh" ] || return 0

    if [ ! -f "$PROJECT_ROOT/.zhoukeer-installed" ] && \
        [ "$PROJECT_ROOT" != "$default_install_dir" ] && \
        [ "${ZHOUKEER_AUTO_UPDATE_FORCE:-0}" != "1" ]; then
        launcher_log "跳过自动更新：当前目录不是受管理的安装目录"
        return 0
    fi

    printf '%s\n' "正在检查工具箱更新..."
    launcher_log "开始启动自动更新检测"

    # Konsole 默认工作目录就是安装目录，更新时该目录会被原子替换。
    # 提前移到稳定目录，更新后再进入新版本，避免父进程保留已删除的 cwd。
    cd "$HOME" 2>/dev/null || cd / || true
    if command -v tee >/dev/null 2>&1; then
        bash "$PROJECT_ROOT/update.sh" --startup 2>&1 | tee -a "$LAUNCH_LOG"
        status=${PIPESTATUS[0]}
    else
        bash "$PROJECT_ROOT/update.sh" --startup >> "$LAUNCH_LOG" 2>&1
        status=$?
    fi
    cd "$PROJECT_ROOT" 2>/dev/null || cd "$HOME" 2>/dev/null || cd / || true

    if [ "$status" -eq 0 ]; then
        launcher_log "启动自动更新检测完成"
    else
        launcher_log "启动自动更新检测失败：状态码=${status}；继续当前版本"
        printf '%s\n' "自动更新暂时不可用，继续启动当前版本。"
    fi
    return 0
}

run_main() {
    local status
    local message

    run_startup_update
    # 自动更新与主界面复用同一个终端；进入触控 UI 前清除更新输出和滚动残影。
    printf '\033[0m\033[r\033[3J\033[2J\033[H'
    launcher_log "主程序开始：$PROJECT_ROOT/main.sh --touch"
    if [ ! -r "$PROJECT_ROOT/main.sh" ]; then
        message="主程序文件缺失或无法读取：
$PROJECT_ROOT/main.sh

启动日志：$LAUNCH_LOG"
        show_launch_error "周克儿工具箱启动失败" "$message" || true
        return 1
    fi

    if command -v tee >/dev/null 2>&1; then
        ZHOUKEER_LAUNCHED=1 bash "$PROJECT_ROOT/main.sh" --touch \
            2> >(tee -a "$LAUNCH_LOG" >&2)
        status=$?
    else
        ZHOUKEER_LAUNCHED=1 bash "$PROJECT_ROOT/main.sh" --touch
        status=$?
    fi

    launcher_log "主程序结束：状态码=$status"
    if [ "$status" -eq 0 ]; then
        return 0
    fi

    message="主程序异常退出（状态码：${status}）。
请把启动日志发给维护者排查：
$LAUNCH_LOG"
    if ! show_launch_error "周克儿工具箱运行失败" "$message"; then
        if [ -r /dev/tty ] && [ -w /dev/tty ]; then
            printf '按回车键关闭窗口...' > /dev/tty
            read -r _ < /dev/tty || true
        fi
    fi
    return "$status"
}

prepare_launcher_log || true

case "${1:-}" in
    --run-main)
        run_main
        exit $?
        ;;
    --open-main)
        PROFILE_FILE="$MAIN_PROFILE_FILE"
        STARTUP_VIEW="main"
        ;;
    "")
        # 旧版安装尚未生成欢迎页主题时，继续使用常规主题启动。
        if [ ! -f "$SPLASH_PROFILE_FILE" ]; then
            PROFILE_FILE="$MAIN_PROFILE_FILE"
            STARTUP_VIEW="main-with-disclaimer"
        fi
        ;;
    *)
        show_launch_error "周克儿工具箱启动失败" \
            "启动器收到未知参数：$1
启动日志：$LAUNCH_LOG" || true
        exit 2
        ;;
esac

launcher_log "启动请求：目录=$PROJECT_ROOT 系统=$(uname -s 2>/dev/null || echo unknown)"

if [ ! -r "$PROJECT_ROOT/main.sh" ]; then
    show_launch_error "周克儿工具箱启动失败" \
        "安装可能不完整，未找到主程序：
$PROJECT_ROOT/main.sh

启动日志：$LAUNCH_LOG" || true
    exit 1
fi

case "$STARTUP_VIEW" in
    splash)
        RUN_COMMAND=(env ZHOUKEER_STARTUP_SPLASH=1 \
            bash "$PROJECT_ROOT/launch.sh" --run-main)
        ;;
    main)
        RUN_COMMAND=(env ZHOUKEER_SKIP_DISCLAIMER=1 ZHOUKEER_SKIP_STARTUP_UPDATE=1 \
            ZHOUKEER_STARTUP_SPLASH=0 bash "$PROJECT_ROOT/launch.sh" --run-main)
        ;;
    *)
        RUN_COMMAND=(env ZHOUKEER_STARTUP_SPLASH=0 \
            bash "$PROJECT_ROOT/launch.sh" --run-main)
        ;;
esac
KONSOLE_HELP=""

supports_konsole_option() {
    printf '%s\n' "$KONSOLE_HELP" | grep -q -- "$1"
}

filter_terminal_stderr() {
    local line

    while IFS= read -r line; do
        case "$line" in
            *"QLayout: Cannot add a null widget to QHBoxLayout"*)
                launcher_log "已隐藏 Konsole 无害布局警告：$line"
                ;;
            *)
                printf '%s\n' "$line" >&2
                launcher_log "终端启动输出：$line"
                ;;
        esac
    done
}

try_terminal() {
    local label="$1"
    shift

    launcher_log "尝试启动：${label}；命令=$1"
    "$@" 2> >(filter_terminal_stderr)
    local status=$?
    if [ "$status" -eq 0 ]; then
        launcher_log "启动命令已接受：$label"
        return 0
    fi

    launcher_log "启动失败：${label}；状态码=$status"
    return "$status"
}

try_konsole_levels() {
    local optional_args=()
    local window_mode="默认尺寸"

    command -v konsole >/dev/null 2>&1 || return 1
    KONSOLE_HELP="$(konsole --help 2>/dev/null || true)"

    if supports_konsole_option '--geometry'; then
        optional_args+=(--geometry "$WINDOW_SIZE")
        window_mode="窗口 $WINDOW_SIZE"
    # 某些 SteamOS 版本不支持 --geometry，但支持 --fullscreen。
    # 不把全屏当作后备方案：用户从桌面图标启动时应始终保留正常窗口。
    fi
    if supports_konsole_option '--workdir'; then
        optional_args+=(--workdir "$PROJECT_ROOT")
    fi

    if [ -f "$PROFILE_FILE" ] && supports_konsole_option '--profile'; then
        if try_terminal "Konsole 完整主题（${window_mode}）" \
            konsole "${optional_args[@]}" --profile "$PROFILE_FILE" \
            -e "${RUN_COMMAND[@]}"; then
            return 0
        fi
    fi

    if [ "${#optional_args[@]}" -gt 0 ]; then
        if try_terminal "Konsole 兼容模式（${window_mode}）" \
            konsole "${optional_args[@]}" -e "${RUN_COMMAND[@]}"; then
            return 0
        fi
    fi

    try_terminal "Konsole 最小参数模式" konsole -e "${RUN_COMMAND[@]}"
}

try_fallback_terminals() {
    if command -v x-terminal-emulator >/dev/null 2>&1 && \
        try_terminal "系统默认终端" x-terminal-emulator -e "${RUN_COMMAND[@]}"; then
        return 0
    fi
    if command -v gnome-terminal >/dev/null 2>&1 && \
        try_terminal "GNOME Terminal" gnome-terminal \
            --working-directory="$PROJECT_ROOT" -- "${RUN_COMMAND[@]}"; then
        return 0
    fi
    if command -v qterminal >/dev/null 2>&1 && \
        try_terminal "QTerminal" qterminal --workdir "$PROJECT_ROOT" \
            -e "${RUN_COMMAND[@]}"; then
        return 0
    fi
    if command -v kitty >/dev/null 2>&1 && \
        try_terminal "Kitty" kitty --directory "$PROJECT_ROOT" "${RUN_COMMAND[@]}"; then
        return 0
    fi
    if command -v alacritty >/dev/null 2>&1 && \
        try_terminal "Alacritty" alacritty --working-directory "$PROJECT_ROOT" \
            -e "${RUN_COMMAND[@]}"; then
        return 0
    fi
    if command -v xterm >/dev/null 2>&1 && \
        try_terminal "XTerm" xterm -e "${RUN_COMMAND[@]}"; then
        return 0
    fi
    return 1
}

if try_konsole_levels; then
    exit 0
fi

launcher_log "Konsole 各级启动均不可用，尝试备用终端"
if try_fallback_terminals; then
    exit 0
fi

if [ -t 0 ] && [ -t 1 ]; then
    launcher_log "图形终端均不可用，使用当前终端直接启动"
    run_main
    exit $?
fi

show_launch_error "周克儿工具箱启动失败" \
    "未能启动 Konsole 或其他兼容终端。
请检查终端程序是否完整，或在 Konsole 中运行：
bash \"$PROJECT_ROOT/main.sh\"

启动日志：$LAUNCH_LOG" || true
exit 1
