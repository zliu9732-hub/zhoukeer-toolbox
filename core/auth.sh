#!/bin/bash

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

resolve_password_record_path() {
    local xdg_desktop
    local default_record="$HOME/Desktop/管理员密码.txt"

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
                printf '%s/管理员密码.txt\n' "${xdg_desktop%/}"
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
        PASSWORD_RECORD_ERROR="桌面没有找到管理员密码.txt"
        return 1
    fi
    if [ ! -f "$file" ] || [ -L "$file" ]; then
        PASSWORD_RECORD_ERROR="管理员密码.txt不是普通文件或是符号链接"
        return 1
    fi
    if [ ! -r "$file" ]; then
        PASSWORD_RECORD_ERROR="当前用户无法读取管理员密码.txt"
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
        PASSWORD_RECORD_ERROR="无法读取管理员密码.txt的所有者"
        return 1
    }
    file_mode="$(password_record_stat mode "$file")" || {
        PASSWORD_RECORD_ERROR="无法读取管理员密码.txt的权限"
        return 1
    }
    link_count="$(password_record_stat links "$file")" || {
        PASSWORD_RECORD_ERROR="无法检查管理员密码.txt的链接数量"
        return 1
    }
    file_size="$(password_record_stat size "$file")" || {
        PASSWORD_RECORD_ERROR="无法读取管理员密码.txt的大小"
        return 1
    }

    if [ "$file_uid" != "$current_uid" ]; then
        PASSWORD_RECORD_ERROR="管理员密码.txt不属于当前用户"
        return 1
    fi
    if [ "$link_count" != "1" ]; then
        PASSWORD_RECORD_ERROR="管理员密码.txt存在额外硬链接"
        return 1
    fi
    case "$file_size" in
        ''|*[!0-9]*) PASSWORD_RECORD_ERROR="管理员密码.txt大小异常"; return 1 ;;
    esac
    if [ "$file_size" -le 0 ] || [ "$file_size" -gt 4096 ]; then
        PASSWORD_RECORD_ERROR="管理员密码.txt为空或内容过大"
        return 1
    fi

    # 兼容旧版本生成的 644/640 文件：仅当它确实是当前用户拥有的普通
    # 单链接小文件时，自动收紧为 600，不要求顾客手动打开终端修权限。
    if [ "$file_mode" != "600" ]; then
        if chmod 600 "$file" 2>/dev/null; then
            file_mode="$(password_record_stat mode "$file" 2>/dev/null || true)"
        fi
        if [ "$file_mode" != "600" ]; then
            PASSWORD_RECORD_ERROR="管理员密码.txt权限不是600且自动修复失败"
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
        PASSWORD_RECORD_ERROR="管理员密码.txt中必须且只能有一行“密码：...”"
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

write_captured_toolbox_password() {
    local password="$1"
    local record_dir
    local tmp_file
    local username

    if [ -e "$PASSWORD_RECORD" ] || [ -L "$PASSWORD_RECORD" ]; then
        return 1
    fi
    record_dir="$(dirname "$PASSWORD_RECORD")" || return 1
    mkdir -p "$record_dir" || return 1
    [ -d "$record_dir" ] || return 1
    username="$(id -un 2>/dev/null)" || return 1

    umask 077
    tmp_file="$(mktemp "$record_dir/.zhoukeer-password.XXXXXX")" || return 1
    if ! cat > "$tmp_file" <<EOF
周克儿工具箱 - Steam Deck 密码记录

用户：$username
操作：录入现有管理员密码
时间：$(date '+%Y-%m-%d %H:%M:%S')

密码：$password

用途：仅供周克儿工具箱在本机自动完成管理员验证。
警告：这是明文密码；所有以当前用户身份运行的软件都可能读取本文件。
说明：工具箱不会把密码写入日志、命令参数或上传到网络。
EOF
    then
        rm -f "$tmp_file"
        return 1
    fi
    chmod 600 "$tmp_file" || {
        rm -f "$tmp_file"
        return 1
    }
    if [ -e "$PASSWORD_RECORD" ] || [ -L "$PASSWORD_RECORD" ] || \
        ! mv -f "$tmp_file" "$PASSWORD_RECORD"; then
        rm -f "$tmp_file"
        return 1
    fi
    chmod 600 "$PASSWORD_RECORD" || return 1
    load_toolbox_password && [ "$TOOLBOX_PASSWORD" = "$password" ]
}

capture_existing_admin_password() {
    local captured_password

    # 插件安装可能在子 shell 中运行，标准输入不一定仍被标记为 TTY；
    # 直接使用当前 Konsole 的控制终端，避免落回 sudo 后反复询问。
    [ -r /dev/tty ] && [ -w /dev/tty ] || return 1
    printf '%s\n' "桌面尚未创建管理员密码.txt。" > /dev/tty
    printf '%s\n' "请输入一次当前管理员密码；验证成功后会自动保存到桌面，后续操作无需重复输入。" > /dev/tty
    printf '%s\n' "注意：密码将按你的设置以明文保存，仅限本机工具箱使用。" > /dev/tty
    printf '当前管理员密码（输入时不会显示）：' > /dev/tty
    exec 3</dev/tty
    IFS= read -r -s -u 3 captured_password || { exec 3<&-; return 1; }
    exec 3<&-
    printf '\n' > /dev/tty
    [ -n "$captured_password" ] || return 1

    if ! authenticate_toolbox_password_value "$captured_password"; then
        captured_password=""
        unset captured_password
        sudo -k >/dev/null 2>&1 || true
        echo "密码验证失败，未创建桌面记录。"
        return 1
    fi
    if ! write_captured_toolbox_password "$captured_password"; then
        captured_password=""
        unset captured_password
        sudo -k >/dev/null 2>&1 || true
        echo "密码验证成功，但桌面密码记录创建失败。"
        return 1
    fi
    captured_password=""
    unset captured_password
    echo "已创建桌面密码记录，后续管理员操作将自动验证。"
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
        echo "请先在工具箱中使用“设置系统密码”，本操作不会弹出重复密码输入。"
        return 1
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
        echo "管理员密码.txt中的密码未通过验证，请在工具箱中更新密码记录。"
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
