#!/bin/bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="$HOME/.local/share/konsole/ZhoukeerToolbox.profile"
WINDOW_SIZE="1220x740"
LOG_DIR="$PROJECT_ROOT/logs"
LAUNCH_LOG="$LOG_DIR/launcher.log"

mkdir -p "$LOG_DIR" 2>/dev/null || true

launcher_log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LAUNCH_LOG" 2>/dev/null || true
}

if ! command -v konsole >/dev/null 2>&1; then
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --error "未找到 Konsole，无法启动周克儿工具箱。"
    fi
    exit 1
fi

KONSOLE_HELP="$(konsole --help 2>/dev/null || true)"

supports_konsole_option() {
    printf '%s\n' "$KONSOLE_HELP" | grep -q -- "$1"
}

build_window_args() {
    KONSOLE_WINDOW_MODE="default"

    if supports_konsole_option '--geometry'; then
        KONSOLE_WINDOW_MODE="geometry"
    elif supports_konsole_option '--fullscreen'; then
        # 新版 SteamOS 的 Konsole 可能移除了 --geometry；全屏仍能保证触控区域完整。
        KONSOLE_WINDOW_MODE="fullscreen"
    else
        launcher_log "Konsole 不支持 --geometry/--fullscreen，使用默认窗口尺寸"
    fi
}

launch_konsole() {
    local use_profile="$1"
    local args=()

    case "$KONSOLE_WINDOW_MODE" in
        geometry) args+=(--geometry "$WINDOW_SIZE") ;;
        fullscreen) args+=(--fullscreen) ;;
    esac

    if [ "$use_profile" = "1" ]; then
        args+=(--profile "$PROFILE_FILE")
    fi

    if supports_konsole_option '--workdir'; then
        args+=(--workdir "$PROJECT_ROOT")
    fi

    launcher_log "启动 Konsole：profile=$use_profile args=${args[*]:-none}"
    konsole "${args[@]}" \
        -e env ZHOUKEER_LAUNCHED=1 bash "$PROJECT_ROOT/main.sh" --touch
}

build_window_args

# SteamOS 不同版本捆绑的 Konsole 参数不完全一致。
# 只在当前版本明确提供 --profile 时启用大字体与背景主题；
# 否则回退到已在 Steam Deck 真机运行过的基础启动参数。
if [ -f "$PROFILE_FILE" ] && supports_konsole_option '--profile'; then
    launch_konsole 1
    launch_status=$?

    if [ "$launch_status" -eq 0 ]; then
        exit 0
    fi

    launcher_log "主题启动失败，状态码=$launch_status，回退到基础启动"
fi

launch_konsole 0
launch_status=$?

if [ "$launch_status" -ne 0 ]; then
    launcher_log "基础启动失败，状态码=$launch_status"
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --error "周克儿工具箱启动失败。\n日志：$LAUNCH_LOG"
    fi
fi

exit "$launch_status"
