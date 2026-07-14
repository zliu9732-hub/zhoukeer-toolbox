#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

PASSWORD_RECORD="${ZHOUKEER_PASSWORD_RECORD:-$HOME/Desktop/密码.txt}"
TOOLBOX_PASSWORD=""

password_record_stat() {
    local field="$1"
    local file="$2"

    case "$field" in
        owner)
            stat -c '%u' "$file" 2>/dev/null || stat -f '%u' "$file" 2>/dev/null
            ;;
        mode)
            stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null
            ;;
        links)
            stat -c '%h' "$file" 2>/dev/null || stat -f '%l' "$file" 2>/dev/null
            ;;
        size)
            stat -c '%s' "$file" 2>/dev/null || stat -f '%z' "$file" 2>/dev/null
            ;;
        *) return 1 ;;
    esac
}

password_record_metadata_is_safe() {
    local file="${1:-$PASSWORD_RECORD}"
    local current_uid
    local file_uid
    local file_mode
    local link_count
    local file_size

    [ -f "$file" ] && [ ! -L "$file" ] && [ -r "$file" ] || return 1

    current_uid="$(id -u 2>/dev/null)" || return 1
    case "$current_uid" in ''|*[!0-9]*) return 1 ;; esac

    file_uid="$(password_record_stat owner "$file")" || return 1
    file_mode="$(password_record_stat mode "$file")" || return 1
    link_count="$(password_record_stat links "$file")" || return 1
    file_size="$(password_record_stat size "$file")" || return 1

    [ "$file_uid" = "$current_uid" ] || return 1
    [ "$file_mode" = "600" ] || return 1
    [ "$link_count" = "1" ] || return 1
    case "$file_size" in ''|*[!0-9]*) return 1 ;; esac
    [ "$file_size" -gt 0 ] && [ "$file_size" -le 4096 ]
}

load_toolbox_password() {
    local field_count

    TOOLBOX_PASSWORD=""

    password_record_metadata_is_safe "$PASSWORD_RECORD" || return 1

    field_count="$(LC_ALL=C awk '/^密码：/ { count++ } END { print count + 0 }' \
        "$PASSWORD_RECORD" 2>/dev/null)" || return 1
    [ "$field_count" = "1" ] || return 1

    TOOLBOX_PASSWORD="$(LC_ALL=C sed -n 's/^密码：//p' "$PASSWORD_RECORD")" || {
        TOOLBOX_PASSWORD=""
        return 1
    }
    [ -n "$TOOLBOX_PASSWORD" ] || return 1

    # 读取后再检查一次，避免在检查与读取之间被替换成宽权限或链接文件。
    password_record_metadata_is_safe "$PASSWORD_RECORD" || {
        TOOLBOX_PASSWORD=""
        return 1
    }
}

authenticate_toolbox_password_value() {
    local password="$1"

    command -v sudo >/dev/null 2>&1 || return 1
    # 清除旧的 sudo 缓存，确保验证的是刚刚输入的密码，而不是已有会话。
    sudo -k >/dev/null 2>&1 || true
    printf '%s\n' "$password" | sudo -S -p '' -v >/dev/null 2>&1
}

validate_toolbox_password_value() {
    local result

    if authenticate_toolbox_password_value "$1"; then
        result=0
    else
        result=$?
    fi
    sudo -k >/dev/null 2>&1 || true
    return "$result"
}

toolbox_sudo_interactive() {
    local result

    if [ "${ZHOUKEER_SUDO_INTERACTIVE_FALLBACK:-1}" = "0" ] || \
        { [ ! -t 0 ] && [ ! -t 1 ]; }; then
        return 1
    fi

    if sudo -- "$@"; then
        result=0
    else
        result=$?
    fi
    sudo -k >/dev/null 2>&1 || true
    return "$result"
}

toolbox_sudo() {
    local result

    command -v sudo >/dev/null 2>&1 || {
        echo "缺少命令: sudo"
        return 1
    }

    if sudo -n true >/dev/null 2>&1; then
        if sudo -n -- "$@"; then
            result=0
        else
            result=$?
        fi
        sudo -k >/dev/null 2>&1 || true
        return "$result"
    fi

    if ! load_toolbox_password; then
        echo "未找到安全可用的桌面密码记录。"
        echo "需要管理员权限时，将由系统正常询问密码。"
        toolbox_sudo_interactive "$@"
        return $?
    fi

    # 密码只经标准输入建立一次最短暂的 sudo 时间戳，不进入命令参数
    # 或环境变量；验证通过后立即执行目标命令并清除时间戳。
    if authenticate_toolbox_password_value "$TOOLBOX_PASSWORD"; then
        result=0
    else
        result=$?
    fi
    TOOLBOX_PASSWORD=""
    unset TOOLBOX_PASSWORD
    if [ "$result" -ne 0 ]; then
        sudo -k >/dev/null 2>&1 || true
        if [ "${ZHOUKEER_SUDO_INTERACTIVE_FALLBACK:-1}" != "0" ] && \
            { [ -t 0 ] || [ -t 1 ]; }; then
            echo "桌面密码记录未通过验证，将由系统重新询问密码。"
            toolbox_sudo_interactive "$@"
            return $?
        fi
        return "$result"
    fi

    if sudo -n -- "$@"; then
        result=0
    else
        result=$?
    fi
    sudo -k >/dev/null 2>&1 || true
    return "$result"
}
