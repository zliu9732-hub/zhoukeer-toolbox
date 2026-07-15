#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/auth.sh"

CURRENT_TOOLBOX_USERNAME=""
CURRENT_TOOLBOX_UID=""

load_non_root_identity() {
    CURRENT_TOOLBOX_UID="$(id -u 2>/dev/null)" || return 1
    CURRENT_TOOLBOX_USERNAME="$(id -un 2>/dev/null)" || return 1

    case "$CURRENT_TOOLBOX_UID" in ''|*[!0-9]*) return 1 ;; esac
    [ "$CURRENT_TOOLBOX_UID" != "0" ] || {
        echo "拒绝以 root 身份设置密码；请使用 Steam Deck 的普通桌面用户运行工具箱。"
        return 1
    }
    case "$CURRENT_TOOLBOX_USERNAME" in ''|*:*|*$'\n'*) return 1 ;; esac
}

show_plaintext_password_warning() {
    echo "重要提示：新密码会以明文写入桌面“管理员密码.txt”。"
    echo "文件权限固定为 600，但所有以当前用户身份运行的软件都可能读取它。"
    echo "工具箱只在需要管理员权限时读取，不会上传或写入日志。"
}

password_record_target_is_safe_for_replace() {
    local file="${1:-$PASSWORD_RECORD}"
    local file_uid
    local link_count

    if [ ! -e "$file" ] && [ ! -L "$file" ]; then
        return 0
    fi
    [ -f "$file" ] && [ ! -L "$file" ] || return 1

    file_uid="$(password_record_stat owner "$file")" || return 1
    link_count="$(password_record_stat links "$file")" || return 1
    [ "$file_uid" = "$CURRENT_TOOLBOX_UID" ] && [ "$link_count" = "1" ]
}

remove_stale_password_record() {
    local file_uid
    local link_count

    TOOLBOX_PASSWORD=""
    unset TOOLBOX_PASSWORD
    if [ ! -e "$PASSWORD_RECORD" ] && [ ! -L "$PASSWORD_RECORD" ]; then
        return 0
    fi
    [ -f "$PASSWORD_RECORD" ] && [ ! -L "$PASSWORD_RECORD" ] || return 1
    file_uid="$(password_record_stat owner "$PASSWORD_RECORD")" || return 1
    link_count="$(password_record_stat links "$PASSWORD_RECORD")" || return 1
    [ "$file_uid" = "$CURRENT_TOOLBOX_UID" ] && [ "$link_count" = "1" ] || return 1
    rm -f -- "$PASSWORD_RECORD"
}

write_password_record() {
    local action_label="$1"
    local password="$2"
    local record_dir
    local tmp_file

    record_dir="$(dirname "$PASSWORD_RECORD")" || return 1
    mkdir -p -- "$record_dir" || return 1
    [ -d "$record_dir" ] || return 1
    if ! password_record_target_is_safe_for_replace "$PASSWORD_RECORD"; then
        echo "拒绝覆盖异常的密码记录路径：$PASSWORD_RECORD"
        echo "该路径必须是当前用户拥有、只有一个硬链接的普通文件。"
        return 1
    fi

    umask 077
    tmp_file="$(mktemp "$record_dir/.zhoukeer-password.XXXXXX")" || return 1
    if ! cat > "$tmp_file" <<EOF
周克儿工具箱 - Steam Deck 密码记录

用户：$CURRENT_TOOLBOX_USERNAME
操作：$action_label
时间：$(date '+%Y-%m-%d %H:%M:%S')

密码：$password

用途：仅供周克儿工具箱在本机自动完成管理员验证。
警告：这是明文密码；所有以当前用户身份运行的软件都可能读取本文件。
说明：工具箱不会把密码写入日志、命令参数或上传到网络。
EOF
    then
        rm -f -- "$tmp_file"
        return 1
    fi
    chmod 600 "$tmp_file" || {
        rm -f -- "$tmp_file"
        return 1
    }

    # SteamOS 的 GNU mv 使用 -T 保证目标不会被当作目录；macOS 测试环境
    # 没有 -T，因此在替换前再次验证目标，并使用同目录原子重命名。
    if mv --help 2>&1 | grep -q -- '--no-target-directory'; then
        mv -fT -- "$tmp_file" "$PASSWORD_RECORD"
    else
        password_record_target_is_safe_for_replace "$PASSWORD_RECORD" && \
            mv -f -- "$tmp_file" "$PASSWORD_RECORD"
    fi || {
        rm -f -- "$tmp_file"
        return 1
    }

    chmod 600 "$PASSWORD_RECORD" || {
        remove_stale_password_record >/dev/null 2>&1 || true
        return 1
    }
    if ! load_toolbox_password || [ "$TOOLBOX_PASSWORD" != "$password" ]; then
        TOOLBOX_PASSWORD=""
        unset TOOLBOX_PASSWORD
        remove_stale_password_record >/dev/null 2>&1 || true
        return 1
    fi
    TOOLBOX_PASSWORD=""
    unset TOOLBOX_PASSWORD
    echo "已生成记录文件：$PASSWORD_RECORD"
}

capture_and_verify_current_password() {
    local captured_password
    local attempts=0

    while [ "$attempts" -lt 3 ]; do
        attempts=$((attempts + 1))
        printf '请再次输入刚设置的新密码（用于自动验证）：'
        IFS= read -r -s captured_password || return 1
        printf '\n'
        if validate_toolbox_password_value "$captured_password"; then
            CAPTURED_PASSWORD="$captured_password"
            captured_password=""
            unset captured_password
            return 0
        fi
        captured_password=""
        unset captured_password
        echo "密码验证失败，请确认输入与刚设置的系统密码一致。"
    done
    return 1
}

set_system_password() {
    local action_label="设置系统密码"

    is_linux || {
        echo "系统密码功能仅支持 Linux/SteamOS。"
        return 1
    }
    require_command passwd || return 1
    load_non_root_identity || return 1

    show_plaintext_password_warning
    echo ""
    echo "$action_label"
    echo "请按照系统提示输入密码；输入时屏幕不会显示字符，这是正常现象。"
    if ! passwd; then
        echo "系统密码没有修改。"
        return 1
    fi

    CAPTURED_PASSWORD=""
    capture_and_verify_current_password || {
        echo "系统密码已生效，但自动验证密码没有记录。"
        return 1
    }
    write_password_record "$action_label" "$CAPTURED_PASSWORD" || {
        CAPTURED_PASSWORD=""
        unset CAPTURED_PASSWORD
        remove_stale_password_record >/dev/null 2>&1 || true
        echo "密码已生效，但桌面密码文件创建失败。旧记录已停用或清除。"
        return 1
    }
    CAPTURED_PASSWORD=""
    unset CAPTURED_PASSWORD
    log "$action_label 完成（桌面密码记录已更新）"
}

prompt_new_password() {
    local first
    local second

    while true; do
        printf '请输入新密码：'
        IFS= read -r -s first || return 1
        printf '\n'
        [ -n "$first" ] || {
            echo "密码不能为空。"
            continue
        }
        printf '请再次输入新密码：'
        IFS= read -r -s second || return 1
        printf '\n'
        if [ "$first" = "$second" ]; then
            case "$first" in
                *:*)
                    first=""
                    second=""
                    unset first second
                    echo "密码不能包含冒号，请重新输入。"
                    continue
                    ;;
            esac
            NEW_PASSWORD="$first"
            first=""
            second=""
            unset first second
            return 0
        fi
        first=""
        second=""
        unset first second
        echo "两次输入不一致，请重新输入。"
    done
}

change_system_password() {
    local action_label="修改系统密码"
    local current_password
    local change_result

    is_linux || {
        echo "系统密码功能仅支持 Linux/SteamOS。"
        return 1
    }
    require_command sudo || return 1
    require_command chpasswd || return 1
    load_non_root_identity || return 1

    show_plaintext_password_warning
    echo ""
    if ! load_toolbox_password; then
        echo "桌面“管理员密码.txt”不存在或未通过安全检查，请先使用“设置系统密码”。"
        return 1
    fi
    current_password="$TOOLBOX_PASSWORD"
    TOOLBOX_PASSWORD=""
    unset TOOLBOX_PASSWORD

    NEW_PASSWORD=""
    prompt_new_password || {
        current_password=""
        unset current_password
        return 1
    }

    # 只在执行 chpasswd 前建立最短暂的 sudo 时间戳，随后立即失效。
    if ! authenticate_toolbox_password_value "$current_password"; then
        current_password=""
        NEW_PASSWORD=""
        unset current_password NEW_PASSWORD
        sudo -k >/dev/null 2>&1 || true
        echo "桌面记录的旧密码验证失败，请先重新设置系统密码。"
        return 1
    fi
    current_password=""
    unset current_password

    if printf '%s:%s\n' "$CURRENT_TOOLBOX_USERNAME" "$NEW_PASSWORD" | \
        sudo -n -- chpasswd; then
        change_result=0
    else
        change_result=$?
    fi
    sudo -k >/dev/null 2>&1 || true
    if [ "$change_result" -ne 0 ]; then
        NEW_PASSWORD=""
        unset NEW_PASSWORD
        echo "系统密码修改失败，桌面密码文件保持原样。"
        return 1
    fi

    write_password_record "$action_label" "$NEW_PASSWORD" || {
        NEW_PASSWORD=""
        unset NEW_PASSWORD
        remove_stale_password_record >/dev/null 2>&1 || true
        echo "密码已修改，但桌面密码文件更新失败。旧记录已停用或清除。"
        return 1
    }
    NEW_PASSWORD=""
    unset NEW_PASSWORD
    log "$action_label 完成（桌面密码记录已更新）"
    echo "系统密码修改完成，桌面密码记录已同步更新。"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        set) set_system_password ;;
        change) change_system_password ;;
        *) echo "用法: $0 {set|change}"; exit 1 ;;
    esac
fi
