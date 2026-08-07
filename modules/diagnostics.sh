#!/bin/bash

set -u

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../core/env.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/platform.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/logger.sh"
# shellcheck disable=SC1091
source "$PROJECT_ROOT/core/source_status.sh"

DIAGNOSTIC_DESKTOP="${ZHOUKEER_DIAGNOSTIC_OUTPUT_DIR:-$HOME/Desktop}"
DIAGNOSTIC_TMP_DIR=""

diagnostic_cleanup() {
    [ -z "$DIAGNOSTIC_TMP_DIR" ] || rm -rf -- "$DIAGNOSTIC_TMP_DIR"
}

diagnostic_redact_stream() {
    local username="${USER:-$(id -un 2>/dev/null || true)}"
    awk -v home="${HOME:-}" -v user="$username" '
        function escape_re(s) { gsub(/[][(){}.^$*+?|\\]/, "\\\\&", s); return s }
        BEGIN { home_re=escape_re(home); user_re=escape_re(user) }
        {
            line=$0
            low=tolower(line)
            if (home_re != "") gsub(home_re, "[HOME]", line)
            if (user_re != "") gsub(user_re, "[用户]", line)
            gsub(/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/, "[MAC已隐藏]", line)
            gsub(/(^|[^0-9])([0-9]{1,3}\.){3}[0-9]{1,3}([^0-9]|$)/, "\\1[IP已隐藏]\\3", line)
            gsub(/[0-9A-Fa-f]{0,4}:[0-9A-Fa-f:]{2,}/, "[IPv6已隐藏]", line)
            low=tolower(line)
            if (low ~ /(password|passwd|密码|token|cookie|authorization|bearer|secret|api[_-]?key|proxy[_-]?(url|auth)|验证码|临时码|远程协助.*(id|码|凭据))/) {
                sub(/[=:：].*$/, "=[敏感内容已隐藏]", line)
                if (line == $0) line="[敏感字段已隐藏]"
            }
            print line
        }
    '
}

diagnostic_redact_file() {
    local input="$1" output="$2"
    [ -f "$input" ] || { : > "$output"; return 0; }
    diagnostic_redact_stream < "$input" > "$output"
}

diagnostic_os_name() {
    local os_release="${ZHOUKEER_OS_RELEASE_FILE:-/etc/os-release}"
    if [ -r "$os_release" ]; then
        sed -n 's/^PRETTY_NAME=//p' "$os_release" | tr -d '"' | head -n 1
    fi
}

diagnostic_recent_errors() {
    if [ -s "$LOG_FILE" ] && [ ! -L "$LOG_FILE" ]; then
        tail -n 200 "$LOG_FILE" | grep -Ei '失败|错误|异常|warning|warn|error|fail|timeout|超时' | tail -n 60 || true
    else
        echo "暂无Renkit错误记录。"
    fi
    local launcher_log="${XDG_STATE_HOME:-$HOME/.local/state}/zhoukeer-toolbox/launcher.log"
    if [ -s "$launcher_log" ] && [ ! -L "$launcher_log" ]; then
        tail -n 40 "$launcher_log"
    fi
}

diagnostic_system_summary() {
    local version="未知" available="未知"
    [ ! -r "$PROJECT_ROOT/VERSION" ] || version="$(tr -d '\r\n' < "$PROJECT_ROOT/VERSION")"
    available="$(df -h "${HOME:-/}" 2>/dev/null | awk 'NR > 1 { value=$4 } END { print value }')"
    printf '%s\n' \
        "Renkit版本：V$version" \
        "生成时间：$(date '+%Y-%m-%d %H:%M:%S')" \
        "系统：$(diagnostic_os_name)" \
        "内核：$(uname -srm 2>/dev/null || echo 未知)" \
        "可用空间：${available:-未知}" \
        "说明：本诊断包由Renkit在本地生成，不会上传或自动发送。"
}

diagnostic_source_summary() {
    echo "======最近连接状态======"
    source_status_show
    echo ""
    echo "======当前软件来源安全摘要======"
    if command -v flatpak >/dev/null 2>&1; then
        flatpak remotes --user --columns=name,url,gpg-verify 2>/dev/null || echo "无法读取应用下载状态。"
    else
        echo "未安装 Flatpak。"
    fi
    if grep -Fqx '# BEGIN ZHOUKEER ARCHLINUXCN' /etc/pacman.conf 2>/dev/null; then
        echo "Renkit管理的 archlinuxcn：已配置（GPG 验证保持启用）"
    else
        echo "Renkit管理的 archlinuxcn：未配置"
    fi
}

diagnostic_network_summary() {
    echo "======最近一次网络检查======"
    source_status_show
    echo ""
    if command -v ip >/dev/null 2>&1 && ip route show default 2>/dev/null | grep -q '^default'; then
        echo "本地连接：已检测到可用连接"
    else
        echo "本地连接：未检测到可用连接"
    fi
    if [ -n "${http_proxy:-}${https_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}${all_proxy:-}" ]; then
        echo "代理设置：已检测到（地址与认证信息不写入诊断包）"
    else
        echo "代理设置：未检测到环境变量代理"
    fi
    echo "说明：生成诊断包时不会联网；以上外部线路结果来自最近一次“一键检查网络”。"
}

diagnostic_archive_is_safe() {
    local archive="$1"
    local entry
    while IFS= read -r entry; do
        case "$entry" in
            /*|../*|*/../*|*/..|*管理员密码*|*password*|*passwd*|*cookie*|*token*) return 1 ;;
        esac
    done < <(tar -tzf "$archive")
}

generate_diagnostic_bundle() {
    local stamp bundle_dir archive raw_file
    mkdir -p -- "$DIAGNOSTIC_DESKTOP" || return 1
    stamp="$(date '+%Y%m%d-%H%M%S')"
    DIAGNOSTIC_TMP_DIR="$(mktemp -d)" || return 1
    trap diagnostic_cleanup EXIT INT TERM
    bundle_dir="$DIAGNOSTIC_TMP_DIR/Renkit诊断包"
    mkdir -m 0700 -- "$bundle_dir" || return 1

    raw_file="$DIAGNOSTIC_TMP_DIR/system.raw"
    diagnostic_system_summary > "$raw_file"
    diagnostic_redact_file "$raw_file" "$bundle_dir/基础信息.txt"

    raw_file="$DIAGNOSTIC_TMP_DIR/network.raw"
    diagnostic_network_summary > "$raw_file"
    diagnostic_redact_file "$raw_file" "$bundle_dir/网络检查摘要.txt"

    raw_file="$DIAGNOSTIC_TMP_DIR/sources.raw"
    diagnostic_source_summary > "$raw_file"
    diagnostic_redact_file "$raw_file" "$bundle_dir/下载与更新状态.txt"

    raw_file="$DIAGNOSTIC_TMP_DIR/errors.raw"
    diagnostic_recent_errors > "$raw_file"
    diagnostic_redact_file "$raw_file" "$bundle_dir/最近错误摘要.txt"

    printf '%s\n' \
        "内容：Renkit版本、SteamOS 基础信息、网络检查、下载与更新状态、最近错误安全摘要。" \
        "隐私：用户名、HOME、IP、MAC、局域网地址、密码、Token、Cookie、代理认证和远程协助凭据会被隐藏。" \
        "排除：不读取、不复制管理员密码便利模式文件，不包含游戏、存档、账号数据或完整日志。" \
        "发送：Renkit不会上传或自动发送，请由你自行决定是否发给维护人员。" > "$bundle_dir/请先阅读.txt"

    chmod 0600 "$bundle_dir"/*.txt || return 1
    archive="$DIAGNOSTIC_DESKTOP/Renkit诊断包-$stamp.tar.gz"
    tar -czf "$archive" -C "$DIAGNOSTIC_TMP_DIR" "Renkit诊断包" || return 1
    diagnostic_archive_is_safe "$archive" || {
        rm -f -- "$archive"
        echo "诊断包安全检查未通过，已删除未完成文件。"
        return 1
    }
    chmod 0600 "$archive" || { rm -f -- "$archive"; return 1; }
    echo "诊断包已生成，可直接发给维护人员，不包含密码和隐私信息。"
    echo "保存位置：$archive"
    echo "Renkit没有上传或发送任何内容。"
    log "已生成本地安全诊断包"
    diagnostic_cleanup
    trap - EXIT INT TERM
}

case "${1:-bundle}" in
    bundle) generate_diagnostic_bundle ;;
    redact)
        [ -n "${2:-}" ] && [ -n "${3:-}" ] || { echo "用法: $0 redact 输入 输出"; exit 1; }
        diagnostic_redact_file "$2" "$3"
        ;;
    status) source_status_show ;;
    *) echo "用法: $0 {bundle|redact 输入 输出|status}"; exit 1 ;;
esac
