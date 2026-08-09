#!/bin/bash

platform_os_release_value() {
    local key="$1"
    local file="${ZHOUKEER_OS_RELEASE_FILE:-/etc/os-release}"
    local value

    [ -r "$file" ] || return 1
    value="$(awk -F= -v wanted="$key" '
        $1 == wanted {
            value = substr($0, index($0, "=") + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            if (value ~ /^".*"$/ || value ~ /^\047.*\047$/) {
                value = substr(value, 2, length(value) - 2)
            }
            print value
            exit
        }
    ' "$file")"
    [ -n "$value" ] || return 1
    printf '%s\n' "$value"
}

detect_platform() {
    PLATFORM_UNAME="$(uname -s 2>/dev/null || echo unknown)"
    PLATFORM_ID=""
    PLATFORM_NAME="$PLATFORM_UNAME"
    PLATFORM_VARIANT_ID=""
    PLATFORM_FAMILY="unknown"
    IS_STEAMOS=0
    IS_BAZZITE=0

    if [ -r "${ZHOUKEER_OS_RELEASE_FILE:-/etc/os-release}" ]; then
        PLATFORM_ID="$(platform_os_release_value ID 2>/dev/null || true)"
        PLATFORM_NAME="$(platform_os_release_value PRETTY_NAME 2>/dev/null || true)"
        PLATFORM_VARIANT_ID="$(platform_os_release_value VARIANT_ID 2>/dev/null || true)"
        PLATFORM_ID_LIKE="$(platform_os_release_value ID_LIKE 2>/dev/null || true)"
        [ -n "$PLATFORM_NAME" ] || PLATFORM_NAME="$PLATFORM_UNAME"
        case "$PLATFORM_ID" in
            steamos)
                IS_STEAMOS=1
                PLATFORM_FAMILY="steamos"
                ;;
            bazzite)
                IS_BAZZITE=1
                PLATFORM_FAMILY="bazzite"
                ;;
        esac
        case " ${PLATFORM_ID_LIKE:-} " in
            *" steamos "*)
                IS_STEAMOS=1
                PLATFORM_FAMILY="steamos"
                ;;
        esac
        case "$PLATFORM_VARIANT_ID" in
            bazzite*)
                IS_BAZZITE=1
                PLATFORM_FAMILY="bazzite"
                ;;
        esac
    fi

    if [ "$IS_BAZZITE" -ne 1 ] && command -v steamos-readonly >/dev/null 2>&1; then
        IS_STEAMOS=1
        PLATFORM_FAMILY="steamos"
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

require_bazzite() {
    detect_platform
    if [ "$IS_BAZZITE" -ne 1 ]; then
        echo "此功能仅支持 Bazzite，已停止执行。"
        return 1
    fi
}

is_supported_gaming_os() {
    detect_platform
    [ "$IS_STEAMOS" -eq 1 ] || [ "$IS_BAZZITE" -eq 1 ]
}

require_supported_gaming_os() {
    if ! is_supported_gaming_os; then
        echo "此功能仅支持 SteamOS 或 Bazzite，已停止执行。"
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
