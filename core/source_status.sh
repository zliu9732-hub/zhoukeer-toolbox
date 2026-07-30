#!/bin/bash

if [ -n "${ZHOUKEER_SOURCE_STATUS_LOADED:-}" ]; then
    return 0
fi
ZHOUKEER_SOURCE_STATUS_LOADED=1

SOURCE_STATUS_DIR="${ZHOUKEER_SOURCE_STATUS_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox}"
SOURCE_STATUS_FILE="${ZHOUKEER_SOURCE_STATUS_FILE:-$SOURCE_STATUS_DIR/source-status.tsv}"

source_status_id_allowed() {
    case "$1" in
        local|dns|https|time|ipv4|ipv6|proxy|steam|gitee|github|flathub-cn|flathub-ustc|flathub-official|update-gitee|update-github|update-domain) return 0 ;;
        *) return 1 ;;
    esac
}

source_status_safe_text() {
    printf '%s' "$1" | tr '\t\r\n' '   ' | sed -E \
        -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1[认证信息已隐藏]@#g' \
        -e 's/(password|passwd|token|cookie|authorization|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1=[已隐藏]/Ig' | cut -c 1-160
}

source_status_record() {
    local id="$1"
    local state="$2"
    local reason="${3:-}"
    local now tmp old_line="" old_id="" old_state="" old_checked="" last_success="" last_failure="" last_reason=""

    source_status_id_allowed "$id" || return 1
    case "$state" in ok|fail|skip) ;; *) return 1 ;; esac
    mkdir -p -- "$SOURCE_STATUS_DIR" || return 1
    chmod 0700 "$SOURCE_STATUS_DIR" 2>/dev/null || true
    now="$(date '+%Y-%m-%dT%H:%M:%S%z')"
    tmp="$(mktemp "$SOURCE_STATUS_DIR/.source-status.XXXXXX")" || return 1
    if [ -f "$SOURCE_STATUS_FILE" ] && [ ! -L "$SOURCE_STATUS_FILE" ]; then
        old_line="$(awk -F '\t' -v id="$id" '$1 == id { print; exit }' "$SOURCE_STATUS_FILE")"
        if [ -n "$old_line" ]; then
            # Tab 属于 shell 的空白 IFS 字符，直接 read 会折叠连续 Tab，
            # 从而把空的“最近成功”列吞掉并令失败时间、原因整体左移。
            # 逐列读取可同时兼容四列旧格式和六列当前格式。
            old_id="$(printf '%s\n' "$old_line" | awk -F '\t' '{ print $1 }')"
            old_state="$(printf '%s\n' "$old_line" | awk -F '\t' '{ print $2 }')"
            old_checked="$(printf '%s\n' "$old_line" | awk -F '\t' '{ print $3 }')"
            last_success="$(printf '%s\n' "$old_line" | awk -F '\t' '{ print $4 }')"
            last_failure="$(printf '%s\n' "$old_line" | awk -F '\t' '{ print $5 }')"
            last_reason="$(printf '%s\n' "$old_line" | awk -F '\t' '{ print $6 }')"
            # 兼容 V5.5.9 早期测试产生的四列状态文件。
            if [ -z "$last_failure" ] && [ -n "$last_success" ]; then
                case "$old_state" in ok) last_success="$old_checked" ;; fail) last_reason="$last_success"; last_failure="$old_checked"; last_success="" ;; esac
            fi
        fi
        awk -F '\t' -v id="$id" '$1 != id' "$SOURCE_STATUS_FILE" > "$tmp" || {
            rm -f -- "$tmp"
            return 1
        }
    fi
    case "$state" in
        ok) last_success="$now" ;;
        fail) last_failure="$now"; last_reason="$(source_status_safe_text "$reason")" ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$state" "$now" "$last_success" "$last_failure" "$last_reason" >> "$tmp" || {
        rm -f -- "$tmp"
        return 1
    }
    chmod 0600 "$tmp" || { rm -f -- "$tmp"; return 1; }
    mv -f -- "$tmp" "$SOURCE_STATUS_FILE"
}

source_status_show() {
    if [ ! -s "$SOURCE_STATUS_FILE" ] || [ -L "$SOURCE_STATUS_FILE" ]; then
        echo "暂无连接记录，请先运行网络检查。"
        return 0
    fi
    awk -F '\t' '
        function label(id) {
            if (id == "update-gitee") return "工具箱更新（Gitee）"
            if (id == "update-github") return "工具箱更新（GitHub）"
            if (id == "update-domain") return "工具箱更新（域名备用）"
            if (id == "flathub-cn") return "应用下载（上海交大）"
            if (id == "flathub-ustc") return "应用下载（中科大）"
            if (id == "flathub-official") return "应用下载（官方）"
            return id
        }
        {
            printf "%-28s %s｜本次 %s", label($1), ($2 == "ok" ? "可用" : ($2 == "skip" ? "未检测" : "不可用")), $3
            if ($4 != "") printf "｜最近成功 %s", $4
            if ($5 != "") printf "｜最近失败 %s", $5
            if ($6 != "") printf "（%s）", $6
            printf "\n"
        }
    ' "$SOURCE_STATUS_FILE"
}
