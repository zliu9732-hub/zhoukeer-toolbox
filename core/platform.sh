#!/bin/bash

detect_platform() {
    PLATFORM_UNAME="$(uname -s 2>/dev/null || echo unknown)"
    PLATFORM_ID=""
    PLATFORM_NAME="$PLATFORM_UNAME"
    IS_STEAMOS=0

    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        PLATFORM_ID="${ID:-}"
        PLATFORM_NAME="${PRETTY_NAME:-$PLATFORM_UNAME}"
        case "${ID:-}" in
            steamos)
                IS_STEAMOS=1
                ;;
        esac
        case " ${ID_LIKE:-} " in
            *" steamos "*)
                IS_STEAMOS=1
                ;;
        esac
    fi

    if command -v steamos-readonly >/dev/null 2>&1; then
        IS_STEAMOS=1
    fi
}

is_linux() {
    [ "$(uname -s 2>/dev/null)" = "Linux" ]
}

is_macos() {
    [ "$(uname -s 2>/dev/null)" = "Darwin" ]
}

require_steamos() {
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ]; then
        echo "此功能仅支持 SteamOS，已停止执行。"
        return 1
    fi
}

require_command() {
    local name="$1"
    if ! command -v "$name" >/dev/null 2>&1; then
        echo "缺少命令: $name"
        return 1
    fi
    return 0
}
