#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

resolve_password_record_path() {
    local xdg_desktop
    local default_record="$HOME/Desktop/密码.txt"

    if [ -n "${ZHOUKEER_PASSWORD_RECORD:-}" ]; then
        printf '%s\n' "$ZHOUKEER_PASSWORD_RECORD"
        return 0
    fi
    if [ -e "$default_record" ] || [ -L "$default_record" ]; then
        printf '%s\n' "$default_record"
        return 0
    fi
    if command -v xdg-user-dir >/dev/null 2>&1; then
        xdg_desktop="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
        case "$xdg_desktop" in
            "$HOME"/*)
                printf '%s/密码.txt\n' "${xdg_desktop%/}"
                return 0
                ;;
        esac
    fi
    printf '%s\n' "$default_record"
}

PASSWORD_RECORD="$(resolve_password_record_path)"
TOOLBOX_PASSWORD=""
PASSWORD_RECORD_ERROR=""

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

    PASSWORD_RECORD_ERROR=""
    if [ ! -e "$file" ] && [ ! -L "$file" ]; then
        PASSWORD_RECORD_ERROR="桌面没有找到密码.txt"
        return 1
    fi
    if [ ! -f "$file" ] || [ -L "$file" ]; then
        PASSWORD_RECORD_ERROR="密码.txt不是普通文件或是符号链接"
        return 1
    fi
    if [ ! -r "$file" ]; then
        PASSWORD_RECORD_ERROR="当前用户无法读取密码.txt"
        return 1
    fi

    current_uid="$(id -u 2>/dev/null)" || {
        PASSWORD_RECORD_ERROR="无法确认当前用户"
        return 1
    }
    case "$current_uid" in
        ''|*[!0-9]*) PASSWORD_RECORD_ERROR="当前用户编号异常"; return 1 ;;
    esac

    file_uid="$(password_record_stat owner "$file")" || {
        PASSWORD_RECORD_ERROR="无法读取密码.txt的所有者"
        return 1
    }
    file_mode="$(password_record_stat mode "$file")" || {
        PASSWORD_RECORD_ERROR="无法读取密码.txt的权限"
        return 1
    }
    link_count="$(password_record_stat links "$file")" || {
        PASSWORD_RECORD_ERROR="无法检查密码.txt的链接数量"
        return 1
    }
    file_size="$(password_record_stat size "$file")" || {
        PASSWORD_RECORD_ERROR="无法读取密码.txt的大小"
        return 1
    }

    if [ "$file_uid" != "$current_uid" ]; then
        PASSWORD_RECORD_ERROR="密码.txt不属于当前用户"
        return 1
    fi
    if [ "$link_count" != "1" ]; then
        PASSWORD_RECORD_ERROR="密码.txt存在额外硬链接"
        return 1
    fi
    case "$file_size" in
        ''|*[!0-9]*) PASSWORD_RECORD_ERROR="密码.txt大小异常"; return 1 ;;
    esac
    if [ "$file_size" -le 0 ] || [ "$file_size" -gt 4096 ]; then
        PASSWORD_RECORD_ERROR="密码.txt为空或内容过大"
        return 1
    fi

    # 兼容旧版本生成的 644/640 文件：仅当它确实是当前用户拥有的普通
    # 单链接小文件时，自动收紧为 600，不要求顾客手动打开终端修权限。
    if [ "$file_mode" != "600" ]; then
        if chmod 600 "$file" 2>/dev/null; then
            file_mode="$(password_record_stat mode "$file" 2>/dev/null || true)"
        fi
        if [ "$file_mode" != "600" ]; then
            PASSWORD_RECORD_ERROR="密码.txt权限不是600且自动修复失败"
            return 1
        fi
        echo "已自动修复旧密码文件权限。" >&2
    fi
    return 0
}

load_toolbox_password() {
    local field_count

    TOOLBOX_PASSWORD=""

    password_record_metadata_is_safe "$PASSWORD_RECORD" || return 1

    field_count="$(LC_ALL=C awk 'index($0, "密码：") == 1 || index($0, "密码:") == 1 { count++ } END { print count + 0 }' \
        "$PASSWORD_RECORD" 2>/dev/null)" || return 1
    if [ "$field_count" != "1" ]; then
        PASSWORD_RECORD_ERROR="密码.txt中必须且只能有一行“密码：...”"
        return 1
    fi

    TOOLBOX_PASSWORD="$(LC_ALL=C sed -n -e 's/^密码：//p' -e 's/^密码://p' "$PASSWORD_RECORD" | tr -d '\r')" || {
        TOOLBOX_PASSWORD=""
        PASSWORD_RECORD_ERROR="无法读取密码字段"
        return 1
    }
    if [ -z "$TOOLBOX_PASSWORD" ]; then
        PASSWORD_RECORD_ERROR="密码字段为空"
        return 1
    fi

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
        echo "桌面密码记录不可用：${PASSWORD_RECORD_ERROR:-未知原因}"
        echo "记录位置：$PASSWORD_RECORD"
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
