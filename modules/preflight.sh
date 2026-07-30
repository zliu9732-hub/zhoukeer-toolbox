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

preflight_nonnegative_integer() {
    case "$1" in ''|*[!0-9]*) return 1 ;; *) return 0 ;; esac
}

preflight_minimum_kib() {
    case "$1" in
        system-update|new-machine) printf '%s\n' 4194304 ;;
        memory) printf '%s\n' 4194304 ;;
        decky) printf '%s\n' 1048576 ;;
        steam302) printf '%s\n' 524288 ;;
        *) return 1 ;;
    esac
}

preflight_plan_text() {
    case "$1" in
        system-update) echo "将更新系统组件和工具箱管理的软件来源；失败时恢复配置备份，备份位于本次临时工作目录。" ;;
        new-machine) echo "将依次完成新机器设置；各安装器保留旧版本或临时备份，失败项目会安全停止。" ;;
        decky) echo "将安装或更新插件商城/插件；旧版本会先备份，失败时尽量恢复，备份位于插件目录旁。" ;;
        steam302) echo "将安装或启动网络加速；程序旧版本会先备份，卸载入口可移除工具箱创建的文件。" ;;
        memory) echo "将调整工具箱管理的虚拟内存；原文件会先备份，失败时尽量恢复到原状态。" ;;
        *) return 1 ;;
    esac
}

preflight_available_kib() {
    df -Pk "$1" 2>/dev/null | awk 'NR > 1 { value=$4 } END { print value }'
}

preflight_filesystem_identity() {
    df -Pk "$1" 2>/dev/null | awk 'NR > 1 { value=$1 } END { print value }'
}

preflight_check_space_path() {
    local path="$1" label="$2" minimum_kib="$3" available_kib

    available_kib="$(preflight_available_kib "$path")"
    if preflight_positive_integer "$available_kib" && [ "$available_kib" -ge "$minimum_kib" ]; then
        printf '%s空间=正常（%s KiB）\n' "$label" "$available_kib" >> "$PREFLIGHT_DETAIL_FILE"
        return 0
    fi
    printf '%s空间=不足（%s KiB，至少需要 %s KiB）\n' \
        "$label" "${available_kib:-未知}" "$minimum_kib" >> "$PREFLIGHT_DETAIL_FILE"
    return 1
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
        preflight_nonnegative_integer "$capacity" || continue
        [ "$capacity" -ge 20 ] && return 0
        return 1
    done
    return 2
}

preflight_network_ok() {
    if [ "${ZHOUKEER_TEST_MODE:-0}" = "1" ] && [ "${ZHOUKEER_PREFLIGHT_SKIP_NETWORK:-0}" = "1" ]; then
        return 0
    fi
    bash "$PROJECT_ROOT/modules/network.sh" --preflight
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
    local min_kib failed=0 readonly_result power_result space_failed=0
    local state_dir
    local home_space_path root_space_path home_filesystem root_filesystem

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

    home_space_path="${ZHOUKEER_PREFLIGHT_SPACE_PATH:-$HOME}"
    root_space_path="${ZHOUKEER_PREFLIGHT_ROOT_PATH:-/}"
    preflight_check_space_path "$home_space_path" "用户存储" "$min_kib" || space_failed=1
    case "$profile" in
        system-update|new-machine)
            home_filesystem="$(preflight_filesystem_identity "$home_space_path")"
            root_filesystem="$(preflight_filesystem_identity "$root_space_path")"
            if [ -n "$home_filesystem" ] && [ "$home_filesystem" = "$root_filesystem" ]; then
                printf '系统空间=与用户存储位于同一文件系统，未重复检查\n' >> "$PREFLIGHT_DETAIL_FILE"
            else
                preflight_check_space_path "$root_space_path" "系统" "$min_kib" || space_failed=1
            fi
            ;;
    esac
    if [ "$space_failed" -ne 0 ]; then
        echo "可用空间不足，已停止操作。请先释放内部存储空间。"
        failed=1
    fi

    if preflight_network_ok; then
        printf '网络=至少一条安全线路可用\n' >> "$PREFLIGHT_DETAIL_FILE"
    else
        echo "网络连接不可用，已停止操作。请先运行“检查问题”。"
        printf '网络=不可用\n' >> "$PREFLIGHT_DETAIL_FILE"
        failed=1
    fi

    preflight_readonly_status
    readonly_result=$?
    case "$readonly_result" in
        0) printf 'SteamOS只读状态=已保护\n' >> "$PREFLIGHT_DETAIL_FILE" ;;
        1)
            printf 'SteamOS只读状态=当前未保护\n' >> "$PREFLIGHT_DETAIL_FILE"
            case "$profile" in system-update|new-machine)
                echo "SteamOS 当前未处于只读保护状态，已停止操作。请先恢复系统保护。"
                failed=1
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
    echo "准备检查通过，可以安全继续。"
    preflight_plan_text "$profile"
    echo "详细信息：$PREFLIGHT_DETAIL_FILE"
    log "高风险操作预检通过: $profile"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_preflight "${1:-}"
fi
