#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"

PREFLIGHT_DETAIL_FILE="${ZHOUKEER_PREFLIGHT_DETAIL_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox/preflight.txt}"

preflight_positive_integer() {
    case "$1" in ''|*[!0-9]*) return 1 ;; *) [ "$1" -gt 0 ] ;; esac
}

preflight_minimum_kib() {
    case "$1" in
        system-update|new-machine) printf '%s\n' 4194304 ;;
        memory) printf '%s\n' 4194304 ;;
        memory-restore) printf '%s\n' 1 ;;
        decky) printf '%s\n' 1048576 ;;
        steam302) printf '%s\n' 524288 ;;
        *) return 1 ;;
    esac
}

preflight_available_kib() {
    df -Pk "${ZHOUKEER_PREFLIGHT_SPACE_PATH:-$HOME}" 2>/dev/null | awk 'NR > 1 { value=$4 } END { print value }'
}

preflight_power_ok() {
    local power_root="${ZHOUKEER_POWER_SUPPLY_ROOT:-/sys/class/power_supply}"
    local capacity="" online="" item

    [ -d "$power_root" ] || return 2
    for item in "$power_root"/*/online; do
        [ -r "$item" ] || continue
        [ "$(tr -d '\r\n' < "$item")" = "1" ] && online=1
    done
    [ "$online" = "1" ] && return 0
    for item in "$power_root"/*/capacity; do
        [ -r "$item" ] || continue
        capacity="$(tr -d '\r\n' < "$item")"
        preflight_positive_integer "$capacity" || continue
        [ "$capacity" -ge 20 ] && return 0
        return 1
    done
    return 2
}

preflight_network_ok() {
    if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ] && [ "${ZHOUKEER_PREFLIGHT_SKIP_NETWORK:-0}" = "1" ]; then
        return 0
    fi
    ZHOUKEER_NETWORK_QUIET=1 bash "$PROJECT_ROOT/modules/network.sh" --preflight
}

preflight_needs_network() {
    case "$1" in
        system-update|new-machine|decky|steam302) return 0 ;;
        *) return 1 ;;
    esac
}

preflight_readonly_status() {
    local status
    command -v steamos-readonly >/dev/null 2>&1 || return 2
    status="$(steamos-readonly status 2>/dev/null || true)"
    case "$(printf '%s' "$status" | tr '[:upper:]' '[:lower:]')" in
        *enabled*|*readonly*) return 0 ;;
        *disabled*) return 1 ;;
        *) return 2 ;;
    esac
}

run_preflight() {
    local profile="${1:-}"
    local min_kib available_kib failed=0 readonly_result power_result
    local state_dir

    min_kib="$(preflight_minimum_kib "$profile")" || {
        echo "未知预检类型：$profile"
        return 1
    }
    detect_platform
    if [ "$IS_STEAMOS" -ne 1 ] && [ "${ZHOUKEER_TEST_MODE:-0}" != "1" ]; then
        echo "此操作仅支持真实 SteamOS，已安全退出。"
        return 1
    fi

    state_dir="$(dirname "$PREFLIGHT_DETAIL_FILE")"
    mkdir -p -- "$state_dir" || return 1
    chmod 0700 "$state_dir" 2>/dev/null || true
    : > "$PREFLIGHT_DETAIL_FILE" || return 1
    chmod 0600 "$PREFLIGHT_DETAIL_FILE" || return 1
    printf '操作=%s\n时间=%s\n' "$profile" "$(date '+%Y-%m-%d %H:%M:%S')" >> "$PREFLIGHT_DETAIL_FILE"

    available_kib="$(preflight_available_kib)"
    if preflight_positive_integer "$available_kib" && [ "$available_kib" -ge "$min_kib" ]; then
        printf '空间=正常（%s KiB）\n' "$available_kib" >> "$PREFLIGHT_DETAIL_FILE"
    else
        echo "可用空间不足，已停止操作。请先释放内部存储空间。"
        printf '空间=不足（%s KiB，至少需要 %s KiB）\n' "${available_kib:-未知}" "$min_kib" >> "$PREFLIGHT_DETAIL_FILE"
        failed=1
    fi

    if preflight_needs_network "$profile"; then
        if preflight_network_ok; then
            printf '网络=至少一条安全线路可用\n' >> "$PREFLIGHT_DETAIL_FILE"
        else
            echo "下载连接暂时不可用，工具箱没有开始修改。请检查网络后重试。"
            printf '网络=不可用\n' >> "$PREFLIGHT_DETAIL_FILE"
            failed=1
        fi
    else
        printf '网络=此操作不需要联网，未检查\n' >> "$PREFLIGHT_DETAIL_FILE"
    fi

    preflight_readonly_status
    readonly_result=$?
    case "$readonly_result" in
        0) printf 'SteamOS只读状态=已保护\n' >> "$PREFLIGHT_DETAIL_FILE" ;;
        1)
            printf 'SteamOS只读状态=当前可写；本次操作完成后恢复保护\n' >> "$PREFLIGHT_DETAIL_FILE"
            case "$profile" in system-update|new-machine)
                echo "SteamOS 当前处于可写状态；本次操作完成后会恢复系统保护。"
            esac
            ;;
        *)
            printf 'SteamOS只读状态=无法确认\n' >> "$PREFLIGHT_DETAIL_FILE"
            case "$profile" in system-update|new-machine)
                echo "无法确认 SteamOS 系统保护状态，已停止操作。"
                failed=1
            esac
            ;;
    esac

    preflight_power_ok
    power_result=$?
    case "$power_result" in
        0) printf '电源=电量充足或已接电源\n' >> "$PREFLIGHT_DETAIL_FILE" ;;
        1) echo "电量低于 20%，已停止操作。请连接电源后重试。"; printf '电源=电量不足\n' >> "$PREFLIGHT_DETAIL_FILE"; failed=1 ;;
        *) printf '电源=设备未提供可安全读取的电量信息\n' >> "$PREFLIGHT_DETAIL_FILE" ;;
    esac

    if [ "$failed" -ne 0 ]; then
        echo "预检未通过，没有执行任何系统修改。"
        echo "详细信息：$PREFLIGHT_DETAIL_FILE"
        log "高风险操作预检失败: $profile"
        return 1
    fi
    [ "${ZHOUKEER_PREFLIGHT_QUIET_SUCCESS:-0}" = "1" ] || echo "检查通过，正在继续..."
    log "高风险操作预检通过: $profile"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_preflight "${1:-}"
fi
